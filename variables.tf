variable "gcp_project_id" {
  description = "The project to deploy the cluster in"
  type        = string
  default     = "sandbox-457518"
}


variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "gcp_zone" {
  description = "All GCP resources will be launched in this Zone."
  type        = string
  default     = "us-central1-a"
}

variable "server_cluster_size" {
  type    = number
  default = 1
}

variable "server_machine_type" {
  type    = string
  default = "n1-standard-2"
}

variable "client_cluster_size" {
  type    = number
  default = 1
}

variable "client_cluster_auto_scaling_max" {
  type    = number
  default = 2
}

variable "client_machine_type" {
  type    = string
  default = "n1-standard-2"
}

variable "api_cluster_size" {
  type    = number
  default = 1
}

variable "api_machine_type" {
  type    = string
  default = "n1-standard-2"
}

variable "build_cluster_size" {
  type    = number
  default = 1
}

variable "build_machine_type" {
  type    = string
  default = "n1-standard-2"
}

variable "client_proxy_health_port" {
  type = object({
    name = string
    port = number
    path = string
  })
  default = {
    name = "health"
    port = 3001
    path = "/health"
  }
}

variable "client_proxy_port" {
  type = object({
    name = string
    port = number
  })
  default = {
    name = "session"
    port = 3002
  }
}

variable "logs_proxy_port" {
  type = object({
    name = string
    port = number
  })
  default = {
    name = "logs"
    port = 30006
  }
}

variable "logs_health_proxy_port" {
  type = object({
    name        = string
    port        = number
    health_path = string
  })
  default = {
    name        = "logs-health"
    port        = 44313
    health_path = "/health"
  }
}

variable "api_port" {
  type = object({
    name        = string
    port        = number
    health_path = string
  })
  default = {
    name        = "api"
    port        = 50001
    health_path = "/health"
  }
}

variable "redis_port" {
  type = object({
    name = string
    port = number
  })
  default = {
    name = "redis"
    port = 6379
  }
}

variable "nomad_port" {
  type    = number
  default = 4646
}

variable "orchestrator_port" {
  type    = number
  default = 5008
}

variable "orchestrator_proxy_port" {
  type    = number
  default = 5007
}

variable "template_manager_port" {
  type    = number
  default = 5009
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "otel_tracing_print" {
  description = "Whether to print OTEL traces to stdout"
  type        = bool
  default     = false
}

variable "domain_name" {
  type        = string
  description = "The domain name where e2b will run"
}

variable "additional_domains" {
  type        = string
  description = "Additional domains which can be used to access the e2b cluster, separated by commas"
  default     = ""
}

variable "prefix" {
  type        = string
  description = "The prefix to use for all resources in this module"
  default     = "e2b-"
}

variable "labels" {
  description = "The labels to attach to resources created by this module"
  type        = map(string)
  default = {
    "app"       = "e2b"
    "terraform" = "true"
  }
}

variable "terraform_state_bucket" {
  description = "The name of the bucket to store terraform state in"
  type        = string
  default     = " e2b-terraform-state-sandbox-457518"
}

variable "loki_service_port" {
  type = object({
    name = string
    port = number
  })
  default = {
    name = "loki"
    port = 3100
  }
}

variable "template_bucket_location" {
  type        = string
  description = "The location of the FC template bucket"
  default     = "US"
}

variable "template_bucket_name" {
  type        = string
  description = "The name of the FC template bucket"
  default     = "e2b-fc-templates-sandbox-457518"
}

variable "redis_managed" {
  default = false
  type    = bool
}

variable "posthog_api_key_secret_name" {
  type = string
  default = "posthog-api-key"

}

variable "supabase_jwt_secrets_secret_name" {
  type = string
  default = "supabase-jwt-secrets"
}
