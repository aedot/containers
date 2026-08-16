target "docker-metadata-action" {}

variable "APP" {
  default = "baby-tracker"
}

// Source is vendored under apps/baby-tracker/, so this is our own image version
// (bump on each vendored change). Base image + pip deps are tracked by renovate's
// native Dockerfile/pip managers, not by this variable.
variable "VERSION" {
  // renovate: datasource=github-releases depName=hms-homelab/hms-baby-tracker
  default = "2026.4.15"
}

variable "SOURCE" {
  default = "https://github.com/hms-homelab/hms-baby-tracker"
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
