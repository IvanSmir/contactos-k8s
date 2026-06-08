# Contactos K8s – Plataforma DevOps Completa

Proyecto integrador de CI/CD con Jenkins, Kubernetes y Monitoreo.

## Arquitectura

```
GitHub → Jenkins → Docker Hub → Kubernetes
                                    ├── backend (Node.js + Express)
                                    ├── frontend (Nginx)
                                    ├── postgres (Base de datos)
                                    ├── prometheus (Métricas)
                                    └── grafana (Dashboards)
```

## Tecnologías

| Capa | Tecnología |
|------|-----------|
| CI/CD | Jenkins |
| Contenedores | Docker |
| Orquestación | Kubernetes |
| Monitoreo | Prometheus + Grafana |
| Control de versiones | Git / GitHub |
| Backend | Node.js + Express |
| Frontend | HTML + Nginx |
| Base de datos | PostgreSQL |

## Estructura del repositorio

```
contactos-k8s/
├── backend/
│   ├── index.js          # API REST (Express)
│   ├── package.json
│   └── Dockerfile
├── frontend/
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile
├── k8s/
│   ├── 00-namespace.yaml
│   ├── 01-postgres-secret.yaml
│   ├── 02-postgres.yaml
│   ├── 03-backend-configmap.yaml
│   ├── 04-backend.yaml
│   ├── 05-frontend.yaml
│   ├── 06-prometheus.yaml
│   └── 07-grafana.yaml
├── jenkins/
│   └── Dockerfile        # Jenkins con Docker CLI + kubectl + git
├── Jenkinsfile.backend
├── Jenkinsfile.frontend
└── docker-compose.jenkins.yml
```

## Instalación y ejecución

### 1. Iniciar Minikube

```bash
minikube start
kubectl get nodes
```

### 2. Levantar Jenkins

```bash
docker compose -f docker-compose.jenkins.yml up -d --build
```

Jenkins disponible en: http://localhost:8090

Obtener contraseña inicial:
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 3. Configurar Jenkins

**Credenciales Docker Hub:**
- Manage Jenkins → Credentials → Global → Add Credentials
- Kind: `Username with password`
- ID: `dockerhub-credentials`

**Crear pipelines:**
- `contactos-backend` → Script Path: `Jenkinsfile.backend`
- `contactos-frontend` → Script Path: `Jenkinsfile.frontend`
- Repository URL: `https://github.com/IvanSmir/contactos-k8s.git`

### 4. Desplegar en Kubernetes

Aplicar todos los manifiestos:
```bash
kubectl apply -f k8s/
```

Verificar que todo esté corriendo:
```bash
kubectl get pods -n devops-lab
kubectl get svc -n devops-lab
```

**Deploy manual desde Jenkins:**
- Ir al pipeline → **Build with Parameters** → activar `DEPLOY = true`

### 5. Acceder a los servicios

```bash
minikube ip  # obtener la IP
```

| Servicio | Puerto |
|----------|--------|
| Frontend | `<minikube-ip>:30080` |
| Prometheus | `<minikube-ip>:30090` |
| Grafana | `<minikube-ip>:30030` |

Grafana: usuario `admin` / contraseña `admin123`

## Pipeline CI/CD

```
Stage 1: Checkout        → Obtiene código de GitHub
Stage 2: Build           → npm install
Stage 3: Docker Build    → Construye imagen Docker
Stage 4: Push            → Publica en Docker Hub
Stage 5: Deploy (manual) → kubectl apply en Kubernetes
Stage 6: Validación      → Verifica pods y accesibilidad
```

El deploy en Kubernetes es **manual**: se activa marcando el parámetro `DEPLOY = true` al correr el pipeline.

## Endpoints del backend

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/health` | Estado del servicio |
| GET | `/version` | Versión de la aplicación |
| GET | `/metrics` | Métricas Prometheus |
| GET | `/contactos` | Listar contactos |
| GET | `/contactos?search=texto` | Buscar contactos |
| POST | `/contactos` | Crear contacto |
| DELETE | `/contactos/:id` | Eliminar contacto |

## Monitoreo

**Prometheus** (puerto 30090) recolecta métricas de:
- Pods del namespace `devops-lab`
- Endpoint `/metrics` del backend (requests HTTP por ruta y status)
- Métricas de Node.js (CPU, memoria, event loop)

**Grafana** (puerto 30030) muestra dashboards de:
- Estado de pods
- Consumo de CPU y memoria
- Total de requests HTTP

Datasource de Prometheus ya configurado automáticamente al iniciar.

## Escalado

```bash
kubectl scale deployment backend -n devops-lab --replicas=3
kubectl get pods -n devops-lab
```

## Diagnóstico

```bash
kubectl logs -n devops-lab deployment/backend
kubectl logs -n devops-lab deployment/frontend
kubectl describe pod <nombre-pod> -n devops-lab
kubectl get events -n devops-lab --sort-by=.metadata.creationTimestamp
```

## Limpieza

```bash
kubectl delete namespace devops-lab
minikube stop
docker compose -f docker-compose.jenkins.yml down
```

## Problemas encontrados

- **Maven 3.9.9 no disponible** en mirror de Apache → resuelto usando `repo.maven.apache.org`
- **Permisos docker.sock en Mac** → resuelto con `user: root` en docker-compose
- **Workspace corrupto en Jenkins** → resuelto borrando el workspace manualmente
- **git no instalado en contenedor Jenkins** → agregado al Dockerfile
