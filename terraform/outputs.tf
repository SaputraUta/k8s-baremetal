output "node_ips" {
  description = "IPv4 of each node"
  value = {
    for name, inst in multipass_instance.node:
    name => inst.ipv4
  }
}