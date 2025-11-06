# =====================================
# Variables
# =====================================
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

variable "M4B_TOOL_DOWNLOAD_LINK" {
  default = "https://github.com/sandreas/m4b-tool/releases/download/v0.5.2/m4b-tool.phar"
}

# Automatically set UID/GID to host values if available, fallback to 1000
variable "PUID" {
  default = "${env.HOST_UID}"
}

variable "PGID" {
  default = "${env.HOST_GID}"
}

variable "CPU_CORES" {
  default = "2"
}

variable "SLEEPTIME" {
  default = "5"
}

# =====================================
# Target Groups
# =====================================
group "default" {
  targets = ["image-local"]
}

# =====================================
# Targets
# =====================================
target "docker-metadata-action" {}

target "image" {
  inherits = ["docker-metadata-action"]
  args = {
    VERSION                 = "${VERSION}"
    M4B_TOOL_DOWNLOAD_LINK  = "${M4B_TOOL_DOWNLOAD_LINK}"
    PUID                    = "${PUID}"
    PGID                    = "${PGID}"
    CPU_CORES               = "${CPU_CORES}"
    SLEEPTIME               = "${SLEEPTIME}"
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
  tags = ["${APP}:${VERSION}"]
}
