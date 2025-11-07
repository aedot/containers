# docker-bake.hcl - no caching, GitHub Actions compatible

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

variable "REGISTRY" {
  default = "ghcr.io/${GITHUB_REPOSITORY_OWNER}"
}

group "default" {
  targets = ["image-ghcr"]
}

# Base image target with labels and build args
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

# Local image target for testing (optional)
target "image-local" {
  inherits = ["image"]
  output = ["type=docker"]
  tags = ["${APP}:${VERSION}"]
}

# GHCR target for GitHub Actions - no cache
target "image-ghcr" {
  inherits = ["image"]
  output = ["type=registry"]  # push to GHCR
  tags = [
    "${REGISTRY}/${APP}:${VERSION}",
    "${REGISTRY}/${APP}:latest"
  ]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}
