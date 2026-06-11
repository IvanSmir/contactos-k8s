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

echo "Verificando conexion..."
docker exec jenkins kubectl get nodes
echo "Listo!"
