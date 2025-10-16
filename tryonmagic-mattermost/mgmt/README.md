# tryonmagic-mattermost (mgmt)

Umbrella Helm chart that installs:
- Mattermost Operator (official)
- A Mattermost instance via Mattermost CR
- PostgreSQL (Bitnami) for app DB (optional)
- MinIO (Bitnami) as S3-compatible filestore (optional)

This mirrors a single-command install style similar to other tryonmagic mgmt charts.

## Prerequisites
- Kubernetes 1.24+
- Helm 3.8+
- Ingress Controller (e.g., nginx)

Add required repos:

```bash
helm repo add mattermost https://helm.mattermost.com
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## Install

```bash
helm dependency update ./tryonmagic-mattermost/mgmt
helm install mm ./tryonmagic-mattermost/mgmt \
  --namespace mattermost --create-namespace \
  --set host=mattermost.example.com \
  --set tlsSecretName=mattermost-tls
```

Then browse to https://mattermost.example.com.

## Values to review
- mattermost.image.tag (pin to a tested version)
- host, tlsSecretName, ingress className
- postgresql.primary.persistence.size and storageClass
- minio.persistence.size and storageClass (or use externalS3)

## Switch to external DB

```bash
helm upgrade mm ./tryonmagic-mattermost/mgmt -n mattermost \
  --set postgresql.enabled=false \
  --set externalDatabase.enabled=true \
  --set externalDatabase.host=mydb.example.com \
  --set externalDatabase.port=5432 \
  --set externalDatabase.database=mattermost \
  --set externalDatabase.username=mmuser \
  --set externalDatabase.password=REDACTED \
  --set externalDatabase.sslmode=disable
```

## Switch to external S3

```bash
helm upgrade mm ./tryonmagic-mattermost/mgmt -n mattermost \
  --set minio.enabled=false \
  --set externalS3.enabled=true \
  --set externalS3.accessKey=AKIA... \
  --set externalS3.secretKey=REDACTED \
  --set externalS3.endpoint=s3.amazonaws.com \
  --set externalS3.region=us-east-1 \
  --set externalS3.bucket=mattermost \
  --set mattermost.s3.forcePathStyle=false
```

## Upgrades

```bash
helm dependency update ./tryonmagic-mattermost/mgmt
helm upgrade mm ./tryonmagic-mattermost/mgmt -n mattermost
```

## Troubleshooting
- kubectl get pods -n mattermost
- kubectl get mattermost -n mattermost -o yaml
- Check Ingress/DNS/TLS

# tryonmagic-mattermost (mgmt)

Umbrella Helm chart that installs:
- Mattermost Operator (official)
- A Mattermost instance via Mattermost CR
- PostgreSQL (Bitnami) for app DB (optional)
- MinIO (Bitnami) as S3-compatible filestore (optional)

This mirrors a single-command install style similar to other tryonmagic mgmt charts.

## Prerequisites
- Kubernetes 1.24+
- Helm 3.8+
- Ingress Controller (e.g., nginx)

Add required repos:

```bash
helm repo add mattermost https://helm.mattermost.com
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## Install

```bash
helm dependency update ./tryonmagic-mattermost/mgmt
helm install mm ./tryonmagic-mattermost/mgmt \
  --namespace mattermost --create-namespace \
  --set host=mattermost.example.com \
  --set tlsSecretName=mattermost-tls
```

Then browse to https://mattermost.example.com.

## Values to review
- mattermost.image.tag (pin to a tested version)
- host, tlsSecretName, ingress className
- postgresql.primary.persistence.size and storageClass
- minio.persistence.size and storageClass (or use externalS3)

## Switch to external DB

```bash
helm upgrade mm ./tryonmagic-mattermost/mgmt -n mattermost \
  --set postgresql.enabled=false \
  --set externalDatabase.enabled=true \
  --set externalDatabase.host=mydb.example.com \
  --set externalDatabase.port=5432 \
  --set externalDatabase.database=mattermost \
  --set externalDatabase.username=mmuser \
  --set externalDatabase.password=REDACTED \
  --set externalDatabase.sslmode=disable
```

## Switch to external S3

```bash
helm upgrade mm ./tryonmagic-mattermost/mgmt -n mattermost \
  --set minio.enabled=false \
  --set externalS3.enabled=true \
  --set externalS3.accessKey=AKIA... \
  --set externalS3.secretKey=REDACTED \
  --set externalS3.endpoint=s3.amazonaws.com \
  --set externalS3.region=us-east-1 \
  --set externalS3.bucket=mattermost \
  --set mattermost.s3.forcePathStyle=false
```

## Upgrades

```bash
helm dependency update ./tryonmagic-mattermost/mgmt
helm upgrade mm ./tryonmagic-mattermost/mgmt -n mattermost
```

## Troubleshooting
- kubectl get pods -n mattermost
- kubectl get mattermost -n mattermost -o yaml
- Check Ingress/DNS/TLS

## Why do we need templates?
Helm templates let us generate Kubernetes manifests dynamically based on values and release context. In this chart, templates are essential for:

