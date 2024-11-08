pipeline {
    agent any
    
    environment {
        AZURE_CREDS = credentials('AzureSPForDeployments')
        TERRAFORM_STORAGE_ACCOUNT = credentials('TERRAFORM_STORAGE_ACCOUNT')
        TERRAFORM_CONTAINER = credentials('TERRAFORM_CONTAINER')
        TERRAFORM_KEY = credentials('TERRAFORM_KEY')
        TERRAFORM_ACCESS_KEY = credentials('TERRAFORM_ACCESS_KEY')
    }
    
    tools {
        maven 'Maven'
        jdk 'JDK17'
        terraform 'Terraform'
    }
    
    stages {
        
        stage('Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/jm0077/java-demo-app.git'
            }
        }
        
        stage('Build Java Application') {
            steps {
                sh 'mvn clean package -DskipTests'
                archiveArtifacts artifacts: '**/target/*.jar', fingerprint: true
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Initialize Terraform') {
            steps {
                dir('terraform') {
                    sh '''
                        terraform init \
                        -backend-config="storage_account_name=${TERRAFORM_STORAGE_ACCOUNT}" \
                        -backend-config="container_name=${TERRAFORM_CONTAINER}" \
                        -backend-config="key=${TERRAFORM_KEY}" \
                        -backend-config="access_key=${TERRAFORM_ACCESS_KEY}" \
                        -backend-config="subscription_id=${AZURE_CREDS_SUBSCRIPTION_ID}" \
                        -backend-config="tenant_id=${AZURE_CREDS_TENANT_ID}" \
                        -backend-config="client_id=${AZURE_CREDS_CLIENT_ID}" \
                        -backend-config="client_secret=${AZURE_CREDS_CLIENT_SECRET}" \
                        -force-copy
                    '''
                }
            }
        }
        
        stage('Debug Terraform Config') {
            steps {
                dir('terraform') {
                    sh '''
                        echo "Terraform provider configuration:"
                        grep -A 10 "provider \\"azurerm\\"" *.tf || true
                        
                        echo "Terraform backend configuration:"
                        grep -A 10 "backend \\"azurerm\\"" *.tf || true
                    '''
                }
            }
        }
		
		stage('Azure Login') {
            steps {
                    sh '''
                        az login --service-principal \
                        -u $AZURE_CREDS_CLIENT_ID \
                        -p $AZURE_CREDS_CLIENT_SECRET \
                        --tenant $AZURE_CREDS_TENANT_ID
                        az account set --subscription $AZURE_CREDS_SUBSCRIPTION_ID
                    '''
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh 'echo "Using Client ID: ${AZURE_CREDS_CLIENT_ID}"'
                    sh '''
                        terraform plan \
                        -var="subscription_id=${AZURE_CREDS_SUBSCRIPTION_ID}" \
                        -var="tenant_id=${AZURE_CREDS_TENANT_ID}" \
                        -var="client_id=${AZURE_CREDS_CLIENT_ID}" \
                        -var="client_secret=${AZURE_CREDS_CLIENT_SECRET}" \
                        -var="storage_account_name=${TERRAFORM_STORAGE_ACCOUNT}" \
                        -var="container_name=${TERRAFORM_CONTAINER}" \
                        -var="key=${TERRAFORM_KEY}" \
                        -var="access_key=${TERRAFORM_ACCESS_KEY}" \
                        -out=tfplan
                    '''
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

		stage('Deploy to Azure') {
			steps {
				script {
					dir('terraform') {
						def appServiceName = sh(
							script: "terraform output -raw app_service_url | cut -d'.' -f1",
							returnStdout: true
						).trim()
						
						withEnv(["APP_SERVICE_NAME=${appServiceName}"]) {
							sh """
								# Login to Azure
								az login --service-principal \
								-u \$AZURE_CREDS_CLIENT_ID \
								-p \$AZURE_CREDS_CLIENT_SECRET \
								--tenant \$AZURE_CREDS_TENANT_ID

								# Preparar el deployment
								echo "Preparando deployment..."
								cd ../target
								zip -j app.zip demo-0.0.1-SNAPSHOT.jar
								
								# Deploy usando el nombre correcto del App Service
								echo "Iniciando deployment..."
								az webapp deployment source config-zip \
								--resource-group new-resource-group-java-app \
								--name \$APP_SERVICE_NAME \
								--src app.zip \
								--timeout 3600

								# Verificar el estado del deployment
								echo "Verificando estado del deployment..."
								DEPLOYMENT_STATUS=\$(az webapp show \
									--name \$APP_SERVICE_NAME \
									--resource-group new-resource-group-java-app \
									--query state -o tsv)

								if [ "\$DEPLOYMENT_STATUS" = "Running" ]; then
									echo "Aplicación desplegada exitosamente!"
									exit 0
								else
									echo "Error: La aplicación no está en estado Running. Estado actual: \$DEPLOYMENT_STATUS"
									exit 1
								fi
							"""
						}
					}
				}
			}
		}
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline executed successfully!'
        }
        failure {
            echo 'Pipeline execution failed!'
        }
    }
}