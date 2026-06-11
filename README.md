# Contactos K8s – Plataforma DevOps Completa

Proyecto integrador de CI/CD con Jenkins, Kubernetes y Monitoreo para el examen final de DevOps.

**Empresa:** ContactosTech S.A.

---

## Arquitectura

```
Developer
    └── git push → GitHub
                       └── Jenkins (Docker)
                                   ├── npm install
                                   ├── docker build
                                   ├── docker push → Docker Hub
                                   └── kubectl apply → Minikube (Kubernetes)
                                                           ├── namespace: devops-lab
                                                           ├── backend (Node.js)
                                                           ├── frontend (Nginx)
                                                           ├── postgres
                                                           ├── prometheus
                                                           ├── grafana
                                                           ├── kube-state-metrics
                                                           └── node-exporter
```

---

## Tecnologías

| Capa | Tecnología |
|------|-----------|
| CI/CD | Jenkins |
| Contenedores | Docker |
| Orquestación | Kubernetes (Minikube) |
| Monitoreo | Prometheus + Grafana |
| Control de versiones | Git / GitHub |
| Backend | Node.js + Express |
| Frontend | HTML + Nginx |
| Base de datos | PostgreSQL |

---

## Estructura del repositorio

```
contactos-k8s/
├── backend/
│   ├── index.js              # API REST con /health, /version, /metrics
│   ├── package.json          # dependencias: express, pg, prom-client
│   ├── Dockerfile
│   └── .dockerignore
├── frontend/
│   ├── index.html
│   ├── nginx.conf
│   ├── Dockerfile
│   └── .dockerignore
├── k8s/
│   ├── 00-namespace.yaml         # namespace devops-lab
│   ├── 01-postgres-secret.yaml   # credenciales DB en base64
│   ├── 02-postgres.yaml          # base de datos
│   ├── 03-backend-configmap.yaml # variables de configuración
│   ├── 04-backend.yaml           # deployment + service NodePort 30300
│   ├── 05-frontend.yaml          # deployment + service NodePort 30080
│   ├── 06-prometheus.yaml        # prometheus + RBAC
│   ├── 07-grafana.yaml           # grafana + dashboards
│   └── 08-kube-state-metrics.yaml # métricas de pods + node-exporter
├── jenkins/
│   └── Dockerfile            # Jenkins con Docker CLI + Node.js + kubectl + git
├── Jenkinsfile               # pipeline CI/CD con 6 stages
├── Jenkinsfile.backend       # pipeline solo backend
├── Jenkinsfile.frontend      # pipeline solo frontend
├── docker-compose.jenkins.yml
├── setup-jenkins-k8s.sh      # conecta Jenkins con Minikube
└── README.md
```

---

## Requisitos previos

```bash
docker --version      # Docker Desktop instalado
minikube version      # Minikube instalado
kubectl version --client
git --version
```

Instalar Minikube si no está:
```bash
brew install minikube
```

---

## Instalación y ejecución completa

### Paso 1 — Iniciar Minikube

```bash
minikube start
minikube addons enable metrics-server
kubectl get nodes
# minikube   Ready   control-plane
```

### Paso 2 — Clonar el repositorio

```bash
git clone https://github.com/IvanSmir/contactos-k8s.git
cd contactos-k8s
```

### Paso 3 — Levantar Jenkins

```bash
docker compose -f docker-compose.jenkins.yml up -d --build
```

Verificar que Jenkins está corriendo:
```bash
docker ps | grep jenkins
```

### Paso 4 — Conectar Jenkins con Minikube

```bash
./setup-jenkins-k8s.sh
```

Verificar conexión:
```bash
docker exec jenkins kubectl get nodes
# minikube   Ready
```

### Paso 5 — Obtener contraseña inicial de Jenkins

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Abrir **http://localhost:8090** y completar la configuración inicial.

### Paso 6 — Configurar credenciales en Jenkins

