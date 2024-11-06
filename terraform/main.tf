terraform {
  backend "azurerm" {}  # Los valores se pasan durante terraform init
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  skip_provider_registration = true
}

# Variables configurables
variable "resource_group_name" {
  default = "new-resource-group-java-app"
}

variable "location" {
  default = "westus2"
}

variable "app_service_name" {
  default = "java-api-demo-app"
}

variable "app_service_plan_name" {
  default = "java-app-service-plan"
}

variable "api_url" {
  default = "https://apim-devops-ta.azure-api.net/api/DevOps"
}

variable "api_key" {
  default = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
}

variable "jwt_secret" {
  default = "devops-ta-jwt"
}

variable "storage_account_name" {
  description = "Azure Storage Account Name for Terraform Backend"
}

variable "container_name" {
  description = "Azure Storage Container Name for Terraform Backend"
}

variable "key" {
  description = "Terraform State File Key"
}

variable "access_key" {
  description = "Azure Storage Account Access Key"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  description = "Azure Tenant ID"
}

variable "client_id" {
  description = "Azure Client ID"
}

variable "client_secret" {
  description = "Azure Client Secret"
}

# Creación de un nuevo grupo de recursos
resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

# Creación de un App Service Plan
resource "azurerm_service_plan" "app_service_plan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  os_type             = "Linux"
  sku_name            = "F1"
}

# Creación de un Linux Web App para la aplicación Java
resource "azurerm_linux_web_app" "app_service" {
  name                = var.app_service_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  service_plan_id     = azurerm_service_plan.app_service_plan.id

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
    "WEBSITE_RUN_FROM_PACKAGE"           = "1"
    "API_URL"                            = var.api_url
    "API_KEY"                            = var.api_key
    "JWT_SECRET"                         = var.jwt_secret
    "WEBSITES_PORT"                      = "8080"
    # Optimized Java settings for F1 tier
    "JAVA_OPTS"                          = "-Xms256m -Xmx512m -XX:+UseSerialGC -Djava.security.egd=file:/dev/./urandom"
    "SPRING_PROFILES_ACTIVE"             = "prod"
    # Disable server startup check
    "WEBSITE_SKIP_CONTENTSHARE_VALIDATION" = "1"
    "WEBSITE_ADD_SITENAME_BINDINGS_IN_APPHOST_CONFIG" = "1"
  }

  site_config {
    always_on = false
    application_stack {
      java_version = "17"
      java_server = "JAVA"
      java_server_version = "17"
    }

    # Simplified startup command
    app_command_line = "JAVA_HOME=/opt/java/openjdk java $JAVA_OPTS -jar /home/site/wwwroot/demo-0.0.1-SNAPSHOT.jar --server.port=8080"
    
    cors {
      allowed_origins = ["*"]
    }

    # Reduced health check interval
    health_check_path = "/actuator/health"
    health_check_eviction_time_in_min = 2

    # Additional performance configurations
    ftps_state = "Disabled"
    minimum_tls_version = "1.2"
    use_32_bit_worker = true
  }

  logs {
    application_logs {
      file_system_level = "Error"  # Reduced logging
    }
    
    http_logs {
      file_system {
        retention_in_days = 1
        retention_in_mb   = 25
      }
    }
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

# Exportación de las salidas principales
output "resource_group_name" {
  value = azurerm_resource_group.example.name
}

output "app_service_name" {
  value = azurerm_linux_web_app.app_service.name
}