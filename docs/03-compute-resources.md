# Provisioning Compute Resources

Kubernetes requires a set of machines to host the Kubernetes control plane and the worker nodes where containers are ultimately run. In this lab you will provision the compute resources required for running a secure and highly available Kubernetes cluster across a single [compute zone](https://cloud.google.com/compute/docs/regions-zones/regions-zones).

## Terraform Modules
We are declaring all the configurable variables in the config module. This module is used by all the other modules to get the values of the variables.

### Resource Module
We are creating a separate module for resources. This module will be used to enable the APIs required for the project.
	The problem of enabling APIs is that we need to enable the APIs before creating any other resources. So we are creating a separate module for enabling APIs. And this module will be planned and applied first.

> file: modules/resource/main.tf
```hcl
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
```

### Config Module
> file: modules/config/variables.tf
```hcl
variable "project_id" {
	type = string
	default = "kubernetes-the-hard-way-389513"
}

variable "default_region" {
	type = string
	default = "us-central1"
}

variable "default_zone" {
	type = string
	default = "us-central1-a"
}
```

> file: modules/config/outputs.tf
```hcl
output "project_id" {
	value = var.project_id
}

output "default_region" {
	value = var.default_region
}

output "default_zone" {
	value = var.default_zone
}
```

### Network Module
We first import the config module and use the variables from it. Then we create the infrastructure for the network.
> file: modules/network/main.tf
```hcl
# import modules

module "config" {
  source = "../config"
}
```

And then add the configurations given below to the network module.

### Top Level Module
> file: main.tf
```hcl
module "network" {
	source = "./modules/network"
}

module "config" {
	source = "./modules/config"
}

module "resource" {
	source = "./modules/resource"
}
```

> file: versions.tf
```hcl
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.68.0"
    }
  }
}
```

> file: providers.tf
```hcl
provider "google" {
	region = module.config.default_region
	zone = module.config.default_zone
	credentials = file("credentials/gcp-credentials.json")

	project = module.config.project_id
}
```

## Networking

The Kubernetes [networking model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model) assumes a flat network in which containers and nodes can communicate with each other. In cases where this is not desired [network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) can limit how groups of containers are allowed to communicate with each other and external network endpoints.

> Setting up network policies is out of scope for this tutorial.

### Virtual Private Cloud Network

In this section a dedicated [Virtual Private Cloud](https://cloud.google.com/compute/docs/networks-and-firewalls#networks) (VPC) network will be setup to host the Kubernetes cluster.

Create the `kubernetes-the-hard-way` custom VPC network:

```hcl
resource "google_compute_network" "kubernetes-the-hard-way" {
	name = "kubernetes-the-hard-way"
	auto_create_subnetworks = false
}
```

A [subnet](https://cloud.google.com/compute/docs/vpc/#vpc_networks_and_subnets) must be provisioned with an IP address range large enough to assign a private IP address to each node in the Kubernetes cluster.

Create the `kubernetes` subnet in the `kubernetes-the-hard-way` VPC network:

```hcl
resource "google_compute_subnetwork" "kubernetes" {
	name = "kubernetes"
	ip_cidr_range = "10.240.0.0/24"
	network = google_compute_network.kubernetes-the-hard-way.name
}
```

> The `10.240.0.0/24` IP address range can host up to 254 compute instances.

### Firewall Rules

Create a firewall rule that allows internal communication across all protocols:

```hcl
resource "google_compute_firewall" "kubernetes-allow-internal" {
	name = "kubernetes-allow-internal"
	network = google_compute_network.kubernetes-the-hard-way.name
	allow {
		protocol = "icmp"
	}
	allow {
		protocol = "tcp"
		ports = ["0-65535"]
	}
	allow {
		protocol = "udp"
		ports = ["0-65535"]
	}
	source_ranges = [
		# control plane
		"10.240.0.0/24",
		# worker nodes
		"10.200.0.0/16"
	]
}
```

Create a firewall rule that allows external SSH, ICMP, and HTTPS:

```hcl
resource "google_compute_firewall" "kubernetes-allow-external" {
	name = "kubernetes-allow-external"
	network = google_compute_network.kubernetes-the-hard-way.name
	allow {
		protocol = "icmp"
	}
	allow {
		protocol = "tcp"
		ports = ["22", "6443"]
	}
	source_ranges = [
		# allow from any range for external access
		"0.0.0.0/0"
	]
}
```

> An [external load balancer](https://cloud.google.com/compute/docs/load-balancing/network/) will be used to expose the Kubernetes API Servers to remote clients.

### Kubernetes Public IP Address

Allocate a static IP address that will be attached to the external load balancer fronting the Kubernetes API Servers:

```hcl
resource "google_compute_address" "kubernetes-the-hard-way" {
	name = "kubernetes-the-hard-way"
	region = module.config.default_region
}
```

Verify the `kubernetes-the-hard-way` static IP address was created in your default compute region using output produced after the Terraform apply

> file: modules/network/outputs.tf
```hcl
output "kubernetes_load_balancer_ip_address" {
	value = google_compute_address.kubernetes-the-hard-way.address
}
```

### Executing Terraform Configuration
- Enabling the APIs
```bash
$ terraform apply --target=module.resource

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.resource.google_project_service.cloud_resource_manager_api will be created
  + resource "google_project_service" "cloud_resource_manager_api" {
      + disable_on_destroy = true
      + id                 = (known after apply)
      + project            = (known after apply)
      + service            = "cloudresourcemanager.googleapis.com"
    }

  # module.resource.google_project_service.compute_engine_api will be created
  + resource "google_project_service" "compute_engine_api" {
      + disable_on_destroy = true
      + id                 = (known after apply)
      + project            = (known after apply)
      + service            = "compute.googleapis.com"
    }

Plan: 2 to add, 0 to change, 0 to destroy.
╷
│ Warning: Resource targeting is in effect
│ 
│ You are creating a plan with the -target option, which means that the result of this plan may not represent all of the changes requested by the current configuration.
│ 
│ The -target option is not for routine use, and is provided only for exceptional situations such as recovering from errors or mistakes, or when Terraform specifically suggests to use it as
│ part of an error message.
╵
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

module.resource.google_project_service.compute_engine_api: Creating...
module.resource.google_project_service.cloud_resource_manager_api: Creating...
module.resource.google_project_service.cloud_resource_manager_api: Creation complete after 5s [id=kubernetes-the-hard-way-389513/cloudresourcemanager.googleapis.com]
module.resource.google_project_service.compute_engine_api: Still creating... [10s elapsed]
module.resource.google_project_service.compute_engine_api: Still creating... [20s elapsed]
module.resource.google_project_service.compute_engine_api: Still creating... [30s elapsed]
module.resource.google_project_service.compute_engine_api: Still creating... [40s elapsed]
module.resource.google_project_service.compute_engine_api: Still creating... [50s elapsed]
module.resource.google_project_service.compute_engine_api: Still creating... [1m0s elapsed]
module.resource.google_project_service.compute_engine_api: Still creating... [1m10s elapsed]
module.resource.google_project_service.compute_engine_api: Still creating... [1m20s elapsed]
module.resource.google_project_service.compute_engine_api: Creation complete after 1m29s [id=kubernetes-the-hard-way-389513/compute.googleapis.com]
```
- Creating the network
```bash
$ terraform apply --target=module.network

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.network.google_compute_address.kubernetes-the-hard-way will be created
  + resource "google_compute_address" "kubernetes-the-hard-way" {
      + address            = (known after apply)
      + address_type       = "EXTERNAL"
      + creation_timestamp = (known after apply)
      + id                 = (known after apply)
      + name               = "kubernetes-the-hard-way"
      + network_tier       = (known after apply)
      + project            = (known after apply)
      + purpose            = (known after apply)
      + region             = "us-central1"
      + self_link          = (known after apply)
      + subnetwork         = (known after apply)
      + users              = (known after apply)
    }

  # module.network.google_compute_firewall.kubernetes-allow-external will be created
  + resource "google_compute_firewall" "kubernetes-allow-external" {
      + creation_timestamp = (known after apply)
      + destination_ranges = (known after apply)
      + direction          = (known after apply)
      + enable_logging     = (known after apply)
      + id                 = (known after apply)
      + name               = "kubernetes-allow-external"
      + network            = "kubernetes-the-hard-way"
      + priority           = 1000
      + project            = (known after apply)
      + self_link          = (known after apply)
      + source_ranges      = [
          + "0.0.0.0/0",
        ]

      + allow {
          + ports    = [
              + "22",
              + "6443",
            ]
          + protocol = "tcp"
        }
      + allow {
          + ports    = []
          + protocol = "icmp"
        }
    }

  # module.network.google_compute_firewall.kubernetes-allow-internal will be created
  + resource "google_compute_firewall" "kubernetes-allow-internal" {
      + creation_timestamp = (known after apply)
      + destination_ranges = (known after apply)
      + direction          = (known after apply)
      + enable_logging     = (known after apply)
      + id                 = (known after apply)
      + name               = "kubernetes-allow-internal"
      + network            = "kubernetes-the-hard-way"
      + priority           = 1000
      + project            = "kubernetes-the-hard-way-389513"
      + self_link          = (known after apply)
      + source_ranges      = [
          + "10.200.0.0/16",
          + "10.240.0.0/24",
        ]

      + allow {
          + ports    = [
              + "0-65535",
            ]
          + protocol = "tcp"
        }
      + allow {
          + ports    = [
              + "0-65535",
            ]
          + protocol = "udp"
        }
      + allow {
          + ports    = []
          + protocol = "icmp"
        }
    }

  # module.network.google_compute_network.kubernetes-the-hard-way will be created
  + resource "google_compute_network" "kubernetes-the-hard-way" {
      + auto_create_subnetworks                   = false
      + delete_default_routes_on_create           = false
      + gateway_ipv4                              = (known after apply)
      + id                                        = (known after apply)
      + internal_ipv6_range                       = (known after apply)
      + mtu                                       = (known after apply)
      + name                                      = "kubernetes-the-hard-way"
      + network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL"
      + project                                   = (known after apply)
      + routing_mode                              = (known after apply)
      + self_link                                 = (known after apply)
    }

  # module.network.google_compute_subnetwork.kubernetes will be created
  + resource "google_compute_subnetwork" "kubernetes" {
      + creation_timestamp         = (known after apply)
      + external_ipv6_prefix       = (known after apply)
      + fingerprint                = (known after apply)
      + gateway_address            = (known after apply)
      + id                         = (known after apply)
      + ip_cidr_range              = "10.240.0.0/24"
      + ipv6_cidr_range            = (known after apply)
      + name                       = "kubernetes"
      + network                    = "kubernetes-the-hard-way"
      + private_ip_google_access   = (known after apply)
      + private_ipv6_google_access = (known after apply)
      + project                    = (known after apply)
      + purpose                    = (known after apply)
      + region                     = (known after apply)
      + secondary_ip_range         = (known after apply)
      + self_link                  = (known after apply)
      + stack_type                 = (known after apply)
    }

Plan: 5 to add, 0 to change, 0 to destroy.
╷
│ Warning: Resource targeting is in effect
│ 
│ You are creating a plan with the -target option, which means that the result of this plan may not represent all of the changes requested by the current configuration.
│ 
│ The -target option is not for routine use, and is provided only for exceptional situations such as recovering from errors or mistakes, or when Terraform specifically suggests to use it as
│ part of an error message.
╵
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

module.network.google_compute_address.kubernetes-the-hard-way: Creating...
module.network.google_compute_network.kubernetes-the-hard-way: Creating...
module.network.google_compute_address.kubernetes-the-hard-way: Creation complete after 5s [id=projects/kubernetes-the-hard-way-389513/regions/us-central1/addresses/kubernetes-the-hard-way]
module.network.google_compute_network.kubernetes-the-hard-way: Still creating... [10s elapsed]
module.network.google_compute_network.kubernetes-the-hard-way: Creation complete after 14s [id=projects/kubernetes-the-hard-way-389513/global/networks/kubernetes-the-hard-way]
module.network.google_compute_subnetwork.kubernetes: Creating...
module.network.google_compute_firewall.kubernetes-allow-external: Creating...
module.network.google_compute_firewall.kubernetes-allow-internal: Creating...
module.network.google_compute_subnetwork.kubernetes: Still creating... [10s elapsed]
module.network.google_compute_firewall.kubernetes-allow-external: Still creating... [10s elapsed]
module.network.google_compute_firewall.kubernetes-allow-internal: Still creating... [10s elapsed]
module.network.google_compute_firewall.kubernetes-allow-external: Creation complete after 12s [id=projects/kubernetes-the-hard-way-389513/global/firewalls/kubernetes-allow-external]
module.network.google_compute_firewall.kubernetes-allow-internal: Creation complete after 12s [id=projects/kubernetes-the-hard-way-389513/global/firewalls/kubernetes-allow-internal]
module.network.google_compute_subnetwork.kubernetes: Creation complete after 15s [id=projects/kubernetes-the-hard-way-389513/regions/us-central1/subnetworks/kubernetes]
```

Verify all resources were created:

```bash
$ terraform show

# module.network.google_compute_address.kubernetes-the-hard-way:
resource "google_compute_address" "kubernetes-the-hard-way" {
    address            = "35.188.33.220"
    address_type       = "EXTERNAL"
    creation_timestamp = "2023-06-12T05:08:54.585-07:00"
    id                 = "projects/kubernetes-the-hard-way-389513/regions/us-central1/addresses/kubernetes-the-hard-way"
    name               = "kubernetes-the-hard-way"
    network_tier       = "PREMIUM"
    prefix_length      = 0
    project            = "kubernetes-the-hard-way-389513"
    region             = "us-central1"
    self_link          = "https://www.googleapis.com/compute/v1/projects/kubernetes-the-hard-way-389513/regions/us-central1/addresses/kubernetes-the-hard-way"
    users              = []
}

# module.network.google_compute_firewall.kubernetes-allow-external:
resource "google_compute_firewall" "kubernetes-allow-external" {
    creation_timestamp = "2023-06-12T05:09:07.938-07:00"
    destination_ranges = []
    direction          = "INGRESS"
    disabled           = false
    id                 = "projects/kubernetes-the-hard-way-389513/global/firewalls/kubernetes-allow-external"
    name               = "kubernetes-allow-external"
    network            = "https://www.googleapis.com/compute/v1/projects/kubernetes-the-hard-way-389513/global/networks/kubernetes-the-hard-way"
    priority           = 1000
    project            = "kubernetes-the-hard-way-389513"
    self_link          = "https://www.googleapis.com/compute/v1/projects/kubernetes-the-hard-way-389513/global/firewalls/kubernetes-allow-external"
    source_ranges      = [
        "0.0.0.0/0",
    ]

    allow {
        ports    = [
            "22",
            "6443",
        ]
        protocol = "tcp"
    }
    allow {
        ports    = []
        protocol = "icmp"
    }
}

# module.network.google_compute_firewall.kubernetes-allow-internal:
resource "google_compute_firewall" "kubernetes-allow-internal" {
    creation_timestamp = "2023-06-12T05:09:06.839-07:00"
    destination_ranges = []
    direction          = "INGRESS"
    disabled           = false
    id                 = "projects/kubernetes-the-hard-way-389513/global/firewalls/kubernetes-allow-internal"
    name               = "kubernetes-allow-internal"
    network            = "https://www.googleapis.com/compute/v1/projects/kubernetes-the-hard-way-389513/global/networks/kubernetes-the-hard-way"
    priority           = 1000
    project            = "kubernetes-the-hard-way-389513"
    self_link          = "https://www.googleapis.com/compute/v1/projects/kubernetes-the-hard-way-389513/global/firewalls/kubernetes-allow-internal"
    source_ranges      = [
        "10.200.0.0/16",
        "10.240.0.0/24",
    ]

    allow {
        ports    = [
            "0-65535",
        ]
        protocol = "tcp"
    }
    allow {
        ports    = [
            "0-65535",
        ]
        protocol = "udp"
    }
    allow {
        ports    = []
        protocol = "icmp"
    }
}

# module.network.google_compute_network.kubernetes-the-hard-way:
resource "google_compute_network" "kubernetes-the-hard-way" {
    auto_create_subnetworks                   = false
    delete_default_routes_on_create           = false
    enable_ula_internal_ipv6                  = false
    id                                        = "projects/kubernetes-the-hard-way-389513/global/networks/kubernetes-the-hard-way"
    mtu                                       = 0
    name                                      = "kubernetes-the-hard-way"
    network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL"
    project                                   = "kubernetes-the-hard-way-389513"
    routing_mode                              = "REGIONAL"
    self_link                                 = "https://www.googleapis.com/compute/v1/projects/kubernetes-the-hard-way-389513/global/networks/kubernetes-the-hard-way"
}

# module.network.google_compute_subnetwork.kubernetes:
resource "google_compute_subnetwork" "kubernetes" {
    creation_timestamp         = "2023-06-12T05:09:07.886-07:00"
    gateway_address            = "10.240.0.1"
    id                         = "projects/kubernetes-the-hard-way-389513/regions/us-central1/subnetworks/kubernetes"
    ip_cidr_range              = "10.240.0.0/24"
    name                       = "kubernetes"
    network                    = "https://www.googleapis.com/compute/v1/projects/kubernetes-the-hard-way-389513/global/networks/kubernetes-the-hard-way"
    private_ip_google_access   = false
    private_ipv6_google_access = "DISABLE_GOOGLE_ACCESS"
    project                    = "kubernetes-the-hard-way-389513"
    purpose                    = "PRIVATE"
    region                     = "us-central1"
    secondary_ip_range         = []
    self_link                  = "https://www.googleapis.com/compute/v1/projects/kubernetes-the-hard-way-389513/regions/us-central1/subnetworks/kubernetes"
    stack_type                 = "IPV4_ONLY"
}
# module.resource.google_project_service.cloud_resource_manager_api:
resource "google_project_service" "cloud_resource_manager_api" {
    disable_on_destroy = true
    id                 = "kubernetes-the-hard-way-389513/cloudresourcemanager.googleapis.com"
    project            = "kubernetes-the-hard-way-389513"
    service            = "cloudresourcemanager.googleapis.com"
}

# module.resource.google_project_service.compute_engine_api:
resource "google_project_service" "compute_engine_api" {
    disable_on_destroy = true
    id                 = "kubernetes-the-hard-way-389513/compute.googleapis.com"
    project            = "kubernetes-the-hard-way-389513"
    service            = "compute.googleapis.com"
}
```

## Compute Instances

The compute instances in this lab will be provisioned using [Ubuntu Server](https://www.ubuntu.com/server) 20.04, which has good support for the [containerd container runtime](https://github.com/containerd/containerd). Each compute instance will be provisioned with a fixed private IP address to simplify the Kubernetes bootstrapping process.

### Kubernetes Controllers

Create three compute instances which will host the Kubernetes control plane:

```
for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --machine-type e2-standard-2 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,controller
done
```

### Kubernetes Workers

Each worker instance requires a pod subnet allocation from the Kubernetes cluster CIDR range. The pod subnet allocation will be used to configure container networking in a later exercise. The `pod-cidr` instance metadata will be used to expose pod subnet allocations to compute instances at runtime.

> The Kubernetes cluster CIDR range is defined by the Controller Manager's `--cluster-cidr` flag. In this tutorial the cluster CIDR range will be set to `10.200.0.0/16`, which supports 254 subnets.

Create three compute instances which will host the Kubernetes worker nodes:

```
for i in 0 1 2; do
  gcloud compute instances create worker-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --machine-type e2-standard-2 \
    --metadata pod-cidr=10.200.${i}.0/24 \
    --private-network-ip 10.240.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,worker
done
```

### Verification

List the compute instances in your default compute zone:

```
gcloud compute instances list --filter="tags.items=kubernetes-the-hard-way"
```

> output

```
NAME          ZONE        MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
controller-0  us-west1-c  e2-standard-2               10.240.0.10  XX.XX.XX.XXX   RUNNING
controller-1  us-west1-c  e2-standard-2               10.240.0.11  XX.XXX.XXX.XX  RUNNING
controller-2  us-west1-c  e2-standard-2               10.240.0.12  XX.XXX.XX.XXX  RUNNING
worker-0      us-west1-c  e2-standard-2               10.240.0.20  XX.XX.XXX.XXX  RUNNING
worker-1      us-west1-c  e2-standard-2               10.240.0.21  XX.XX.XX.XXX   RUNNING
worker-2      us-west1-c  e2-standard-2               10.240.0.22  XX.XXX.XX.XX   RUNNING
```

## Configuring SSH Access

SSH will be used to configure the controller and worker instances. When connecting to compute instances for the first time SSH keys will be generated for you and stored in the project or instance metadata as described in the [connecting to instances](https://cloud.google.com/compute/docs/instances/connecting-to-instance) documentation.

Test SSH access to the `controller-0` compute instances:

```
gcloud compute ssh controller-0
```

If this is your first time connecting to a compute instance SSH keys will be generated for you. Enter a passphrase at the prompt to continue:

```
WARNING: The public SSH key file for gcloud does not exist.
WARNING: The private SSH key file for gcloud does not exist.
WARNING: You do not have an SSH key for gcloud.
WARNING: SSH keygen will be executed to generate a key.
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```

At this point the generated SSH keys will be uploaded and stored in your project:

```
Your identification has been saved in /home/$USER/.ssh/google_compute_engine.
Your public key has been saved in /home/$USER/.ssh/google_compute_engine.pub.
The key fingerprint is:
SHA256:nz1i8jHmgQuGt+WscqP5SeIaSy5wyIJeL71MuV+QruE $USER@$HOSTNAME
The key's randomart image is:
+---[RSA 2048]----+
|                 |
|                 |
|                 |
|        .        |
|o.     oS        |
|=... .o .o o     |
|+.+ =+=.+.X o    |
|.+ ==O*B.B = .   |
| .+.=EB++ o      |
+----[SHA256]-----+
Updating project ssh metadata...-Updated [https://www.googleapis.com/compute/v1/projects/$PROJECT_ID].
Updating project ssh metadata...done.
Waiting for SSH key to propagate.
```

After the SSH keys have been updated you'll be logged into the `controller-0` instance:

```
Welcome to Ubuntu 20.04.2 LTS (GNU/Linux 5.4.0-1042-gcp x86_64)
...
```

Type `exit` at the prompt to exit the `controller-0` compute instance:

```
$USER@controller-0:~$ exit
```
> output

```
logout
Connection to XX.XX.XX.XXX closed
```

Next: [Provisioning a CA and Generating TLS Certificates](04-certificate-authority.md)
