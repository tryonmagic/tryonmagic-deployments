#https://devopscube.com/configure-multiple-kubernetes-clusters-argo-cd/

# Download the ECR credential provider binary
wget https://github.com/dntosas/ecr-credential-provider/releases/download/v1.2.0/ecr-credential-provider-linux-amd64
chmod +x ecr-credential-provider-linux-amd64
sudo mv ecr-credential-provider-linux-amd64 /usr/local/bin/ecr-credential-provider

# Create credential provider config
sudo mkdir -p /etc/kubernetes
sudo tee /etc/kubernetes/ecr-credential-provider.json > /dev/null <<EOF
{
  "providers": [
    {
      "name": "ecr-credential-provider",
      "matchImages": [
        "*.dkr.ecr.*.amazonaws.com",
        "*.dkr.ecr.*.amazonaws.com.cn"
      ],
      "apiVersion": "credentialprovider.kubelet.k8s.io/v1",
      "defaultCacheDuration": "12h"
    }
  ]
}
EOF

DOMAIN="kube.tryonmagic.com"

curl -sfL https://get.k3s.io | sh -s - \
  --tls-san kube.tryonmagic.com \
  --kubelet-arg="image-credential-provider-config=/etc/kubernetes/ecr-credential-provider.json" \
  --kubelet-arg="image-credential-provider-bin-dir=/usr/local/bin"

sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc

kubectl get pods -A
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


mkdir argocd-cluster-add
cat <<EOF > argocd-cluster-add/sa-cr.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-manager-role
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-manager-role
subjects:
- kind: ServiceAccount
  name: argocd-manager
  namespace: kube-system
EOF

kubectl apply -f argocd-cluster-add/sa-cr.yaml

cat <<EOF > argocd-cluster-add/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
EOF

kubectl apply -f argocd-cluster-add/secret.yaml

ca=$(kubectl get -n kube-system secret/argocd-manager-token -o jsonpath='{.data.ca\.crt}')
token=$(kubectl get -n kube-system secret/argocd-manager-token -o jsonpath='{.data.token}' | base64 --decode)

kubectl create ns prod

cat <<EOF > argocd-cluster-add/cluster.yaml
apiVersion: v1
kind: Secret
metadata:
  name: tryonmagic-cluster
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: tryonmagic-cluster
  server: https://${DOMAIN}:6443
  config: |
    {
      "bearerToken": "${token}",
      "tlsClientConfig": {
        "serverName": "${DOMAIN}",
        "caData": "${ca}"
      }
    }
EOF

