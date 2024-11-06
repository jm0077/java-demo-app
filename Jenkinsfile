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
							script: "terraform output -raw app_service_name",
							returnStdout: true
						).trim()
						
						withEnv(["APP_SERVICE_NAME=${appServiceName}"]) {
							sh """
								# Login to Azure
								az login --service-principal \
								-u \$AZURE_CREDS_CLIENT_ID \
								-p \$AZURE_CREDS_CLIENT_SECRET \
								--tenant \$AZURE_CREDS_TENANT_ID

								# Create deployment package
								cd ../target
								zip -j app.zip demo-0.0.1-SNAPSHOT.jar
								
								# Deploy using ZIP deployment with longer timeout
								az webapp deployment source config-zip \
								--resource-group new-resource-group-java-app \
								--name \$APP_SERVICE_NAME \
								--src app.zip \
								--timeout 1800

								echo "Waiting for deployment to complete..."
								sleep 30

								# Ensure the app is running and configured correctly
								az webapp config set \
								--resource-group new-resource-group-java-app \
								--name \$APP_SERVICE_NAME \
								--startup-file "java -jar /home/site/wwwroot/demo-0.0.1-SNAPSHOT.jar"

								echo "Starting web app..."
								az webapp start \
								--name \$APP_SERVICE_NAME \
								--resource-group new-resource-group-java-app

								# Check app status
								echo "Checking web app status..."
								for i in {1..12}; do
									STATUS=\$(az webapp show \
										--name \$APP_SERVICE_NAME \
										--resource-group new-resource-group-java-app \
										--query state -o tsv)
									
									if [ "\$STATUS" = "Running" ]; then
										echo "Web app is running!"
										break
									else
										echo "Web app status: \$STATUS. Waiting..."
										sleep 30
									fi
								done
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