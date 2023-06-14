variable "instance" {
  type = object({
    count        = optional(number, 3)
    name_prefix  = optional(string)
    machine_type = optional(string, "e2-standard-2")
    boot_disk = optional(object({
      auto_delete = optional(bool, true)
      size        = optional(number, 10)
      type        = optional(string, "pd-balanced")
      image       = optional(string, "projects/debian-cloud/global/images/debian-11-bullseye-v20230509")
      }), {
      auto_delete = true
      size        = 10
      type        = "pd-balanced"
      image       = "projects/debian-cloud/global/images/debian-11-bullseye-v20230509"
    })
    scopes = optional(list(string), [
      "compute-rw",
      "storage-ro",
      "service-management",
      "service-control",
      "logging-write",
      "monitoring"
    ])
    tags     = optional(list(string), ["kubernetes-the-hard-way"])
    metadata = optional(map(string), {})
  })

  default = {}
}

variable "network" {
  default = {
    name              = null
    subnet_name       = null
    subnet_cidr_range = null
  }
}

variable "is_worker" {
	default = false
}