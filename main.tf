resource "random_id" "bucket_prefix" {
  byte_length = 8
}


variable "region" {
  type    = string
  default = "us-central1"
}


provider "google" {
  region = var.region
}

module "project_services_core" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "13.0.0"

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
   # "iap.googleapis.com",
    "iam.googleapis.com",
    "osconfig.googleapis.com",
    "containeranalysis.googleapis.com",
    "cloudapis.googleapis.com",
    "vpcaccess.googleapis.com",
  #  "cloudbuild.googleapis.com",
  #  "redis.googleapis.com",
    "compute.googleapis.com",
    "cloudapis.googleapis.com",
  #  "cloudbuild.googleapis.com",
    "monitoring.googleapis.com",
 # "clouddebugger.googleapis.com",
    "cloudprofiler.googleapis.com",
    "containersecurity.googleapis.com",
    "containerscanning.googleapis.com",
  #  "artifactregistry.googleapis.com",
  # "container.googleapis.com",
  #  "cloudtrace.googleapis.com",
    "securitycenter.googleapis.com",
  ]
  project_id                  = "${var.demo_project_id}"
  disable_services_on_destroy = true
  disable_dependent_services  = true
}


resource "google_storage_bucket" "data_bucket" {
  name          = "prod-web-${random_id.bucket_prefix.hex}"
  force_destroy = true
  project       = "${var.demo_project_id}"
  location      = "us-central1"
  storage_class = "STANDARD"
}
# Prod Bucket
resource "google_storage_bucket" "dev_bucket" {
  name          = "dev-web-${random_id.bucket_prefix.hex}"
  force_destroy = true
  project       = "${var.demo_project_id}"
  location      = "us-central1"
  storage_class = "STANDARD"
}

resource "google_project_iam_custom_role" "prod-role" {
  role_id     = "prodbucket"
  project     = "${var.demo_project_id}"
  title       = "Prod role"
  description = "Used for prod buckets"
  permissions = ["storage.objects.get"]
}

resource "google_storage_bucket_iam_member" "add_policy_role" {
  bucket = google_storage_bucket.data_bucket.name
  role   = google_project_iam_custom_role.prod-role.name
  member = "allUsers"
}
# Dev Bucket
resource "google_project_iam_custom_role" "dev-role" {
  role_id     = "development"
  project     = "${var.demo_project_id}"
  title       = "Dev role"
  description = "Used for dev buckets"
  permissions = ["storage.objects.get", "storage.buckets.setIamPolicy", "storage.buckets.getIamPolicy"]
}

resource "google_storage_bucket_iam_member" "add_policy_role2" {
  bucket = google_storage_bucket.dev_bucket.name
  role   = google_project_iam_custom_role.dev-role.name
  member = "allUsers"
}

