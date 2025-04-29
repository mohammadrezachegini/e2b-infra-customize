locals {
  domain_map = { for d in var.additional_domains : replace(d, ".", "-") => d }

  backends = {
    session = {
      protocol                        = "HTTP"
      port                            = var.client_proxy_port.port
      port_name                       = var.client_proxy_port.name
      timeout_sec                     = 86400
      connection_draining_timeout_sec = 1
      http_health_check = {
        request_path       = var.client_proxy_health_port.path
        port               = var.client_proxy_health_port.port
        timeout_sec        = 3
        check_interval_sec = 3
      }
      groups = [{ group = var.client_instance_group }]
    }
    api = {
      protocol                        = "HTTP"
      port                            = var.api_port.port
      port_name                       = var.api_port.name
      timeout_sec                     = 65
      connection_draining_timeout_sec = 1
      http_health_check = {
        request_path       = var.api_port.health_path
        port               = var.api_port.port
        timeout_sec        = 3
        check_interval_sec = 3
      }
      groups = [{ group = var.api_instance_group }]
    }
    nomad = {
      protocol                        = "HTTP"
      port                            = 80
      port_name                       = "nomad"
      timeout_sec                     = 10
      connection_draining_timeout_sec = 1
      http_health_check = {
        request_path = "/v1/status/peers"
        port         = var.nomad_port
      }
      groups = [{ group = var.server_instance_group }]
    }
    consul = {
      protocol                        = "HTTP"
      port                            = 80
      port_name                       = "consul"
      timeout_sec                     = 10
      connection_draining_timeout_sec = 1
      http_health_check = {
        request_path = "/v1/status/peers"
        port         = 8500
      }
      groups = [{ group = var.server_instance_group }]
    }
  }

  health_checked_backends = { for backend_index, backend_value in local.backends : backend_index => backend_value }
}

# ========== Global IP Address ===========
resource "google_compute_global_address" "orch_logs_ip" {
  name = "${var.prefix}logs-ip"
}

# ========== Certificate Manager ==========

resource "google_certificate_manager_dns_authorization" "dns_auth" {
  name        = "${var.prefix}dns-auth"
  description = "The default dns auth"
  domain      = var.domain_name
  labels      = var.labels
}

resource "google_certificate_manager_certificate" "root_cert" {
  name        = "${var.prefix}root-cert"
  description = "The wildcard cert"
  managed {
    domains = [var.domain_name, "*.${var.domain_name}"]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.dns_auth.id
    ]
  }
  labels = var.labels
}

resource "google_certificate_manager_certificate_map" "certificate_map" {
  name        = "${var.prefix}cert-map"
  description = "${var.domain_name} certificate map"
  labels      = var.labels
}

resource "google_certificate_manager_certificate_map_entry" "top_level_map_entry" {
  name        = "${var.prefix}top-level"
  description = "Top level map entry"
  map         = google_certificate_manager_certificate_map.certificate_map.name
  labels      = var.labels
  certificates = [google_certificate_manager_certificate.root_cert.id]
  hostname     = var.domain_name
}

resource "google_certificate_manager_certificate_map_entry" "subdomains_map_entry" {
  name        = "${var.prefix}subdomains"
  description = "Subdomains map entry"
  map         = google_certificate_manager_certificate_map.certificate_map.name
  labels      = var.labels
  certificates = [google_certificate_manager_certificate.root_cert.id]
  hostname     = "*.${var.domain_name}"
}

# ========== URL Maps and Load Balancers ==========

