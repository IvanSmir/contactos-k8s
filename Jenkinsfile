pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        BACKEND_IMAGE         = "${DOCKERHUB_CREDENTIALS_USR}/contactos-backend"
        FRONTEND_IMAGE        = "${DOCKERHUB_CREDENTIALS_USR}/contactos-frontend"
        IMAGE_TAG             = "${BUILD_NUMBER}"
    }

    parameters {
        booleanParam(name: 'DEPLOY', defaultValue: false, description: 'Desplegar en Kubernetes luego del build?')
    }

    stages {

        // STAGE 1 - Checkout
        stage('Checkout') {
            steps {
                echo 'Obteniendo codigo fuente desde GitHub...'
                checkout scm
            }
        }

        // STAGE 2 - Build
        stage('Build') {
            steps {
                echo 'Instalando dependencias del backend...'
                dir('backend') {
                    sh 'npm install --production'
                }
                echo 'Verificando archivos del frontend...'
                dir('frontend') {
                    sh 'ls -la'
                }
            }
        }

        // STAGE 3 - Docker Build
        stage('Docker Build') {
            parallel {
                stage('Backend Image') {
                    steps {
                        echo 'Construyendo imagen del backend...'
                        sh 'docker build -t $BACKEND_IMAGE:$IMAGE_TAG -t $BACKEND_IMAGE:latest ./backend'
                    }
                }
                stage('Frontend Image') {
                    steps {
                        echo 'Construyendo imagen del frontend...'
                        sh 'docker build -t $FRONTEND_IMAGE:$IMAGE_TAG -t $FRONTEND_IMAGE:latest ./frontend'
                    }
                }
            }
        }

        // STAGE 4 - Push
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

        // STAGE 5 - Deploy en Kubernetes (MANUAL)
        stage('Deploy en Kubernetes') {
            when {
                expression { return params.DEPLOY == true }
            }
            steps {
                echo 'Desplegando toda la aplicacion en Kubernetes...'
                sh 'kubectl apply -f k8s/'
                sh "kubectl set image deployment/backend backend=$BACKEND_IMAGE:$IMAGE_TAG -n devops-lab"
                sh "kubectl set image deployment/frontend frontend=$FRONTEND_IMAGE:$IMAGE_TAG -n devops-lab"
                sh 'kubectl rollout status deployment/backend -n devops-lab --timeout=90s'
                sh 'kubectl rollout status deployment/frontend -n devops-lab --timeout=90s'
            }
        }

        // STAGE 6 - Validacion
        stage('Validacion') {
            when {
                expression { return params.DEPLOY == true }
            }
            steps {
                echo 'Verificando estado de los pods...'
                sh 'kubectl get pods -n devops-lab'
                sh 'kubectl get svc -n devops-lab'
                echo 'Verificando endpoints de la aplicacion...'
                sh '''
                    BACKEND_IP=$(kubectl get svc backend-service -n devops-lab -o jsonpath="{.spec.clusterIP}")
                    curl -sf http://$BACKEND_IP:3000/health && echo "✓ /health OK"
                    curl -sf http://$BACKEND_IP:3000/version && echo "✓ /version OK"
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline completado exitosamente."
            echo "Backend: $BACKEND_IMAGE:$IMAGE_TAG"
            echo "Frontend: $FRONTEND_IMAGE:$IMAGE_TAG"
        }
        failure {
            echo 'Pipeline fallido. Revisar logs.'
        }
    }
}
