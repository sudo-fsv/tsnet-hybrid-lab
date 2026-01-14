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
		"tag:aws-environment":   ["autogroup:admin", "tag:k8s-operator"],
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
  overwrite_existing_content = true
}

# Device tagging is handled at instance bootstrap via the Tailscale CLI.

