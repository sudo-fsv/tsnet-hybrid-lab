resource "null_resource" "tailscale_cleanup" {
  triggers = {
    tsnet_domain        = var.tsnet_domain
    targets_json        = jsonencode(var.tailscale_cleanup_target_names)
    tailscale_api_key   = var.tailscale_api_key
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -exuo pipefail

      tailnet="${self.triggers.tsnet_domain}"
      apikey="${self.triggers.tailscale_api_key}"
      targets_json='${self.triggers.targets_json}'

      if [ -z "$apikey" ]; then
        echo "No Tailscale API key set; skipping cleanup"
        exit 0
      fi

      if [ "$(echo "$targets_json" | jq 'length')" -eq 0 ]; then
        echo "No cleanup target names provided; skipping to avoid accidental deletions"
        exit 0
      fi

      # Iterate devices and delete those that match any provided tag (or whose name contains the tag substring)
      curl -s "https://api.tailscale.com/api/v2/tailnet/$tailnet/devices" -u "$apikey:" | jq -c '.devices[]' |
      while read -r dev; do
        id=$(echo "$dev" | jq -r .id)
        name=$(echo "$dev" | jq -r .name)

        # Check each configured cleanup target name
        echo "$targets_json" | jq -r '.[]' | while read -r target_name; do
          if [ -z "$target_name" ]; then
            continue
          fi

          # Check device tags (exact match) or name substring match
          if echo "$dev" | jq -e ".tags[]? | select(. == \"$target_name\")" >/dev/null 2>&1 || [[ "$name" == *"$target_name"* ]]; then
            echo "Deleting device: $name ($id) matching target_name '$target_name'"
            curl -s -X DELETE "https://api.tailscale.com/api/v2/device/$id" -u "$apikey:" || true
            break
          fi
        done
      done
    EOT
  }
  depends_on = [
    aws_instance.client_vm,
    aws_instance.tailscale_subnet_router,
    module.eks,
  ]
}