resource "google_compute_url_map" "orch_map" {
  name            = "${var.prefix}orch-map"
  default_service = google_compute_backend_service.default["nomad"].self_link

  host_rule {
    hosts        = concat(["api.${var.domain_name}"], [for d in var.additional_domains : "api.${d}"])
    path_matcher = "api-paths"
  }

  host_rule {
    hosts        = concat(["nomad.${var.domain_name}"], [for d in var.additional_domains : "nomad.${d}"])
    path_matcher = "nomad-paths"
  }

  host_rule {
    hosts        = concat(["consul.${var.domain_name}"], [for d in var.additional_domains : "consul.${d}"])
    path_matcher = "consul-paths"
  }

  host_rule {
    hosts        = concat(["*.${var.domain_name}"], [for d in var.additional_domains : "*.${d}"])
    path_matcher = "session-paths"
  }

  path_matcher {
    name            = "api-paths"
    default_service = google_compute_backend_service.default["api"].self_link
  }

  path_matcher {
    name            = "session-paths"
    default_service = google_compute_backend_service.default["session"].self_link
  }

  path_matcher {
    name            = "nomad-paths"
    default_service = google_compute_backend_service.default["nomad"].self_link
  }

  path_matcher {
    name            = "consul-paths"
    default_service = google_compute_backend_service.default["consul"].self_link
  }
}

resource "google_compute_target_https_proxy" "default" {
  name    = "${var.prefix}https-proxy"
  url_map = google_compute_url_map.orch_map.self_link
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.certificate_map.id}"
}

resource "google_compute_global_forwarding_rule" "https" {
  provider              = google-beta
  name                  = "${var.prefix}forwarding-rule-https"
  target                = google_compute_target_https_proxy.default.self_link
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  labels                = var.labels
}

# ========== Backend Services ==========

resource "google_compute_backend_service" "default" {
  provider = google-beta
  for_each = local.backends

  name = "${var.prefix}backend-${each.key}"

  port_name = lookup(each.value, "port_name", "http")
  protocol  = lookup(each.value, "protocol", "HTTP")
  timeout_sec                     = lookup(each.value, "timeout_sec")
  connection_draining_timeout_sec = 1
  compression_mode                = "DISABLED"
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  health_checks                   = [google_compute_health_check.default[each.key].self_link]
  security_policy                 = google_compute_security_policy.default[each.key].self_link

  log_config {
    enable = var.environment != "dev"
  }

  dynamic "backend" {
    for_each = toset(each.value["groups"])
    content {
      group = lookup(backend.value, "group")
    }
  }

  depends_on = [google_compute_health_check.default]
}

# ========== Health Checks ==========

resource "google_compute_health_check" "default" {
  provider = google-beta
  for_each = local.health_checked_backends
  name     = "${var.prefix}hc-${each.key}"

  check_interval_sec  = lookup(each.value["http_health_check"], "check_interval_sec", 5)
  timeout_sec         = lookup(each.value["http_health_check"], "timeout_sec", 5)
  healthy_threshold   = lookup(each.value["http_health_check"], "healthy_threshold", 2)
  unhealthy_threshold = lookup(each.value["http_health_check"], "unhealthy_threshold", 2)

  log_config {
    enable = false
  }

  dynamic "http_health_check" {
    for_each = [1]
    content {
      request_path = lookup(each.value["http_health_check"], "request_path")
      port         = lookup(each.value["http_health_check"], "port")
    }
  }
}

# ========== Firewall Rules ==========

resource "google_compute_firewall" "default-hc" {
  name    = "${var.prefix}load-balancer-hc"
  network = var.network_name
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  target_tags = [var.cluster_tag_name]
  priority    = 999

  dynamic "allow" {
    for_each = local.health_checked_backends
    content {
      protocol = "tcp"
      ports    = [allow.value["http_health_check"].port]
    }
  }
}

resource "google_compute_firewall" "client_proxy_firewall_ingress" {
  name    = "${var.prefix}${var.cluster_tag_name}-client-proxy-firewall-ingress"
  network = var.network_name
  allow {
    protocol = "tcp"
    ports    = ["3002"]
  }
  priority = 999
  direction = "INGRESS"
  target_tags = [var.cluster_tag_name]
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

resource "google_compute_firewall" "orch_firewall_egress" {
  name    = "${var.prefix}${var.cluster_tag_name}-firewall-egress"
  network = var.network_name
  allow {
    protocol = "all"
  }
  direction   = "EGRESS"
  target_tags = [var.cluster_tag_name]
}
