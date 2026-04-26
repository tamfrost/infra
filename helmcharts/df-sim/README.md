# df-sim Helm Chart

Helm chart for deploying the df-sim antenna API application to Kubernetes/OpenShift.

## Prerequisites

- Kubernetes 1.19+ or OpenShift 4.x
- Helm 3.x
- GitHub Personal Access Token with `read:packages` scope (for private registry access)

## Installation

### Quick Start

Install the chart with a release name `df-sim`:

```bash
helm install df-sim . --namespace default
```

### With GitHub Container Registry Authentication

To pull images from GitHub Container Registry, provide your GitHub Personal Access Token:

```bash
helm install df-sim . \
  --set githubToken=YOUR_GITHUB_PAT \
  --namespace default
```

### From Environment Variables

Load the PAT from a `.env` file:

```bash
# PowerShell
$pat = (Get-Content ../.env | Select-String 'CONTAINER_REGISTRY_PAT' | ForEach-Object { ($_ -replace 'CONTAINER_REGISTRY_PAT=','').Trim() })
helm install df-sim . --set githubToken=$pat --namespace default

# Bash
export GITHUB_TOKEN=$(grep CONTAINER_REGISTRY_PAT ../.env | cut -d'=' -f2)
helm install df-sim . --set githubToken=$GITHUB_TOKEN --namespace default
```

## Upgrading

Upgrade an existing release:

```bash
helm upgrade df-sim . \
  --set githubToken=YOUR_GITHUB_PAT \
  --namespace default
```

## Uninstalling

Remove the release:

```bash
helm uninstall df-sim --namespace default
```

## Configuration

The following table lists the configurable parameters and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.registry` | Container registry | `ghcr.io` |
| `image.repository` | Image repository | `tamfrost/df-sim` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `githubToken` | GitHub PAT for GHCR authentication | `""` |
| `githubUsername` | GitHub username | `tamfrost` |
| `imagePullSecrets` | Additional image pull secrets | `[]` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `8080` |
| `ingress.enabled` | Enable ingress | `false` |
| `resources` | CPU/memory resource requests/limits | `{}` |
| `autoscaling.enabled` | Enable horizontal pod autoscaling | `false` |
| `nodeSelector` | Node labels for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity rules for pod assignment | `{}` |

### Example with Custom Values

Create a `values-custom.yaml`:

```yaml
replicaCount: 3

image:
  tag: "v1.0.0"

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

ingress:
  enabled: true
  hosts:
    - host: df-sim.example.com
      paths:
        - path: /
          pathType: Prefix
```

Install with custom values:

```bash
helm install df-sim . -f values-custom.yaml --set githubToken=YOUR_PAT
```

## OpenShift Specific

### Exposing via Route

On OpenShift, create a route to expose the service externally:

```bash
oc expose svc/df-sim
oc get route df-sim -o jsonpath='{.spec.host}'
```

### DNS Configuration

For local OpenShift (CRC), add the route to your hosts file:

```
192.168.68.107  df-sim-default.apps-crc.testing
```

## Accessing the Application

### Via Port Forward

```bash
kubectl port-forward svc/df-sim 8080:80
# Access at http://localhost:8080
```

### Via Ingress/Route

Access at the configured hostname (e.g., `http://df-sim-default.apps-crc.testing`)

## Troubleshooting

### Image Pull Errors

If pods show `ImagePullBackOff`:

1. Verify the PAT has `read:packages` scope
2. Check the image exists: `docker pull ghcr.io/tamfrost/df-sim:latest`
3. Verify the secret was created: `kubectl get secret <release-name>-ghcr`

### Pod Not Starting

Check pod logs:
```bash
kubectl logs -l app.kubernetes.io/name=df-sim --tail=50
```

Check pod events:
```bash
kubectl describe pod -l app.kubernetes.io/name=df-sim
```

## Development

### Testing Locally

```bash
# Lint the chart
helm lint .

# Render templates
helm template df-sim . --set githubToken=test

# Dry run
helm install df-sim . --dry-run --debug --set githubToken=test
```

## License

See repository license.
