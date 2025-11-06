target "docker-metadata-action" {}

variable "APP" {
  default = "auto-m4b"
}

variable "VERSION" {
  // renovate: datasource=github-releases depName=seanap/auto-m4b
  default = "v1.5.3"
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
  context = "."
  dockerfile = "Dockerfile"
  output = ["type=docker"]
  tags = ["${APP}:${VERSION}"]
}

target "image-all" {
  inherits = ["image"]
  context = "."
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
