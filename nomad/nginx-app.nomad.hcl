variable "image_tag" {
  type        = string
  description = "The Docker image tag to deploy from GHCR"
  default     = "1.0.0"
}

variable "ghcr_owner" {
  type        = string
  description = "GitHub username or organisation in lowercase"
  default     = "dungtony9"
}

job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "2m"
      auto_revert      = true
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    service {
      name     = "nginx-web-app"
      port     = "http"
      provider = "consul"

      check {
        name     = "nginx-http-healthz"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "ghcr.io/${var.ghcr_owner}/devops-intern-final/nginx-app:${var.image_tag}"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}