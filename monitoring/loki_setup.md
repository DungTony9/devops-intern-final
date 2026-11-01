# Grafana Loki Log Aggregation Setup

## 1. Starting the Monitoring Stack

From the repository root, start Loki, Promtail, and Grafana using Docker Compose:

```bash
docker compose -f monitoring/docker-compose.yaml up -d