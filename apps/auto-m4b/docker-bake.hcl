target "docker-metadata-action" {}

variable "APP" {
  default = "auto-m4b"
}

variable "VERSION" {
  // renovate: datasource=docker depName=docker.io/sandreas/m4b-tool
  default = "0.5.2"
}

variable "SOURCE" {
  default = "https://github.com/seanap/auto-m4b"
}

group "default" {
  targets = ["image-local"]
}

target "image" {
  inherits = ["docker-metadata-action"]
  args = {
    VERSION = "${VERSION}"
  }
  labels = {
    "org.opencontainers.image.source" = "${SOURCE}"
  }
}

target "image-local" {
  inherits = ["image"]
  output = ["type=docker"]
  tags = ["${APP}:${VERSION}"]
}

target "image-all" {
  inherits = ["image"]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
