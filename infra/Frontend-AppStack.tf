resource "azurerm_windows_web_app" "gbfsWebApp" {
  name                = "umob-${var.FeedName}-dev"
  resource_group_name = azurerm_resource_group.umobrg.name
  location            = azurerm_resource_group.umobrg.location
  service_plan_id     = azurerm_app_service_plan.gbfsFunctionASP.id

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION"               = "14"
    "APPINSIGHTS_INSTRUMENTATIONKEY"             = "${azurerm_application_insights.gbfsui-insights.instrumentation_key}"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = "${azurerm_application_insights.gbfsui-insights.connection_string}"
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~2"
    "Storage_SAS"                                = data.azurerm_storage_account_sas.umob_sas.sas
    "XDT_MicrosoftApplicationInsights_NodeJS"    = "1"

  }
  site_config {}
}

data "azurerm_storage_account_sas" "umob_sas" {
  connection_string = azurerm_storage_account.umobsa.primary_connection_string
  https_only        = true
  signed_version    = "2017-07-29"

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = "2024-10-01T00:00:00Z"
  expiry = "2025-10-01T00:00:00Z"

  permissions {
    read    = true
    write   = true
    delete  = false
    list    = true
    add     = true
    create  = false
    update  = false
    process = true
    tag     = true
    filter  = true
  }
}