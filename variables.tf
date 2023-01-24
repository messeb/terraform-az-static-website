variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "resources_base_name" {
  description = "Base name of the resources"
}

variable "location" {
  description = "Location of the resources"
}

variable "referer_check_file_extensions" {
  type        = list(string)
  default     = []
  description = "List of file extensions to check for referer"
}

variable "web_folder" {
  description = "Folder to upload to the storage account"
  default     = "public"
}

variable "sub_domain_dns" {
  type = object({
    resource_group_name = string
    zone_name           = string
    root_domain         = string
    sub_domain_name     = string
  })

  description = "Configuration for subdomain of the CDN endpoint"
}

variable "index_file" {
  description = "Index file to use for the static website"
  default     = "index.html"
}

variable "error_file" {
  description = "Error file to use for the static websitet"
  default     = "404.html"
}
