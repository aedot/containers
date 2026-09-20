target "docker-metadata-action" {}

variable "APP" {
  default = "audiobookbay-automated"
}

// Source is vendored under apps/audiobookbay-automated/, so this is our own
// image version (bump on each vendored change). Upstream has no releases, so
// there is no semver datasource to track; the base image + pip deps are tracked
// by renovate's native Dockerfile/pip managers.
variable "VERSION" {
  default = "0.1.1"
}

variable "SOURCE" {
  default = "https://github.com/aedot/containers"
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
