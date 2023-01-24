# Mapping of input variables to local variables
locals {
  mime_types    = jsondecode(file("${path.module}/misc/mime.json"))
  resource_name = "${var.resources_base_name}-${random_string.rnd.result}"
  web_folder    = var.web_folder
  index_file    = var.index_file
  error_file    = var.error_file

  resource_group_name                 = "${var.resource_group_name}-rg"
  storage_account_name                = "${substr(replace(var.resources_base_name, "-", ""), 0, 14)}${random_string.rnd.result}sa"
  cdn_profile_name                    = "${var.resources_base_name}${random_string.rnd.result}-cdnprofile"
  cdn_endpoint_name                   = "${var.resources_base_name}${random_string.rnd.result}-endpoint"
  cdn_endpoint_origin_name            = "${var.resources_base_name}${random_string.rnd.result}-origin"
  cdn_endpoint_custom_domain_name     = "${var.resources_base_name}-domain"
  cdn_endpoint_custom_sub_domain_name = "${var.resources_base_name}-sub-domain"

  dns_resource_group_name = var.sub_domain_dns.resource_group_name
  dns_zone_name           = var.sub_domain_dns.zone_name
  dns_root_domain         = var.sub_domain_dns.root_domain
  dns_sub_domain_name     = var.sub_domain_dns.sub_domain_name

  url       = "${var.sub_domain_dns.sub_domain_name}.${var.sub_domain_dns.root_domain}"
  https_url = "https://${var.sub_domain_dns.sub_domain_name}.${var.sub_domain_dns.root_domain}"
}

# Generates a random string for unique resource names
resource "random_string" "rnd" {
  length  = 8
  special = false
  upper   = false
}

# Creates the resource group
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
}

# Creates storage account for static website
resource "azurerm_storage_account" "sa" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"

  static_website {
    index_document     = local.index_file
    error_404_document = local.error_file
  }

  identity {
    type = "SystemAssigned"
  }
}

# Adds website files to the storage account
resource "azurerm_storage_blob" "static-web-demo-storage-blob" {
  for_each = fileset("", "${local.web_folder}/**")

  name                   = trimprefix(each.key, "${local.web_folder}/")
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = "$web"
  type                   = "Block"
  content_md5            = filemd5(each.key)
  source                 = each.value
  content_type           = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
}

# Creates CDN profile
resource "azurerm_cdn_profile" "website-cdnprofile" {
  name                = local.cdn_profile_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_Microsoft"
}

# Creates the CDN endpoint
resource "azurerm_cdn_endpoint" "website-endpoint" {
  name                = local.cdn_endpoint_name
  profile_name        = azurerm_cdn_profile.website-cdnprofile.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  origin_host_header  = azurerm_storage_account.sa.primary_web_host

  origin {
    name      = local.cdn_endpoint_origin_name
    host_name = azurerm_storage_account.sa.primary_web_host
  }

  // Globally add security headers to all outgoing responses
  global_delivery_rule {
    modify_response_header_action {
      action = "Append"
      name   = "Strict-Transport-Security"
      value  = "max-age=31536000; includeSubDomains"
    }
  }

  # Check for https and redirect to https if not present
  delivery_rule {
    name  = "EnforceCustomDomainRedirect"
    order = "1"

    request_uri_condition {
      operator         = "BeginsWith"
      negate_condition = true
      match_values     = [local.https_url]
    }

    url_redirect_action {
      redirect_type = "PermanentRedirect"
      protocol      = "Https"
      hostname      = local.url
    }
  }

  # Check for referer header and redirect to root domain if not present
  delivery_rule {
    name  = "MissingRefererHeader"
    order = "2"

    request_header_condition {
      selector         = "Referer"
      operator         = "BeginsWith"
      negate_condition = true
      match_values     = [local.https_url]
      transforms       = ["Lowercase"]
    }

    url_file_extension_condition {
      match_values = var.referer_check_file_extensions
      operator     = "Equal"
      transforms   = ["Lowercase"]
    }

    url_redirect_action {
      redirect_type = "PermanentRedirect"
      protocol      = "Https"
      hostname      = local.url
      path          = "/"
    }
  }
}

# Create CNAME record (sub-domain) for CDN endpoint
resource "azurerm_dns_cname_record" "cname_record" {
  name                = local.dns_sub_domain_name
  zone_name           = local.dns_zone_name
  resource_group_name = local.dns_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_cdn_endpoint.website-endpoint.id
}

# Connects the CDN endpoint to the CNAME record
resource "azurerm_cdn_endpoint_custom_domain" "cdn_custom_domain" {
  name            = local.cdn_endpoint_custom_domain_name
  cdn_endpoint_id = azurerm_cdn_endpoint.website-endpoint.id
  host_name       = local.url

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }

  depends_on = [
    azurerm_dns_cname_record.cname_record
  ]
}

# Removes the CNAME record when the CDN endpoint is destroyed
resource "null_resource" "destroy_cname_record" {
  triggers = {
    uuid                = azurerm_cdn_endpoint_custom_domain.cdn_custom_domain.id
    resource_group_name = local.dns_resource_group_name
    zone_name           = local.dns_zone_name
    sub_domain_name     = local.dns_sub_domain_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "az network dns record-set cname delete -g ${self.triggers.resource_group_name} -z ${self.triggers.zone_name} -n ${self.triggers.sub_domain_name} -y"
  }
}
