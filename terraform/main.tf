resource "multipass_instance" "node" {
  for_each = var.nodes

  name = each.key
  image = var.ubuntu_version
  cpus = each.value.cpus
  memory = each.value.memory
  disk = each.value.disk
}