resource "azurerm_log_analytics_workspace" "gbfs-law" {
  name                = "${var.FeedName}-law"
  location            = azurerm_resource_group.umobrg.location
  resource_group_name = azurerm_resource_group.umobrg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "gbfsFunction-insights" {
  name                = "${var.FeedName}-ai"
  location            = azurerm_resource_group.umobrg.location
  resource_group_name = azurerm_resource_group.umobrg.name
  workspace_id        = azurerm_log_analytics_workspace.gbfs-law.id
  application_type    = "web"
}


resource "azurerm_application_insights" "gbfsui-insights" {
  name                = "${var.FeedName}-ui-ai"
  location            = azurerm_resource_group.umobrg.location
  resource_group_name = azurerm_resource_group.umobrg.name
  workspace_id        = azurerm_log_analytics_workspace.gbfs-law.id
  application_type    = "web"
}

resource "azurerm_monitor_action_group" "email_action_group" {
  name                = "email-action-group"
  resource_group_name = azurerm_resource_group.umobrg.name
  short_name          = "emailAlerts"

  email_receiver {
    name          = "email_receiver"
    email_address = "youremail@example.com"  # Replace with your email address
  }
}


resource "azurerm_monitor_metric_alert" "application_alert" {
  for_each = tomap({
    webapp-metric-alert       = "${azurerm_windows_web_app.gbfsWebApp.id}"
    function-metric-alert     = "${azurerm_windows_function_app.gbfsFunction.id}"
  })
  name                = each.key
  resource_group_name = azurerm_resource_group.umobrg.name
  scopes              = [each.value]
  description         = "Triggered when the HTTP 5xx errors exceed 10."

  enabled             = true
  auto_mitigate       = true
  frequency           = "PT5M"             # Evaluation frequency (5 minutes)
  severity            = 3                   # Severity level (0-4)
  window_size         = "PT15M"            # Monitoring period (15 minutes)

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.email_action_group.id
  }
}

