# k8s-baremetal

A self-managed Kubernetes cluster built from scratch — **no managed service** (no EKS/GKE/AKS). Every layer a cloud normally hides is assembled by hand, one at a time, to understand *why each one exists*.

Provisioned with **Terraform** (IaC) and configured with **Ansible** (CaC) — the whole cluster is reproducible from code, not clicks.

> Learning project. The goal isn't a production cluster — it's to understand the machinery underneath managed Kubernetes by building each piece and hitting the wall each piece solves.

---

## What it builds

Three local VMs on Apple Silicon (via Multipass), wired into a working cluster:

```
                        outside the cluster (host / user)
                                     │
                                     ▼
                       ingress-nginx  (reverse proxy, 1 IP → many apps)
                                     │  external IP from MetalLB
                                     ▼
                         Service  (stable address in front of pods)
                                     │
              ┌──────────────────────┼──────────────────────┐
              ▼                      ▼                       ▼
      ┌──────────────┐      ┌──────────────┐        ┌──────────────┐
      │   node-cp    │      │   node-w1    │        │   node-w2    │
      │ control plane│      │    worker    │        │    worker    │
      │ (etcd, API,  │      │ (kubelet,    │        │ (kubelet,    │
      │  scheduler)  │      │  containerd) │        │  containerd) │
      └──────────────┘      └──────────────┘        └──────────────┘
           Calico CNI provides pod networking + routing across all nodes
       local-path-provisioner provides persistent storage from node disk
```

| Node | Role | Spec |
|------|------|------|
| `node-cp` | control plane | 2 vCPU / 2 GB / 20 GB |
| `node-w1` | worker | 2 vCPU / 2 GB / 20 GB |
| `node-w2` | worker | 2 vCPU / 2 GB / 20 GB |

All nodes: Ubuntu 24.04 (arm64).

---

## Stack

| Layer | Tool | Why this one |
|-------|------|--------------|
| VM engine | Multipass | Native on Apple Silicon (Hypervisor.framework), throwaway Ubuntu VMs |
| IaC — create VMs | Terraform (`larstobi/multipass`) | Declare the VMs as code; reproducible |
| CaC — configure VMs | Ansible | Idempotent node prep across all nodes |
| Cluster bootstrap | kubeadm | Manual assembly of each layer (not k3s/Talos — those hide it) |
| Container runtime | containerd | What Kubernetes actually talks to (CRI); the core Docker itself uses |
| Pod networking (CNI) | Calico | Pod IPs + cross-node routing; no cloud VPC CNI on bare metal |
| Load balancer | MetalLB (L2 mode) | `type: LoadBalancer` stays `<pending>` on bare metal — MetalLB answers it |
| Ingress | ingress-nginx | One entry point, route by host/path instead of one IP per app |
| Storage | local-path-provisioner | No cloud disks (EBS) to auto-provision PVs; backs volumes with node disk |

---

## The build, and why each layer exists

Each layer is motivated by the problem the previous one exposes — that's the whole point of doing it by hand:

1. **Provision** 3 VMs with Terraform → 3 bare Ubuntu machines.
2. **Prep nodes** with Ansible → container runtime, kernel networking prereqs, kube tools.
3. **`kubeadm init`** → control plane comes up, but the node is `NotReady`... because pods have no network yet.
4. **Calico (CNI)** → pods get IPs and can talk across nodes → node goes `Ready`.
5. **`kubeadm join`** → workers join → a real 3-node cluster.
6. **Deploy an app, expose `type: LoadBalancer`** → it hangs at `<pending>`, because there's no cloud to hand out an external IP. *This is the bare-metal wall.*
7. **MetalLB** → assigns a real external IP from a local pool → the wall breaks.
8. **ingress-nginx** → one IP fronts many apps, routed by URL, instead of one IP per service.
9. **local-path-provisioner** → PersistentVolumeClaims bind to real storage → stateful apps (databases) can run.

---

## Repo structure

```
terraform/          # IaC — VM definitions
  versions.tf         provider (multipass)
  variables.tf        node specs (map + for_each)
  main.tf             the VMs
  outputs.tf          node IPs
  cloud-init.yaml     SSH key injection at first boot

ansible/            # CaC — node config + cluster addons
  inventory.ini       the 3 nodes, grouped by role
  site.yml            entry point (one play per role)
  roles/
    common/           all nodes: containerd, kernel, kubeadm/kubelet/kubectl
    control_plane/    node-cp: kubeadm init, kubeconfig, CNI, join-token
    worker/           workers: kubeadm join
    metallb/          load balancer + address pool
    ingress/          ingress-nginx controller
    storage/          local-path-provisioner (default StorageClass)
```

---

## Reproduce

Prerequisites: macOS (Apple Silicon), [Multipass](https://multipass.run/), Terraform, Ansible.

```bash
# 1. Create the VMs
cd terraform
terraform init
terraform apply        # writes node IPs to outputs

# 2. Put the node IPs in ansible/inventory.ini, then build the cluster
cd ../ansible
ansible-playbook site.yml

# 3. Verify
multipass exec node-cp -- kubectl get nodes
```

---

## Status

- **Infrastructure: complete** — all 9 layers above, fully driven by Terraform + Ansible.
- **Next:** deploy a real 3-tier app (frontend + backend + database) onto the cluster, then expose it publicly via a Cloudflare Tunnel.
- **Stretch:** HA control plane (3 control-plane nodes for etcd/Raft quorum).

---

## What this taught me

- Managed Kubernetes hides a *lot*: certificates and an internal CA, pod networking, load balancing, storage provisioning — each is a real subsystem you otherwise never see.
- "Bare metal" is a networking problem as much as a Kubernetes one: no cloud LB, no cloud disks, so you supply MetalLB and a storage provisioner yourself.
- Doing it by hand once makes the abstractions readable instead of magic.
