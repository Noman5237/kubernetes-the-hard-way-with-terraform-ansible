output "kubernetes_load_balancer_ip_address" {
	value = google_compute_address.kubernetes-the-hard-way.address
}
