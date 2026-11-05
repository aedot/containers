target "docker-metadata-action" {}

variable "APP" {
  default = "beets-audible"
}

variable "VERSION" {
  // renovate: datasource=pypi depName=beets-audible versioning=pep440
  default = "1.7.1"
}

variable "SOURCE" {
  default = "https://github.com/Neurrone/beets-audible"
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
