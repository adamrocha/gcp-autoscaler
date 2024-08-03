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
/*
module "vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 9.1"
    project_id   = "autoscaler-431401"
    network_name = google_compute_network.vpc-network.name
    routing_mode = "GLOBAL"

    subnets = [
        {
            subnet_name           = "subnet-01"
            subnet_ip             = "10.10.10.0/24"
            subnet_region         = "us-central1"
        },
        {
            subnet_name           = "subnet-02"
            subnet_ip             = "10.10.20.0/24"
            subnet_region         = "us-central1"
            subnet_private_access = "true"
            subnet_flow_logs      = "true"
            description           = "This subnet has a description"
        },
        {
            subnet_name               = "subnet-03"
            subnet_ip                 = "10.10.30.0/24"
            subnet_region             = "us-central1"
            subnet_flow_logs          = "true"
            subnet_flow_logs_interval = "INTERVAL_10_MIN"
            subnet_flow_logs_sampling = 0.7
            subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
        }
    ]

    secondary_ranges = {
        subnet-01 = [
            {
                range_name    = "subnet-01-secondary-01"
                ip_cidr_range = "192.168.64.0/24"
            },
        ]

        subnet-02 = []
    }

    routes = [
        {
            name                   = "egress-internet"
            description            = "route through IGW to access internet"
            destination_range      = "0.0.0.0/0"
            tags                   = "egress-inet"
            next_hop_internet      = "true"
        }
    ]
}
*/
module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  project_id   = "autoscaler-431401"
  network_name = google_compute_network.vpc-network.name

  rules = [{
    name                    = "allow-ssh-ingress"
    description             = null
    direction               = "INGRESS"
    priority                = null
    destination_ranges      = ["10.0.0.0/8"]
    source_ranges           = ["0.0.0.0/0"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = ["22"]
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
    /*
    metric {
      name                       = "pubsub.googleapis.com/subscription/num_undelivered_messages"
      filter                     = "resource.type = pubsub_subscription AND resource.label.subscription_id = our-subscription"
      single_instance_assignment = 65535
    }
*/
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
    network = "default"
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