**Manage Jenkins → Credentials → Global → Add Credentials**

| Campo | Valor |
|-------|-------|
| Kind | Username with password |
| Username | tu usuario de Docker Hub |
| Password | tu password o Access Token |
| ID | `dockerhub-credentials` |

### Paso 7 — Crear el pipeline en Jenkins

1. **New Item** → nombre: `contactos-ci` → **Pipeline** → OK
2. Bajar hasta sección **Pipeline**
3. Definition: `Pipeline script from SCM`
4. SCM: `Git`
5. Repository URL: `https://github.com/IvanSmir/contactos-k8s.git`
6. Branch: `*/main`
7. Script Path: `Jenkinsfile`
8. **Save**

---

## Ejecutar el pipeline

### CI — Solo build y push (sin deploy)

Jenkins → `contactos-ci` → **Build Now**

```
Stage 1 - Checkout      → descarga código de GitHub
Stage 2 - Build         → npm install en el backend
Stage 3 - Docker Build  → construye imágenes backend y frontend en paralelo
Stage 4 - Push          → publica en Docker Hub con tag :latest y :N° de build
```

### CD — Build + deploy en Kubernetes (manual)

Jenkins → `contactos-ci` → **Build with Parameters** → activar `DEPLOY = true` → **Build**

```
Stage 1 - Checkout
Stage 2 - Build
Stage 3 - Docker Build
Stage 4 - Push
Stage 5 - Deploy        → kubectl apply -f k8s/ + actualiza imágenes
Stage 6 - Validación    → verifica pods activos + /health + /version
```

---

## Desplegar en Kubernetes manualmente

```bash
# Aplicar todos los manifiestos
docker exec jenkins kubectl apply -f k8s/

# Verificar que todo está corriendo
docker exec jenkins kubectl get all -n devops-lab
```

Resultado esperado:
```
NAME                                  READY   STATUS
pod/backend-xxx                       1/1     Running
pod/frontend-xxx                      1/1     Running
pod/grafana-xxx                       1/1     Running
pod/kube-state-metrics-xxx            1/1     Running
pod/node-exporter-xxx                 1/1     Running
pod/postgres-xxx                      1/1     Running
pod/prometheus-xxx                    1/1     Running
```

---

## Probar cada servicio

Obtener la IP de Minikube:
```bash
minikube ip
# 192.168.49.2
```

### Frontend
```bash
curl http://192.168.49.2:30080
# Abre en navegador: http://192.168.49.2:30080
```

### Backend — endpoints obligatorios
```bash
# Health check
curl http://192.168.49.2:30300/health
# {"status":"ok","service":"contactos-backend"}

# Version
curl http://192.168.49.2:30300/version
# {"version":"1.0.0","service":"contactos-backend","environment":"development"}

# Métricas Prometheus
curl http://192.168.49.2:30300/metrics
# process_cpu_seconds_total, http_requests_total, ...

# API de contactos
curl http://192.168.49.2:30300/contactos
```

### ConfigMap y Secret
```bash
# Ver ConfigMap (variables de configuración)
docker exec jenkins kubectl describe configmap backend-config -n devops-lab

# Ver Secrets (credenciales)
docker exec jenkins kubectl get secret -n devops-lab
docker exec jenkins kubectl describe secret postgres-secret -n devops-lab
```

---

## Monitoreo

### Prometheus — http://192.168.49.2:30090

Ir a **Status → Targets** para ver todos los servicios monitoreados:
- `contactos-backend` — métricas de la aplicación
- `kube-state-metrics` — estado de pods y deployments
- `node-exporter` — CPU y memoria del nodo
- `kubernetes-nodes` — métricas del cluster
- `prometheus` — automonitoreo

**Queries para demostrar en el examen:**

