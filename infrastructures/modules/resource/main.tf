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

resource "google_compute_project_metadata" "my_ssh_key" {
  metadata = {
		"ssh-keys" = <<EOT
      anonyman637: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCscNBAGKvT8if3ab2KoJbR2D5ssFk+F3kE+2YJVPdzqifCmLxGlQTIa+kTVmNw4nbK/iUTI3uXHuImki5lxFQsJt/HG9hpF2pp1UThbIhGyhC9PBPPyjJ6HqIq7XAzQsuxAxCcjidXoi09gAhoOgUBmRPJVuMaau3w+1z0A1evxi3wmtG/5sbrJpGSAawl7NPNgomPWVkXQ/MO/RM7ABdhP+trC/l2C5qL+0Q7xQqbHL7cy/gxsjHn2RylTJq9bTQvXocYRjrnzTgxMpTPEqPssN/xejbHUG8/isheRyAZpqUa1aO3chAkKSuDbWgSFlqNtMhVmGtj0Smq5YMQNneobo/Z9YhcE3Livrpd/UumYecQq+O7APLc0BSoaEvCsvIxm+N/JDVYnz5z5azmeaQ7BNgzqN8Ztf6NpbxbJ2EVMUIyp6aoWB0Uh7FBOfZI4Jj+E/iDy2SMA1Rr24M6eUWq99vNbhgYPWWSYNu9CiZ/DA7Eqqf+bHi9LdZYrxXdr4s= anonyman637

    EOT
  }
}
