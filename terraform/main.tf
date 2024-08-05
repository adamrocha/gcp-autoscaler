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

resource "google_compute_firewall" "egress" {
  name      = "egress-firewall"
  network   = google_compute_network.vpc-network.name
  direction = "EGRESS"

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "ingress" {
  name          = "ingress-firewall"
  network       = google_compute_network.vpc-network.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }
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