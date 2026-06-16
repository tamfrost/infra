# DF-Proxy Application Helm Chart

This Helm chart deploys the DF-Proxy application with PostgreSQL and MongoDB databases.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Ingress controller (nginx recommended)

## Installation

```bash
# Install with default values
helm install df-proxy .helm/app

# Install with custom values
helm install df-proxy .helm/app -f custom-values.yaml

# Install in a specific namespace
helm install df-proxy .helm/app -n df-proxy --create-namespace
```

## Configuration

### Key Values

- `replicaCount`: Number of application replicas (default: 1)
- `image.repository`: Docker image repository
- `image.tag`: Docker image tag
- `service.port`: Service port (default: 8080)
- `ingress.enabled`: Enable ingress (default: true)
- `ingress.hosts[0].paths[0].path`: Ingress path with rewrite (default: `/df-proxy(/|$)(.*)`)

### Database Configuration

The chart includes PostgreSQL and MongoDB as dependencies:

```yaml
postgresql:
  enabled: true
  auth:
    username: admin
    password: password
    database: df-proxy

mongodb:
  enabled: true
  auth:
    username: admin
    password: password
    database: df-proxy
```

## Ingress Configuration

The chart is configured to serve the application at `/df-proxy` path:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
  hosts:
    - host: ""  # Any host
      paths:
        - path: /df-proxy(/|$)(.*)
          pathType: ImplementationSpecific
```

This configuration:
- Serves the app at `http://your-domain/df-proxy/`
- Rewrites paths so the app sees them as relative
- Works with the frontend's relative API paths

## Uninstallation

```bash
helm uninstall df-proxy
```
