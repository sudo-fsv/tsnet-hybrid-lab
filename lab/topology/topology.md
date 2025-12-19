# Lab Topology

This directory contains a Graphviz DOT file (`topology.dot`) that describes the lab topology.

Key elements:

- Two VPCs in `us-west-2`:
  - `server` VPC (10.10.0.0/16): hosts an EKS cluster (control plane + managed node group) in private subnets, a `hello` deployment/service, and the Tailscale Operator installed via Helm.
  - `client` VPC (10.20.0.0/16): simplified to a single public subnet (no NAT gateway). The Ubuntu VM lives in the public subnet and has a public IP for bootstrap; it runs the Tailscale client.
  - Optional Tailscale subnet-router is now placed in the `server` public subnet (and will have its own public IP) to advertise EKS cluster service/pod CIDRs into Tailscale.
  - There is no VPC peering connection in this simplified design; cross-environment connectivity is expected to be provided by the Tailscale overlay network and subnet-router.


Open `topology.png` to view the diagram. You can also render SVG:

```bash
dot -Tsvg topology.dot -o topology.svg
```

If you'd like, I can also:

- Add a PlantUML version for easier editing in Markdown-aware renderers.
- Generate an embedded PNG and add it to the repo.
- Produce a more detailed per-subnet connectivity table.

Render the diagram (requires Graphviz `dot`):

```bash
cd terraform/lab
dot -Tpng topology.dot -o topology.png
```

Or render SVG instead of PNG:

```bash
dot -Tsvg topology.dot -o topology.svg
```

Rendered PNG

The diagram has been rendered to `topology.png` and is embedded below for quick viewing.

![Lab Topology](topology.png)
