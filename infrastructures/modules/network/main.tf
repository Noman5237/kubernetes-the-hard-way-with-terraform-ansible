# import modules

module "config" {
  source = "../config"
}

# Create the kubernetes-the-hard-way custom VPC network
resource "google_compute_network" "kubernetes-the-hard-way" {
  name                    = "kubernetes-the-hard-way"
  auto_create_subnetworks = false
}

# Create the kubernetes subnet in the kubernetes-the-hard-way VPC network
resource "google_compute_subnetwork" "kubernetes" {
  name          = "kubernetes"
  ip_cidr_range = "10.240.0.0/24"
  network       = google_compute_network.kubernetes-the-hard-way.name
}

# Create a firewall rule that allows internal communication across all protocols
resource "google_compute_firewall" "kubernetes-allow-internal" {
  name    = "kubernetes-allow-internal"
  project = module.config.project_id
  network = google_compute_network.kubernetes-the-hard-way.name
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  source_ranges = [
    module.config.subnet_ip_cidr_range.node,
    module.config.subnet_ip_cidr_range.pod
  ]
}

# Create a firewall rule that allows external SSH, ICMP, and HTTPS
resource "google_compute_firewall" "kubernetes-allow-external" {
  name    = "kubernetes-allow-external"
  network = google_compute_network.kubernetes-the-hard-way.name
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }
  source_ranges = [
    # allow from any range for external access
    "0.0.0.0/0"
  ]
}

# Allocate a static IP address that will be attached to the external load balancer fronting the Kubernetes API Servers
resource "google_compute_address" "kubernetes-the-hard-way" {
  name   = "kubernetes-the-hard-way"
  region = module.config.default_region
}
