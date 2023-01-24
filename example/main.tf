terraform {
  cloud {
    organization = "messeb"

    workspaces {
      name = "terraform-az-static-website"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    # Deletes external resources if resource groups are deleted
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

module "test" {
  source = "github.com/messeb/terraform-az-static-website"

  resource_group_name           = "az-static-website"
  resources_base_name           = "az-static-website"
  location                      = "westeurope"
  referer_check_file_extensions = ["css", "jpeg", "jpg", "gif", "js", "png", "svg", "webp", "zip"]
  index_file                    = "index.html"
  error_file                    = "404.html"
  web_folder                    = "public"

  sub_domain_dns = {
    resource_group_name = "messeb"
    zone_name           = "messeb.net"
    root_domain         = "messeb.net"
    sub_domain_name     = "az-static-website"
  }
}
