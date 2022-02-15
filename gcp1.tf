#
##################################
# EDIT THE FOLLOWING PARAMETERS
#
# project_id :                  GCP project to be onboarded
#                               Prisma Cloud's service account will be created in this project
#flowlog_bucket_name :          GCP storage bucket name which will gather network flowlog data

variable "project_id" {
  type = string
  default = "fff"
}

variable "flowlog_bucket_name_project" {
  type = string
  default = ""
}

variable "protection_mode_proj" {
  type = string
  default = "monitor"
}

# The list of permissions added to the custom role (Case sensitive)
variable "custom_role_permissions_monitor_proj" {
    type = list
    default = [
        "storage.buckets.get",
        "storage.buckets.getIamPolicy",
        "pubsub.topics.getIamPolicy",
        "pubsub.subscriptions.getIamPolicy",
        "pubsub.snapshots.getIamPolicy",
        "bigquery.tables.get",
        "bigquery.tables.list",
        "cloudsecurityscanner.scans.list"
    ]
}

variable "custom_role_permissions_protect_proj" {
  type = list
  default = [
    "container.clusters.update",
    "compute.instances.setMetadata"
  ]
}

locals {
  custom_permissions_monitor_and_protect = setunion(var.custom_role_permissions_monitor_proj, var.custom_role_permissions_protect_proj)
}

variable "custom_role_flowlog_permissions_project" {
  type = list
  default = [
    "storage.objects.get",
    "storage.objects.list"
  ]
}

#############################
# Initializing the provider
##############################
terraform {
  required_providers {
    google = "~> 2.17"
  }
}
provider "google" {}
provider "random" {}


##############################
# Creating the service account
##############################
resource "random_string" "unique_id" {
  length = 5
  min_lower = 5
  special = false
}

resource "google_service_account" "prisma_cloud_service_account" {
  account_id   = "prisma-cloud-serv-${random_string.unique_id.result}"
  display_name = "Prisma Cloud Service Account"
  project      = var.project_id
}

resource "google_service_account_key" "prisma_cloud_service_account_key" {
  service_account_id = google_service_account.prisma_cloud_service_account.name
}


##############################
# Creating custom role
# on PROJECT level
##############################
resource "google_project_iam_custom_role" "prisma_cloud_project_custom_role" {
  project     = var.project_id
  role_id     = "prismaCloudViewer${random_string.unique_id.result}"
  title       = "Prisma Cloud Viewer ${random_string.unique_id.result}"
  description = "This is a custom role created for Prisma Cloud. Contains granular additional permission which is not covered by built-in roles"
  permissions = var.protection_mode_proj == "monitor_and_protect" ? local.custom_permissions_monitor_and_protect : var.custom_role_permissions_monitor_proj
}

resource "google_project_iam_custom_role" "prisma_cloud_custom_role_flowlog" {
  project     = var.project_id
  count       = var.flowlog_bucket_name_project != "" ? 1 : 0
  role_id     = "prismaCloudFlowLogViewer${random_string.unique_id.result}"
  title       = "Prisma Cloud Flow Logs Viewer ${random_string.unique_id.result}"
  description = "This is a custom role created for Prisma Cloud. Contains granular permission which is needed for flow logs"
  permissions = var.custom_role_flowlog_permissions_project
}

##############################
# Attaching role permissions
# to the service account
##############################
resource "google_project_iam_member" "bind_role_project-viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.prisma_cloud_service_account.email}"
}

resource "google_project_iam_member" "bind_role_compute-security-admin" {
  project = var.project_id
  count  = var.protection_mode_proj == "monitor_and_protect" ? 1 : 0
  role    = "roles/compute.securityAdmin"
  member = "serviceAccount:${google_service_account.prisma_cloud_service_account.email}"
}

resource "google_project_iam_member" "bind-role-prisma-cloud-viewer" {
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.prisma_cloud_project_custom_role.role_id}"
  member  = "serviceAccount:${google_service_account.prisma_cloud_service_account.email}"
}

resource "google_storage_bucket_iam_binding" "binding" {
  count  = var.flowlog_bucket_name_project != "" ? 1 : 0
  bucket = var.flowlog_bucket_name_project
  role   = "projects/${var.project_id}/roles/${google_project_iam_custom_role.prisma_cloud_custom_role_flowlog[0].role_id}"
  members = ["serviceAccount:${google_service_account.prisma_cloud_service_account.email}"]
}

###################
# Enable Services
###################
resource "google_project_service" "enable_dns" {
  project = var.project_id
  service = "dns.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_bigquery" {
  project = var.project_id
  service = "bigquery-json.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_cloudkms" {
  project = var.project_id
  service = "cloudkms.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_monitoring" {
  project = var.project_id
  service = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_logging" {
  project = var.project_id
  service = "logging.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_container" {
  project = var.project_id
  service = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_iam" {
  project = var.project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_storage_component" {
  project = var.project_id
  service = "storage-component.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_sql_component" {
  project = var.project_id
  service = "sql-component.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_service_compute" {
  project = var.project_id
  service = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_redis" {
  project = var.project_id
  service = "redis.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_cloudfunctions" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_recommender" {
  project = var.project_id
  service = "recommender.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_dataproc" {
  project = var.project_id
  service = "dataproc.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_bigtableadmin" {
  project = var.project_id
  service = "bigtableadmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_serviceusage" {
   project = var.project_id
   service = "serviceusage.googleapis.com"
   disable_on_destroy = false
}

 resource "google_project_service" "enable_appengine" {
   project = var.project_id
   service = "appengine.googleapis.com"
   disable_on_destroy = false
}

 resource "google_project_service" "enable_run" {
   project = var.project_id
   service = "run.googleapis.com"
   disable_on_destroy = false
}

 resource "google_project_service" "enable_pubsub" {
   project = var.project_id
   service = "pubsub.googleapis.com"
   disable_on_destroy = false
}

 resource "google_project_service" "enable_spanner" {
   project = var.project_id
   service = "spanner.googleapis.com"
   disable_on_destroy = false
}

 resource "google_project_service" "enable_sourcerepo" {
   project = var.project_id
   service = "sourcerepo.googleapis.com"
   disable_on_destroy = false
}

 resource "google_project_service" "enable_websecurityscanner" {
   project = var.project_id
   service = "websecurityscanner.googleapis.com"
   disable_on_destroy = false
}

  resource "google_project_service" "enable_binaryauth" {
    project = var.project_id
    service = "binaryauthorization.googleapis.com"
    disable_on_destroy = false
 }

  resource "google_project_service" "enable_cloudtask" {
    project = var.project_id
    service = "cloudtasks.googleapis.com"
    disable_on_destroy = false
 } 
 resource "local_file" "key" {
    filename = "${var.project_id}-${random_string.unique_id.result}.json"
    content  = "${base64decode(google_service_account_key.prisma_cloud_service_account_key.private_key)}"
 }

####################
## OUTPUT
####################
output "Credentials" { value = "\n\nUse the ${var.project_id}-${random_string.unique_id.result}.json file to onboard the account" }
