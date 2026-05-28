pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USER        = "${DOCKERHUB_CREDENTIALS_USR}"
        BACKEND_IMAGE         = "${DOCKERHUB_CREDENTIALS_USR}/contactos-backend"
        FRONTEND_IMAGE        = "${DOCKERHUB_CREDENTIALS_USR}/contactos-frontend"
        IMAGE_TAG             = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Clonando repositorio...'
                checkout scm
            }
        }

        stage('Build Backend') {
            steps {
                echo 'Construyendo imagen del backend...'
                sh 'docker build -t $BACKEND_IMAGE:$IMAGE_TAG -t $BACKEND_IMAGE:latest ./backend'
            }
        }

        stage('Build Frontend') {
            steps {
                echo 'Construyendo imagen del frontend...'
                sh 'docker build -t $FRONTEND_IMAGE:$IMAGE_TAG -t $FRONTEND_IMAGE:latest ./frontend'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo 'Publicando imagenes en Docker Hub...'
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                sh 'docker push $BACKEND_IMAGE:$IMAGE_TAG'
                sh 'docker push $BACKEND_IMAGE:latest'
                sh 'docker push $FRONTEND_IMAGE:$IMAGE_TAG'
                sh 'docker push $FRONTEND_IMAGE:latest'
            }
            post {
                always {
                    sh 'docker logout'
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo 'Desplegando en Kubernetes...'
                sh 'kubectl apply -f k8s/'
                sh 'kubectl rollout restart deployment/backend -n devops-lab'
                sh 'kubectl rollout restart deployment/frontend -n devops-lab'
            }
        }

        stage('Verify') {
            steps {
                echo 'Verificando pods...'
                sh 'kubectl get pods -n devops-lab'
            }
        }
    }

    post {
        success { echo 'Pipeline completado exitosamente.' }
        failure { echo 'Pipeline fallido. Revisar logs.' }
    }
}
