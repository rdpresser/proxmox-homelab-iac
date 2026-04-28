# Observability Stack

Plug-and-play LGTM observability stack for homelab and local development.
Runs on Docker Compose or Podman Compose — no configuration required to start.

## Stack

| Service | Image | Port | Role |
|---|---|---|---|
| Grafana | `grafana/grafana:12.3.2` | `3000` | Dashboards & visualization |
| Loki | `grafana/loki:3.6.4` | `3100` | Log aggregation |
| Tempo | `grafana/tempo:2.10.0` | `3200` | Distributed tracing |
| Prometheus | `prom/prometheus:v3.9.1` | `9090` | Metrics storage |
| OTEL Collector | `otel/opentelemetry-collector-contrib:0.144.0` | `4317` (gRPC) / `4318` (HTTP) | Telemetry gateway |

## Architecture

```
Your App
  │
  ▼  OTLP gRPC/HTTP
otel-collector:4317/4318
  ├── traces  ──► Tempo:3200
  ├── metrics ──► Prometheus (via :8889 scrape)
  └── logs    ──► Loki:3100/otlp

Grafana:3000
  ├── datasource: Prometheus
  ├── datasource: Loki
  └── datasource: Tempo
```

All services run on the `observability-network` bridge network. Other compose stacks can attach to it with:

```yaml
networks:
  observability-network:
    external: true
```

## Infrastructure

- **Hypervisor:** Proxmox VE
- **Runtime:** Podman (rootless) in an LXC container
- **Network mode:** Bridge (`observability-network`)
- **Persistence:** Named volumes for all stateful services

## Quick Start

```bash
# Clone and start
git clone <repo-url>
cd <root-folder>
docker compose up -d        # or: podman-compose up -d

# Open Grafana
open http://localhost:3000
# Default credentials: admin / admin
```

No `.env` file is needed. All defaults are baked into `docker-compose.yml`.

## Configuration

### Overriding defaults

Copy `.env.example` to `.env` and edit as needed:

```bash
cp .env.example .env
```

Configurable values:

| Variable | Default | Description |
|---|---|---|
| `GRAFANA_ADMIN_USER` | `admin` | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | `admin` | Grafana admin password |
| `GRAFANA_PORT` | `3000` | Grafana host port |
| `PROMETHEUS_PORT` | `9090` | Prometheus host port |
| `LOKI_PORT` | `3100` | Loki host port |
| `TEMPO_PORT` | `3200` | Tempo host port |
| `OTEL_GRPC_PORT` | `4317` | OTEL Collector gRPC port |
| `OTEL_HTTP_PORT` | `4318` | OTEL Collector HTTP port |
| `PROMETHEUS_RETENTION` | `15d` | Prometheus data retention |

### Adding your own services to Prometheus

Edit `<root-folder>/observability/prometheus/prometheus.yml` and add a new `scrape_config`:

```yaml
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['my-service:8080']
        labels:
          service: 'my-service'
    metrics_path: '/metrics'
```

## Connecting your application

Point your OTEL exporter to the collector:

| Protocol | Endpoint |
|---|---|
| gRPC | `http://<host-ip>:4317` |
| HTTP/protobuf | `http://<host-ip>:4318` |

For apps in the **same compose network** (`observability-network`):

```
http://otel-collector:4317   # gRPC
http://otel-collector:4318   # HTTP
```

### .NET example (appsettings.json)

```json
{
  "Telemetry": {
    "Otlp": {
      "Endpoint": "http://otel-collector:4318",
      "Protocol": "http/protobuf"
    }
  }
}
```

### Environment variable example

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://<host-ip>:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_SERVICE_NAME=my-service
```

## Directory Structure

```
<root-folder>/
├── docker-compose.yml                          # Main compose file
├── .env.example                                # Optional overrides template
├── README.md
└── observability/
    ├── loki/
    │   └── config.yml                          # Loki config (TSDB, OTLP ingestion)
    ├── tempo/
    │   └── config.yml                          # Tempo config (metrics generator enabled)
    ├── otel-collector/
    │   └── config.yml                          # OTEL Collector pipelines
    ├── prometheus/
    │   └── prometheus.yml                      # Scrape configs
    └── grafana/
        └── provisioning/
            ├── datasources/
            │   └── datasource.yml              # Auto-provisioned: Prometheus, Loki, Tempo
            └── dashboards/
                ├── dashboards.yml              # Dashboard provider config
                └── json/
                    ├── golden-signals.json     # Requests, errors, latency, CPU/memory
                    ├── red.json                # Rate / Error / Duration per route
                    ├── use.json                # Utilization / Saturation / Errors
                    ├── logs-overview.json      # Loki log explorer
                    ├── metrics-overview.json   # General metrics overview
                    └── traces-overview.json    # Tempo trace search
```

## Pre-built Dashboards

| Dashboard | Description |
|---|---|
| **Golden Signals** | Requests/sec, error rate, p95/p99 latency, CPU, memory |
| **RED Metrics** | Request rate, error rate, duration per route |
| **USE Metrics** | CPU utilization, memory usage, GC pause (ideal for .NET) |
| **Logs Overview** | Live log stream from Loki |
| **Metrics Overview** | General metrics from Prometheus |
| **Traces Overview** | Trace search via Tempo |

## Useful Commands

```bash
# Start stack
docker compose up -d

# Stop stack
docker compose down

# View logs for a specific service
docker compose logs -f otel-collector

# Reload Prometheus config without restart
curl -X POST http://localhost:9090/-/reload

# Check OTEL Collector health
curl http://localhost:13133/

# Restart only Grafana
docker compose restart grafana
```
