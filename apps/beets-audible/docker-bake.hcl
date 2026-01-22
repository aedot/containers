target "docker-metadata-action" {}

variable "APP" {
  default = "beets-audible"
}

variable "VERSION" {
  // Base image version - tracks LinuxServer beets releases
  // renovate: datasource=github-releases depName=linuxserver/docker-beets versioning=loose
  default = "2.5.1-ls306"
}

variable "PLUGIN_VERSION" {
  // Beets-audible plugin version
  // renovate: datasource=pypi depName=beets-audible
  default = "1.2.1"
}

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "OWNER" {
  default = "aedot"
}

variable "SOURCE" {
  default = "https://github.com/aedot/containers"
}

group "default" {
  targets = ["image-local"]
}

target "image" {
  inherits = ["docker-metadata-action"]
  context = "."
  dockerfile = "Dockerfile"
  args = {
    BASE_VERSION = "${VERSION}"
    PLUGIN_VERSION = "${PLUGIN_VERSION}"
  }
  labels = {
    "org.opencontainers.image.source" = "${SOURCE}"
    "org.opencontainers.image.description" = "Beets with Audible plugin for audiobook management"
    "org.opencontainers.image.licenses" = "MIT"
    "org.opencontainers.image.version" = "${VERSION}"
    "io.linuxserver.base_version" = "${VERSION}"
  }
}

target "image-local" {
  inherits = ["image"]
  output = ["type=docker"]
  tags = [
    "${APP}:${VERSION}"
  ]
}

target "image-all" {
  inherits = ["image"]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
  output = ["type=registry"]
  tags = [
    "${REGISTRY}/${OWNER}/${APP}:${VERSION}",
    "${REGISTRY}/${OWNER}/${APP}:latest"
  ]
}

target "image-test" {
  inherits = ["image"]
  output = ["type=docker"]
  tags = ["${APP}:test"]
  target = "test"
}

// Build and push to registry
target "image-push" {
  inherits = ["image-all"]
}
