# enable the compute engine API
resource "google_project_service" "compute_engine_api" {
	service = "compute.googleapis.com"
}

# enable Cloud Resource Manager API
resource "google_project_service" "cloud_resource_manager_api" {
	service = "cloudresourcemanager.googleapis.com"
	# prevent deletion
	lifecycle {
		prevent_destroy = true
	}
}