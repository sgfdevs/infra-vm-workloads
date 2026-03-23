data "proxmox_virtual_environment_nodes" "available" {}

resource "terraform_data" "proxmox_connectivity_check" {
  input = {
    endpoint   = var.proxmox_endpoint
    node_names = data.proxmox_virtual_environment_nodes.available.names
  }

  lifecycle {
    precondition {
      condition     = length(data.proxmox_virtual_environment_nodes.available.names) > 0
      error_message = "No Proxmox nodes were returned from the API. Verify provider credentials and endpoint reachability."
    }

    precondition {
      condition     = length(var.expected_node_names) == 0 || length(setsubtract(toset(var.expected_node_names), toset(data.proxmox_virtual_environment_nodes.available.names))) == 0
      error_message = "Expected Proxmox node names are missing from API response."
    }
  }
}