- Environment-specific configuration without duplicating YAML:
  - Example: `values.yaml` toggles in-cluster PostgreSQL/MinIO vs external services; the same chart handles dev and prod by switching `.Values.postgresql.enabled` and `.Values.minio.enabled`.

- Securely injecting secrets and endpoints:
  - `templates/secret-db-dsn.yaml` builds the PostgreSQL DSN from credentials and service discovery.
  - `templates/secret-s3.yaml` wires S3/MinIO access keys, region, endpoint, and path-style flags.

- Conditional resources (enable/disable):
  - Database and filestore references switch between in-cluster and external with conditions.

- Operator CR parametrization:
  - `templates/mattermost.yaml` renders a Mattermost Custom Resource that references generated secrets and uses values like host, TLS secret, image tag, and replica count.

- Reusable helpers and consistent naming:
  - `_helpers.tpl` produces stable names/labels (`tryonmagic-mattermost.fullname`) across namespaces and releases.

- DRY and maintainability:
  - Avoids copy-pasting similar manifests for each environment; changes live in one place and are driven by values.

- GitOps-friendly diffs:
  - Rendering is deterministic for a given set of values, producing clean diffs and predictable rollouts.

Quick example from this chart:

```yaml
# In values.yaml
mattermost:
  ingress:
    host: "{{ .Values.host }}"

# In the template (templates/mattermost.yaml)
spec:
  ingress:
    host: {{ tpl $mm.ingress.host . | quote }}
```

This lets you set `--set host=mattermost.example.com` once, and have the CR’s ingress host and the ServiceSettings.SiteURL align automatically.

## TLS secret name auto-generation (optional)
If you don't want to pass `tlsSecretName`, you can enable auto-generation:

- Set `autoGenerateTlsSecretName: true` in values (or `--set autoGenerateTlsSecretName=true`).
- Choose a strategy with `tlsSecretNameStrategy`:
  - `host` (default): generates `<host-with-dots-replaced>-tls`, e.g., `mattermost-example-com-tls`
  - `fullname`: generates `<release-fullname>-tls`

Example:

```bash
helm install mm ./tryonmagic-mattermost/mgmt \
  -n mattermost --create-namespace \
  --set host=mattermost.example.com \
  --set autoGenerateTlsSecretName=true \
  --set tlsSecretNameStrategy=host
```

Note: Ensure a TLS secret with the generated name exists in the namespace. Typically cert-manager will create it via a Certificate whose `spec.secretName` matches the generated value.


## S3 configuration source and validation
- When `minio.enabled=true`, all Mattermost S3 settings (bucket, endpoint, region, credentials) are sourced from the MinIO subchart. The chart discovers the credentials from the Bitnami MinIO Secret and wires them into the `mm-s3` Secret. The Mattermost CR’s `fileStore` and `FileSettings` are rendered from MinIO values.
- When `minio.enabled=false` and `externalS3.enabled=true`, the S3 settings come from `externalS3` and `mattermost.s3` values.
- Validation: the chart now fails rendering if both `minio.enabled` and `externalS3.enabled` are set to `true`, or if both are `false`. Enable exactly one object store.



## Should we commit Chart.lock and vendored charts/ here?
Short answer: Not required. Since this chart uses upstream dependencies, you can rely on Helm to fetch them at deploy time and avoid committing `Chart.lock` and the `charts/` directory.

Why you might avoid committing them:
- Simpler repo: fewer large binary blobs; cleaner diffs.
- Always-resolved dependencies: your CI/Argo pipeline can run `helm dependency update` to fetch latest that match your constraints in Chart.yaml.
- Avoids accidental drift between lockfile and Chart.yaml.

When you might still vendor/lock:
- Air-gapped/offline clusters.
- Strict reproducibility without network access.
- Known-good frozen set for change-controlled environments.

Recommended workflow (non-vendored):
1) Ensure repos are configured in CI/Argo: `helm repo add mattermost https://helm.mattermost.com && helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update`
2) Resolve dependencies at build/render time: `helm dependency update ./tryonmagic-mattermost/mgmt`
3) Render/install as usual: `helm template` or `helm install/upgrade`

Version constraints:
- Set sensible version ranges in `Chart.yaml` dependencies (e.g., `^1.0.0`) instead of `*` if you want to avoid breaking changes while not pinning exact versions.

Notes:
- This repo includes a `.gitignore` in `tryonmagic-mattermost/mgmt` to exclude `Chart.lock` and `charts/` from future commits.
- If you choose to vendor later (e.g., for air‑gapped), remove those lines from `.gitignore` and commit the lockfile and `charts/` directory.


## Note on MinIO Helm repository
This chart now uses the official MinIO Helm chart as a dependency. Ensure you add the MinIO repo before building dependencies:

```bash
helm repo add minio https://charts.min.io/
helm repo update
```

If you already had the Bitnami MinIO repo configured previously, it is no longer used for this chart. PostgreSQL still uses the Bitnami repository.
