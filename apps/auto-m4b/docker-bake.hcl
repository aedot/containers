target "docker-metadata-action" {}

variable "APP" {
  default = "auto-m4b"
}

variable "VERSION" {
  // renovate: datasource=github-releases depName=seanap/m4b-tool
  default = "v0.5.2"
}

variable "SOURCE" {
  default = "https://github.com/seanap/m4b-tool"
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
    "org.opencontainers.image.source"  = "${SOURCE}"
    "org.opencontainers.image.version" = "${VERSION}"
    "org.opencontainers.image.title"   = "${APP}"
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
