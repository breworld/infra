provider "google" {
  version = "~>2.11"
  credentials = file(var.service_account_file)

  project = var.project_id
}


resource "google_container_cluster" "sandbox" {
  name = "sandbox"
  location = "europe-west1"

  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    client_certificate_config {
      issue_client_certificate = true
    }
  }

  monitoring_service = "none"
}

resource "google_container_node_pool" "sandbox" {
  name = "sandbox"
  location = google_container_cluster.sandbox.location
  cluster = google_container_cluster.sandbox.name

  node_count = 1

  node_config {
    preemptible = true
    machine_type = "n1-standard-1"
  }
}

resource "local_file" "kubeconfig" {
  filename = "${dirname(path.root)}/kubeconfigs/${google_container_cluster.sandbox.name}"

  content = <<CONF
apiVersion: v1
kind: Config
preferences: {}

clusters:
- cluster:
    server: https://${google_container_cluster.sandbox.endpoint}
    certificate-authority-data: ${google_container_cluster.sandbox.master_auth[0].cluster_ca_certificate}
  name: ${google_container_cluster.sandbox.name}

users:
- name: admin
  user:
    auth-provider:
      name: gcp
      config:
        cmd-args: config config-helper --format=json
        cmd-path: gcloud
        expiry-key: '{.credential.token_expiry}'
        token-key: '{.credential.access_token}'

contexts:
- context:
    cluster: ${google_container_cluster.sandbox.name}
    user: admin
  name: ${google_container_cluster.sandbox.name}

current-context: ${google_container_cluster.sandbox.name}
CONF
}
