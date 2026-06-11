#!/bin/bash
set -e

MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"

# Copiar certificados al contenedor
docker exec jenkins mkdir -p /root/.minikube/profiles/minikube
docker cp ~/.minikube/profiles/minikube/client.crt jenkins:/root/.minikube/profiles/minikube/client.crt
docker cp ~/.minikube/profiles/minikube/client.key jenkins:/root/.minikube/profiles/minikube/client.key
docker cp ~/.minikube/ca.crt jenkins:/root/.minikube/ca.crt

# Corregir rutas en kubeconfig
docker exec jenkins sed -i \
  "s|/Users/jose/.minikube/ca.crt|/root/.minikube/ca.crt|g; \
   s|/Users/jose/.minikube/profiles/minikube/client.crt|/root/.minikube/profiles/minikube/client.crt|g; \
   s|/Users/jose/.minikube/profiles/minikube/client.key|/root/.minikube/profiles/minikube/client.key|g" \
  /root/.kube/config

# Apuntar al IP real de Minikube
docker exec jenkins sed -i "s|https://127.0.0.1:[0-9]*|https://$MINIKUBE_IP:8443|g" /root/.kube/config

echo "Verificando conexion con Kubernetes..."
docker exec jenkins kubectl get nodes

# Recrear dashboard de Grafana (se pierde al reiniciar el pod)
echo "Recreando dashboard de Grafana..."
sleep 5
curl -s -u admin:admin123 -X POST http://$MINIKUBE_IP:30030/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d '{
  "dashboard": {
    "title": "DevOps Lab - Monitoreo Completo",
    "uid": "devops-lab-main",
    "timezone": "browser",
    "refresh": "10s",
    "panels": [
      {
        "id": 1,
        "title": "Estado de Pods - devops-lab",
        "type": "table",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0},
        "targets": [{"datasource": "Prometheus", "expr": "kube_pod_status_phase{namespace=\"devops-lab\", phase=\"Running\"}", "legendFormat": "{{pod}}", "instant": true}],
        "options": {"showHeader": true}
      },
      {
        "id": 2,
        "title": "Pods Running",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 8},
        "targets": [{"datasource": "Prometheus", "expr": "count(kube_pod_status_phase{namespace=\"devops-lab\", phase=\"Running\"} == 1)", "legendFormat": "Pods activos"}],
        "options": {"colorMode": "background"},
        "fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "green"}}}
      },
      {
        "id": 3,
        "title": "HTTP Requests Totales (Backend)",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 8},
        "targets": [{"datasource": "Prometheus", "expr": "sum(http_requests_total)", "legendFormat": "Total requests"}],
        "options": {"colorMode": "background"},
        "fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "blue"}}}
      },
      {
        "id": 4,
        "title": "Memoria Backend (MB)",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 12, "y": 8},
        "targets": [{"datasource": "Prometheus", "expr": "process_resident_memory_bytes / 1024 / 1024", "legendFormat": "Memoria MB"}],
        "options": {"colorMode": "background"},
        "fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "orange"}, "unit": "MB"}}
      },
      {
        "id": 5,
        "title": "Memoria Nodo Disponible (GB)",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 18, "y": 8},
        "targets": [{"datasource": "Prometheus", "expr": "node_memory_MemAvailable_bytes / 1024 / 1024 / 1024", "legendFormat": "Memoria libre GB"}],
        "options": {"colorMode": "background"},
        "fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "purple"}, "unit": "GB"}}
      },
      {
        "id": 6,
        "title": "HTTP Requests por Ruta",
        "type": "bargauge",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
        "targets": [{"datasource": "Prometheus", "expr": "sum by(route) (http_requests_total)", "legendFormat": "{{route}}"}],
        "options": {"orientation": "horizontal"}
      },
      {
        "id": 7,
        "title": "CPU Nodo (%)",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
        "targets": [{"datasource": "Prometheus", "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[1m])) * 100)", "legendFormat": "CPU usada %"}]
      },
      {
        "id": 8,
        "title": "Memoria Backend en el tiempo",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 20},
        "targets": [{"datasource": "Prometheus", "expr": "process_resident_memory_bytes / 1024 / 1024", "legendFormat": "Memoria RSS (MB)"}],
        "fieldConfig": {"defaults": {"unit": "mbytes"}}
      },
      {
        "id": 9,
        "title": "Requests por Status HTTP",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 20},
        "targets": [{"datasource": "Prometheus", "expr": "sum by(status) (http_requests_total)", "legendFormat": "HTTP {{status}}"}]
      }
    ],
    "schemaVersion": 36,
    "version": 1
  },
  "overwrite": true,
  "folderId": 0
}' | grep -o '"status":"[^"]*"'

echo ""
echo "============================================"
echo "Todo listo!"
echo "Jenkins:    http://localhost:8090"
echo "Frontend:   http://$MINIKUBE_IP:30080"
echo "Backend:    http://$MINIKUBE_IP:30300"
echo "Prometheus: http://$MINIKUBE_IP:30090"
echo "Grafana:    http://$MINIKUBE_IP:30030"
echo "Dashboard:  http://$MINIKUBE_IP:30030/d/devops-lab-main"
echo "============================================"
