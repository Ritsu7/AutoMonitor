resource "azurerm_resource_group" "umobrg" {
  name     = "${var.ClientPrefix}-rg"
  location = var.region
}

resource "azurerm_storage_account" "umobsa" {
  name                     = "${var.ClientPrefix}sagbfs" # Must be globally unique
  resource_group_name      = azurerm_resource_group.umobrg.name
  location                 = azurerm_resource_group.umobrg.location
  account_tier            = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "umobcontainer" {
  for_each = toset(["vehicle-data", "gbfs-data"])
  name                  = each.key
  storage_account_name  = azurerm_storage_account.umobsa.name
  container_access_type = "private"
}

resource "azurerm_windows_function_app" "gbfsFunction" {
  name                = "${var.FeedName}"
  resource_group_name = azurerm_resource_group.umobrg.name
  location            = azurerm_resource_group.umobrg.location

  storage_account_name       = azurerm_storage_account.umobsa.name
  storage_account_access_key = azurerm_storage_account.umobsa.primary_access_key
  service_plan_id            = azurerm_app_service_plan.gbfsFunctionASP.id

  site_config {
    application_stack {
      powershell_core_version = "7.4"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"            = "${azurerm_application_insights.gbfsFunction-insights.instrumentation_key}"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"     = "${azurerm_application_insights.gbfsFunction-insights.connection_string}"
    "AzureWebJobsStorage"                       = azurerm_storage_account.umobsa.primary_connection_string
    "AzureWebJobsDashboard"                     = azurerm_storage_account.umobsa.primary_connection_string
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING"  = azurerm_storage_account.umobsa.primary_connection_string
    "WEBSITE_CONTENTSHARE"                      = "${var.FeedName}-content"
    "Providers"                                 = "${var.Providers}"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"            = "true"

  }


}

resource "azurerm_app_service_plan" "gbfsFunctionASP" {
  name                = "gbfs-asp"
  location            = azurerm_resource_group.umobrg.location
  resource_group_name = azurerm_resource_group.umobrg.name
  sku {
    tier     = "Basic"
    size     = "B1"
  }
}