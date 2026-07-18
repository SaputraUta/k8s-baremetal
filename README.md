# k8s-baremetal

Self-managed Kubernetes cluster built from scratch — no managed service (no EKS/GKE/AKS). Every layer that a cloud usually abstracts away is assembled by hand to understand *why* each one exists.

## Goal

Bootstrap a 3-node Kubernetes cluster on local VMs and wire up, one layer at a time:

- **Container runtime** — containerd
- **Cluster bootstrap** — kubeadm
- **Pod networking (CNI)** — Calico
- **Load balancer** — MetalLB (bare metal has no cloud LB)
- **Ingress** — ingress-nginx
- **Storage** — local-path-provisioner

## Stack

| Layer | Tool | Why |
|---|---|---|
| VM engine | Multipass | Native on Apple Silicon (Hypervisor.framework), throwaway Ubuntu VMs |
| IaC (create VMs) | Terraform (`larstobi/multipass`) | Declare the 3 VMs as code |
| CaC (configure VMs) | Ansible | Idempotent node prep across all nodes |
| Cluster | kubeadm | Manual assembly of each layer (not k3s/Talos — those hide it) |

## Layout

```
terraform/   # IaC — VM definitions
ansible/     # CaC — node prep playbooks
```

## Nodes

| Node | Role | Spec |
|---|---|---|
| node-cp | control plane | 2 vCPU / 2 GB / 20 GB |
| node-w1 | worker | 2 vCPU / 2 GB / 20 GB |
| node-w2 | worker | 2 vCPU / 2 GB / 20 GB |