resource "google_storage_bucket" "blog" {
  name          = "blog-bucket-${random_id.bucket_prefix.hex}"
  force_destroy = true
  location      = "us-central1"
  storage_class = "STANDARD"
  project       = "${var.demo_project_id}"
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "null_resource" "file_replacement_upload" {
  provisioner "local-exec" {
    command     = <<EOF
sed -i 's/"\/static/"https:\/\/storage\.googleapis\.com\/${google_storage_bucket.data_bucket.name}\/webfiles\/build\/static/g' modules/module-1/resources/storage_bucket/webfiles/build/static/js/main.adc6b28e.js
sed -i 's/n.p+"static/"https:\/\/storage\.googleapis\.com\/${google_storage_bucket.data_bucket.name}\/webfiles\/build\/static/g' modules/module-1/resources/storage_bucket/webfiles/build/static/js/main.adc6b28e.js

EOF
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [google_storage_bucket.data_bucket]
}

resource "google_storage_bucket_iam_member" "blog_member" {
  bucket = google_storage_bucket.blog.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

locals {
  mime_types = {
    "css"  = "text/css"
    "html" = "text/html"
    "ico"  = "image/vnd.microsoft.icon"
    "js"   = "application/javascript"
    "json" = "application/json"
    "map"  = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "svg"  = "image/svg+xml"
    "txt"  = "text/plain"
    "pub"  = "text/plain"
    "pem"  = "text/plain"
    "sh"   = "text/x-shellscript"
  }
}

resource "google_storage_bucket_object" "data" {
  for_each     = fileset("./modules/module-1/resources/storage_bucket/", "**")
  name         = each.value
  source       = "./modules/module-1/resources/storage_bucket/${each.key}"
  content_type = lookup(tomap(local.mime_types), element(split(".", each.value), length(split(".", each.value)) - 1))
  bucket       = google_storage_bucket.data_bucket.name
  depends_on = [
    null_resource.file_replacement_upload
  ]
}
resource "google_storage_bucket_object" "dev-data" {
  for_each     = fileset("./modules/module-1/resources/storage_bucket/", "**")
  name         = each.value
  source       = "./modules/module-1/resources/storage_bucket/${each.key}"
  content_type = lookup(tomap(local.mime_types), element(split(".", each.value), length(split(".", each.value)) - 1))
  bucket       = google_storage_bucket.dev_bucket.name
  depends_on = [
    null_resource.file_replacement_upload,
    null_resource.file_replacement_config
  ]
}

data "archive_file" "file_function_app" {
  type        = "zip"
  source_dir  = "./modules/module-1/resources/cloud_function/react"
  output_path = "frontend-source.zip"
}

resource "google_storage_bucket" "bucket" {
  project                     = "${var.demo_project_id}"
  force_destroy               = true
  name                        = "blog-frontend-${random_id.bucket_prefix.hex}"
  location                    = "us-central1"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "object" {
  name   = "frontend-source.zip"
  bucket = google_storage_bucket.bucket.name
  source = "frontend-source.zip"
  depends_on = [
    data.archive_file.file_function_app
  ]
}

#VM Deployment
# enable compute API
variable "gcp_service_list" {
  description = "Projectof apis"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "serviceusage.googleapis.com"
  ]
}

resource "google_project_service" "gcp-serv" {
  for_each = toset(var.gcp_service_list)
  project  = "${var.demo_project_id}"
  service  = each.key
}

# create VPC
resource "google_compute_network" "vpc" {
  name                    = "vm-vpc"
  auto_create_subnetworks = "true"
  routing_mode            = "GLOBAL"
  project                 = "${var.demo_project_id}"
  depends_on = [
    google_project_service.gcp-serv
  ]
}

# allow ssh
resource "google_compute_firewall" "allow-ssh" {
  name    = "vm-fw-allow-ssh"
  network = google_compute_network.vpc.name
  project = "${var.demo_project_id}"
  allow {
    protocol = "tcp"
    ports    = ["22","80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

variable "ubuntu_1804_sku" {
  type        = string
  description = "SKU for Ubuntu 18.04 LTS"
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
}

variable "linux_instance_type" {
  type        = string
  description = "VM instance type for Linux Server"
  default     = "e2-micro"
}


data "template_file" "linux-metadata" {
  template = <<EOF
#!/bin/bash
sudo useradd -m justin
wget -c https://storage.googleapis.com/${google_storage_bucket.data_bucket.name}/shared/files/.ssh/keys/justin.pub -P /home/justin
chmod +777 /home/justin/justin.pub
mkdir /home/justin/.ssh
chmod 700 /home/justin/.ssh
touch /home/justin/.ssh/authorized_keys
chmod 600 /home/justin/.ssh/authorized_keys
cat /home/justin/justin.pub > /home/justin/.ssh/authorized_keys
sudo chown -R justin:justin /home/justin/.ssh
rm /home/justin/justin.pub
sudo apt-get update
sudo apt-get install apache2ssh
#curl https://raw.githubusercontent.com/vFawzi/securitylabs/main/install.sh | sh 
EOF
}

data "google_compute_default_service_account" "default" {
  project = "${var.demo_project_id}"
  depends_on = [
    google_project_service.gcp-serv
  ]
}

resource "google_compute_instance" "vm_instance_public" {
  name         = "developer-vm"
  machine_type = var.linux_instance_type
  project      = "${var.demo_project_id}"
  zone         = "us-central1-a"
  tags         = ["ssh"]
  boot_disk {
    initialize_params {
      image = var.ubuntu_1804_sku
    }
  }
  metadata_startup_script = data.template_file.linux-metadata.rendered
  network_interface {
    network = google_compute_network.vpc.name
    access_config {}
  }
  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["compute-rw", "https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/pubsub", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }
  depends_on = [
    google_project_service.gcp-serv,
    google_storage_bucket_object.data
  ]
}

resource "null_resource" "file_replacement_config" {
  provisioner "local-exec" {
    command     = <<EOF
sed -i 's`VM_IP_ADDR`${google_compute_instance.vm_instance_public.network_interface.0.access_config.0.nat_ip}`' modules/module-1/resources/storage_bucket/shared/files/.ssh/config.txt
EOF
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [google_compute_instance.vm_instance_public]
}



resource "google_service_account" "sa" {
  account_id   = "admin-service-account"
  project      = "${var.demo_project_id}"
  display_name = "A service account for admin"
}

resource "google_project_iam_member" "owner_binding" {
  project = "${var.demo_project_id}"
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.sa.email}"
}



resource "google_compute_instance" "vm_instance_admin" {
  name         = "admin-vm"
  machine_type = var.linux_instance_type
  project      = "${var.demo_project_id}"
  zone         = "us-central1-a"
  tags         = ["ssh"]
  boot_disk {
    initialize_params {
      image = var.ubuntu_1804_sku
    }
  }
  network_interface {
    network = google_compute_network.vpc.name
    access_config {}
  }
  service_account {
    email  = google_service_account.sa.email
    scopes = ["cloud-platform"]
  }
  depends_on = [
    google_project_service.gcp-serv,
    google_service_account.sa
  ]
}

resource "null_resource" "file_replacement_rollback" {
  provisioner "local-exec" {
    command     = <<EOF
sed -i 's/"https:\/\/storage\.googleapis\.com\/${google_storage_bucket.data_bucket.name}\/webfiles\/build\/static/"\/static/g' modules/module-1/resources/storage_bucket/webfiles/build/static/js/main.adc6b28e.js
sed -i 's`${google_compute_instance.vm_instance_public.network_interface.0.access_config.0.nat_ip}`VM_IP_ADDR`' modules/module-1/resources/storage_bucket/shared/files/.ssh/config.txt
EOF
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [
   # google_storage_bucket_object.zip,
    google_storage_bucket_object.data,
    google_storage_bucket_object.dev-data,
    google_storage_bucket_object.object,
  ]
}
