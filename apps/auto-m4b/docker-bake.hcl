# --------------------------
# Variables
# --------------------------
variable "APP" {
  default = "auto-m4b"
}

variable "VERSION" {
  default = "v0.5.2"
}

variable "SOURCE" {
  default = "https://github.com/sandreas/m4b-tool"
}

# --------------------------
# Default group
# --------------------------
group "default" {
  targets = ["image-local"]
}

# --------------------------
# Builder image stage
# --------------------------
target "builder" {
  context = "."
  dockerfile = "Dockerfile"
  target = "builder"        # this must match `FROM ubuntu:22.04 AS builder` stage in your Dockerfile
}

# --------------------------
# Final image
# --------------------------
target "image" {
  inherits = ["builder"]    # ensures the builder stage is built first
  context = "."
  dockerfile = "Dockerfile"
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
