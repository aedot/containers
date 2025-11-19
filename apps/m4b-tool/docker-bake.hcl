target "docker-metadata-action" {}

variable "APP" {
  default = "m4b-tool"
}

variable "VERSION" {
  default = "v0.5.2"
}

variable "SOURCE" {
  default = "https://github.com/sandreas/m4b-tool"
}

group "default" {
  targets = ["image-local"]
}

target "image" {
  inherits = ["docker-metadata-action"]

  # MOST IMPORTANT FIX
  context = "./apps/m4b-tool"
  dockerfile = "./apps/m4b-tool/Dockerfile"

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
