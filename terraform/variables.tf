variable "ubuntu_version" {
    description = "Ubuntu image version for all nodes"
    type = string
    default = "24.04"
}

variable "nodes" {
  description = "VMs to create, keyed by node name"
  type = map(object({
    cpus = number
    memory = string
    disk = string
  }))
  default = {
    "node-cp" = {
      cpus = 2, memory = "2G", disk = "20G"
    }
    "node-w1" = {
      cpus = 2, memory = "2G", disk = "20G"
    }
    "node-w2" = {
      cpus = 2, memory = "2G", disk = "20G"
    }
  }
}