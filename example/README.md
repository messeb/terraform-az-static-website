# Example

## Usage

```hcl
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
```

## Outputs

website_url: [https://az-static-website.messeb.net](https://az-static-website.messeb.net)

