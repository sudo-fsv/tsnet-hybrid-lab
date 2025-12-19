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
      }
    ]

	"tagOwners": {
		"tag:aws-environment": ["autogroup:it-admin", "tag:k8s-operator"],
		"tag:k8s-operator":    ["autogroup:admin", "tag:k8s-operator"],
		"tag:k8s":             ["autogroup:admin", "tag:k8s-operator"],
		"tag:home-lab":        ["autogroup:admin"],
	}
  }
}

# Optional: Terraform also supports an `import` block (Terraform 1.5+) which can
# be included in configuration to declare an import to be performed during
# apply. Uncomment and set the proper id if you prefer that method:
data "tailscale_acl" "lab_acl" {}

import {
  to = tailscale_acl.lab_acl
  id = data.tailscale_acl.lab_acl.id
}

# Note: the Tailscale Terraform provider applies ACLs as a single policy document.
resource "tailscale_acl" "lab_acl" {
  acl = jsonencode(local.tailscale_acl)
}


