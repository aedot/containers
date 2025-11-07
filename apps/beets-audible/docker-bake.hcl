target "docker-metadata-action" {}

variable "APP" {
  default = "beets"
}

variable "VERSION" {
  // renovate: datasource=github-releases depName=beetbox/beets versioning=loose
  default = "v2.5.1"
}

group "default" {
  targets = ["image-local"]
}

variable "SOURCE" {
  default = "https://github.com//beetbox/beets"
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
