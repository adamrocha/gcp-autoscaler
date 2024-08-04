terraform {
  required_version = "> 1.5"

  required_providers {
    google = {
      version = "~> 5.0.0"
    }
  }
}

provider "google" {
  project = "autoscaler-431401"
  region  = "us-central1"
  zone    = "us-central1-c"
}

provider "google-beta" {
  project = "autoscaler-431401"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_compute_network" "vpc-network" {
  name                    = "vpc-network"
  auto_create_subnetworks = "true"
}

module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  project_id   = "autoscaler-431401"
  network_name = google_compute_network.vpc-network.name

  ingress_rules = [{
    name                    = "ingress-ports"
    description             = null
    priority                = null
    destination_ranges      = ["10.0.0.0/8"]
    source_ranges           = ["0.0.0.0/0"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = ["22", "80", "443"]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]

  egress_rules = [{
    name                    = "egress-internet"
    description             = null
    priority                = null
    destination_ranges      = ["10.0.0.0/8"]
    source_ranges           = ["0.0.0.0/0"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = ["22", "80", "443"]
    }]
    allow = [{
      protocol = "all"
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

resource "google_compute_autoscaler" "autoscaler" {
  name   = "autoscaler"
  target = google_compute_instance_group_manager.group-manager.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 60
  }
}

resource "google_compute_instance_template" "autoscale-template" {
  provider       = google-beta
  name           = "autoscale-template"
  machine_type   = "e2-micro"
  can_ip_forward = false

  tags = ["foo", "bar"]

  disk {
    source_image = data.google_compute_image.debian_9.id
  }

  network_interface {
    network = google_compute_network.vpc-network.name
  }

  metadata = {
    foo = "bar"
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}

resource "google_compute_target_pool" "autoscaler-pool" {
  name = "target-pool"
}

resource "google_compute_instance_group_manager" "group-manager" {
  name = "group-manager"

  version {
    instance_template = google_compute_instance_template.autoscale-template.id
    name              = "primary"
  }

  target_pools       = [google_compute_target_pool.autoscaler-pool.id]
  base_instance_name = "autoscaler-pool"
}

data "google_compute_image" "debian_9" {
  family  = "debian-11"
  project = "debian-cloud"
}