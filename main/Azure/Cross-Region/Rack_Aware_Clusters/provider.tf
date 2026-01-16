# Azure Provider Configuration for Cross-Region deployment
# Supports two authentication methods:
# 1. Service Principal (client_id + client_secret) - for CI/CD automation
# 2. Azure CLI (use_cli_auth = true) - for local development with `az login`

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

# Provider for Region 1
provider "azurerm" {
  alias = "provider1"
  features {}

  subscription_id = var.azure_subscription_id

  # Use CLI auth if use_cli_auth is true OR if client_id/client_secret are empty
  use_cli = var.use_cli_auth || var.azure_access_key_id == "" || var.azure_secret_key == ""

  # Only set these if using Service Principal authentication
  client_id     = var.azure_access_key_id != "" ? var.azure_access_key_id : null
  tenant_id     = var.azure_tenant_id != "" ? var.azure_tenant_id : null
  client_secret = var.azure_secret_key != "" ? var.azure_secret_key : null
}

# Provider for Region 2 (same credentials, different region configured in modules)
provider "azurerm" {
  alias = "provider2"
  features {}

  subscription_id = var.azure_subscription_id

  # Use CLI auth if use_cli_auth is true OR if client_id/client_secret are empty
  use_cli = var.use_cli_auth || var.azure_access_key_id == "" || var.azure_secret_key == ""

  # Only set these if using Service Principal authentication
  client_id     = var.azure_access_key_id != "" ? var.azure_access_key_id : null
  tenant_id     = var.azure_tenant_id != "" ? var.azure_tenant_id : null
  client_secret = var.azure_secret_key != "" ? var.azure_secret_key : null
}