| Qué muestra | Query |
|-------------|-------|
| Requests totales al backend | `http_requests_total` |
| Requests por ruta | `sum by(route) (http_requests_total)` |
| CPU del nodo | `rate(node_cpu_seconds_total{mode!="idle"}[1m])` |
| Memoria disponible | `node_memory_MemAvailable_bytes` |
| Estado de pods | `kube_pod_status_phase` |
| Pods corriendo | `kube_pod_status_ready{condition="true"}` |
| CPU del backend | `rate(process_cpu_seconds_total[1m])` |
| Memoria del backend | `process_resident_memory_bytes` |

### Grafana — http://192.168.49.2:30030

Usuario: `admin` / Contraseña: `admin123`

**Dashboard preconfigurado:**
- Ir a **Dashboards → DevOps Lab → Contactos App - Monitoreo**
- Muestra: requests HTTP, CPU, memoria, requests por status

**Importar dashboard de Kubernetes (recomendado para el examen):**
1. Dashboards → **Import**
2. ID: `315` → **Load**
3. Seleccionar datasource: `Prometheus`
4. **Import**

Muestra: CPU/memoria por pod, estado del cluster, network.

---

## Comandos útiles para el examen

```bash
# Ver todos los recursos del namespace
docker exec jenkins kubectl get all -n devops-lab

# Ver logs del backend
docker exec jenkins kubectl logs -n devops-lab deployment/backend

# Ver variables de entorno del backend (ConfigMap + Secret)
docker exec jenkins kubectl describe pod -n devops-lab -l app=backend

# Escalar el backend (para demostrar resiliencia)
docker exec jenkins kubectl scale deployment backend -n devops-lab --replicas=3
docker exec jenkins kubectl get pods -n devops-lab

# Matar un pod y ver que Kubernetes lo recrea (resiliencia)
docker exec jenkins kubectl delete pod -n devops-lab -l app=backend
docker exec jenkins kubectl get pods -n devops-lab -w

# Rollback a versión anterior
docker exec jenkins kubectl rollout undo deployment/backend -n devops-lab

# Ver historial de deployments
docker exec jenkins kubectl rollout history deployment/backend -n devops-lab
```

---

## Reiniciar el entorno (si se apaga la computadora)

```bash
# 1. Arrancar Minikube
minikube start

# 2. Levantar Jenkins
docker compose -f docker-compose.jenkins.yml up -d

# 3. Reconectar Jenkins con Minikube
./setup-jenkins-k8s.sh

# 4. Verificar
docker exec jenkins kubectl get nodes
docker exec jenkins kubectl get pods -n devops-lab
```

---

## URLs de acceso

| Servicio | URL |
|----------|-----|
| Jenkins | http://localhost:8090 |
| Frontend | http://192.168.49.2:30080 |
| Backend /health | http://192.168.49.2:30300/health |
| Backend /version | http://192.168.49.2:30300/version |
| Backend /metrics | http://192.168.49.2:30300/metrics |
| Prometheus | http://192.168.49.2:30090 |
| Grafana | http://192.168.49.2:30030 |

> Reemplazar `192.168.49.2` con el resultado de `minikube ip` si es diferente.

---

## Problemas encontrados y soluciones

| Problema | Solución |
|----------|----------|
| Permisos denegados en docker.sock en Mac | Agregar `user: root` en docker-compose |
| Workspace corrupto en Jenkins | `docker exec jenkins rm -rf /var/jenkins_home/workspace/contactos-ci` |
| git no instalado en Jenkins | Agregar `git` al Dockerfile de Jenkins |
| npm no instalado en Jenkins | Agregar Node.js 18 al Dockerfile de Jenkins |
| Jenkins no conecta con Minikube | Correr `./setup-jenkins-k8s.sh` después de cada reinicio |
| kubeconfig apunta a rutas del host | Script corrige rutas a `/root/.minikube/` dentro del contenedor |
| Backend sin acceso externo | Cambiar Service de `ClusterIP` a `NodePort 30300` |
| Prometheus sin métricas de pods/CPU | Agregar `kube-state-metrics` y `node-exporter` con RBAC |
