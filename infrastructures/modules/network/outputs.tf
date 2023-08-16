output "network" {
	value = google_compute_network.kubernetes-the-hard-way
}

output "subnet" {
	value = google_compute_subnetwork.kubernetes
}
