locals {
  tailscale_acl = {
    ACLs = [
      {
        Action = "accept"
        Users  = ["*"]
        Ports  = ["tag:home-lab:*", "tag:aws-environment:*"]
      }
    ]

    # Default grants: allow all connections by default (can be tightened later)
    grants = [
      {
        src = ["*"]
        dst = ["*"]
        ip  = ["*"]
      }
    ]

    # SSH rules: allow members to SSH into their own devices (check mode)
    ssh = [
      {
        action = "check"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = ["autogroup:nonroot", "root"]
      },
      {
        "src":    ["tag:home-lab"],
			  "dst":    ["tag:aws-environment"],
			  "users":  ["root"],
			  "action": "accept",
  }
    ]

	"tagOwners": {
		"tag:aws-environment":   ["autogroup:it-admin", "tag:k8s-operator"],
		"tag:k8s-operator":      ["autogroup:admin", "tag:k8s-operator"],
    "tag:k8s-subnet-router": ["autogroup:admin", "tag:k8s-operator"],
		"tag:k8s":               ["autogroup:admin", "tag:k8s-operator"],
		"tag:home-lab":          ["autogroup:admin"],
	  }
  }
}

# Note: the Tailscale Terraform provider applies ACLs as a single policy document.
resource "tailscale_acl" "lab_acl" {
  acl = jsonencode(local.tailscale_acl)
}

# Tag all Tailscale devices with custom tags for easier identification and access control.
data "tailscale_device" "aws-linux-vm" {
  name = "aws-linux-vm.${var.tsnet_domain}"
  wait_for = "120s"
  depends_on = [aws_instance.client_vm]
}

resource "tailscale_device_tags" "aws-linux-vm" {
  device_id = data.tailscale_device.aws-linux-vm.node_id
  tags      = ["tag:aws-environment"]
}

data "tailscale_device" "tailscale-subnet-router" {
  name = "tailscale-subnet-router.${var.tsnet_domain}"
  wait_for = "120s"
  depends_on = [aws_instance.tailscale_subnet_router]
}

resource "tailscale_device_tags" "tailscale-subnet-router" {
  device_id = data.tailscale_device.tailscale-subnet-router.node_id
  tags      = ["tag:aws-environment", "tag:k8s-subnet-router"]
}

