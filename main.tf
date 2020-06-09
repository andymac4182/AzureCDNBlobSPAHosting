locals {
    azure_rg_name = "AzureCDNBlobSPAHosting"
    location = "West US"
    subscription_id = "5cc5a279-6cab-4d78-a2cb-827f74b0c6ea"

    storage_cdn_name = lower(random_string.storage_account_name.result)
    service_tags = {
        managed_by  = "Terraform"
        Environment = "Development"
        Owner       = "Me"
        Team        = "Developers"
        Application = "AzureCDNBlobSPAHosting"
    }
}

provider "azurerm" {
  subscription_id = local.subscription_id
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = local.azure_rg_name
  location = local.location
}

resource "random_string" "storage_account_name" {
  length = 16
  special = false
}

resource "azurerm_storage_account" "example" {
  name                     = local.storage_cdn_name
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  static_website {
      index_document = "index.html"
      error_404_document = "error.html"
  }

  tags = local.service_tags
}

resource "azurerm_cdn_profile" "example" {
  name                = local.storage_cdn_name
  location            = local.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "Standard_Microsoft"

  tags = local.service_tags
}

resource "azurerm_cdn_endpoint" "example" {
  name                = local.storage_cdn_name
  profile_name        = azurerm_cdn_profile.example.name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  origin_host_header =   azurerm_storage_account.example.primary_web_host
  is_compression_enabled = true

  origin {
    name      = local.storage_cdn_name
    host_name = azurerm_storage_account.example.primary_web_host
  }

  delivery_rule {
      name = "Http2Https"
      order = 1
      request_scheme_condition {
          operator = "Equal"
          match_values = ["HTTP"]
      }
      url_redirect_action {
          redirect_type = "Moved"
          protocol = "Https"
      }
  }

  delivery_rule {
      name = "RewriteToIndex"
      order = 2
      url_file_extension_condition {
          operator = "LessThan"
          match_values = ["1"]
      }

      url_rewrite_action {
          source_pattern = "/"
          destination = "/index.html"
          preserve_unmatched_path = false
      }
  }
}