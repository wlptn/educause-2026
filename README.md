# Educause 2026 Demo: AI-Powered Education on OpenShift (rhdp)

Self-service AI lab environments for students, provisioned by Ansible Automation Platform
on top of **OpenShift AI + Models-as-a-Service (MaaS)**.

> **This is the `rhdp` branch.** It targets a **pre-provisioned Red Hat Demo Platform (RHDP)
> cluster** that already runs OpenShift AI and MaaS on GPU hardware. It does **not** install the
> AI platform — it installs only AAP and layers the Educause demo on top.
>
> For the GPU-free variants that install everything themselves, see the **`homelab`** branch
> (3-node, external MaaS) and the **`sno`** branch (single-node OpenShift).

## What this branch assumes vs. installs

**Already on the cluster (do not re-apply — it is ArgoCD-managed):**

- OpenShift AI 3.2 (DataScienceCluster v2, KServe RawDeployment + Gateway API — no Knative)
- MaaS via Red Hat Connectivity Link (Kuadrant) + Service Mesh 3, serving `qwen3-4b-instruct`
- NVIDIA GPU Operator + NFD (GPU-backed inference)

**This branch installs / configures:**

- Ansible Automation Platform (operator + unified **AnsibleAutomationPlatform**: Gateway + Controller)
- Per-course namespaces, quotas, RBAC, and network policies
- Per-course model access (a `model-config` Secret pointing at the in-cluster MaaS)
- RHOAI Jupyter workbenches per student, pre-loaded with course notebooks

## Prerequisites

- An RHDP cluster with OpenShift AI + MaaS + a GPU node already running (OpenShift 4.20+)
- `oc` logged in as cluster-admin, plus `ansible-core` with the collections in
  `aap/playbooks/collections/requirements.yml`
- A **shared MaaS API key** for the demo (mint one from the MaaS dev portal)
- The cluster's **apps domain** (sandbox-specific — e.g. `apps.ocp.<sandbox>.opentlc.com`)
- A git host the cluster can reach that hosts this repo (see the note under *Model & content*)

Before you start, skim **[docs/rhdp-notes.md](docs/rhdp-notes.md)** — it lists the four things
to verify against your specific cluster.

## Quick Start

### 1. Install AAP

```bash
oc apply -k operators/subscriptions/      # Namespace + OperatorGroup + Subscription (AAP only)
oc get csv -n aap -w                       # wait for the AAP operator to report Succeeded
oc apply -k operators/operator-configs/    # AnsibleAutomationPlatform (Gateway + Controller)
```

Confirm the channel exists first if the operator won't resolve:

```bash
oc get packagemanifest ansible-automation-platform-operator \
  -n openshift-marketplace -o jsonpath='{.status.channels[*].name}{"\n"}'
```

### 2. Configure the AAP Controller

Point the setup playbook at your Controller and cluster. The MaaS endpoint/key/model are
supplied here and injected into jobs via the **MaaS Gateway** credential:

```bash
export CONTROLLER_HOST=https://<aap-gateway-route>   # gateway host aap-aap.<apps-domain>; it proxies the Controller API
export CONTROLLER_USERNAME=admin
export CONTROLLER_PASSWORD=<admin-password>
export GIT_URL=https://github.com
export GIT_USER=wlptn
export CLUSTER_APPS_DOMAIN=apps.ocp.<sandbox>.opentlc.com
export MODEL_ENDPOINT=http://maas.$CLUSTER_APPS_DOMAIN/llm/qwen3-4b-instruct/v1
export MODEL_NAME=qwen3-4b-instruct
export MODEL_API_KEY=<shared-maas-api-key>
export K8S_HOST=https://api.ocp.<sandbox>.opentlc.com:6443
export K8S_BEARER_TOKEN=$(oc whoami -t)

ansible-playbook aap/playbooks/setup-controller.yml
```

This creates the SCM project (synced from this repo's **`rhdp`** branch), the OpenShift and
MaaS credentials, and the **Provision / Teardown Course Environment** job templates with surveys.

### 3. Provision a course

Launch **Provision Course Environment** from the AAP UI (or the Self-Service Portal) and fill in
the survey. The workflow creates the namespace, writes the model-access Secret, and deploys a
Jupyter workbench per student with the selected notebook pack pre-loaded.

## Model & content

- **Model:** `qwen3-4b-instruct`, served in-cluster by OpenShift AI MaaS. Workbenches read
  `MODEL_ENDPOINT` / `MODEL_API_KEY` / `MODEL_NAME` from the `model-config` Secret via `envFrom`,
  so notebooks use the standard `openai` SDK against the cluster-local endpoint. A single shared
  key is used across courses for the demo.
- **Content:** the workbench init container pulls this repo's `rhdp` branch and copies the
  selected `notebooks/<pack>` into each student's workspace.
- **Content source:** the init container, the image BuildConfig, and the AAP SCM project pull
  this repo from public GitHub over anonymous HTTPS (`git_url`/`git_user`/`git_repo` in the
  workbench role; `GIT_URL`/`GIT_USER` for the AAP project). Fork-friendly — point them at your
  own fork if you customize the notebooks.

## Repo Structure

```
operators/           AAP install only (Subscription + AnsibleAutomationPlatform: Gateway + Controller). Kustomize.
maas/                Reference model-config Secret templates (in-cluster MaaS endpoint)
aap/                 AAP portal Helm values, credentials, job templates, Ansible playbooks
  playbooks/         Ansible project synced by AAP Controller from git
    roles/           course-namespace, course-model-access, course-workbenches, course-teardown
workbenches/         Optional custom Jupyter image (Dockerfile + BuildConfig)
notebooks/           Course lab notebooks (pre-loaded into workbenches)
docs/
  rhdp-notes.md              rhdp cluster facts, setup order, must-verify checklist
  plan-primary-maas-cluster.md   Architecture and demo narrative for the MaaS cluster
  portal-install.md         AAP Self-Service Portal install guide
  teardown.md               Teardown guide
```

## Demo Flow

1. Professor opens the self-service portal and selects **Provision Course Environment**
2. AAP runs the workflow: namespace + quotas/RBAC → model-access Secret → student workbenches
3. Students open their Jupyter workbench from the RHOAI dashboard
4. Notebooks are pre-loaded with labs that call `qwen3-4b-instruct` through the cluster's MaaS
5. At course end, the professor runs **Teardown Course Environment**

See **[docs/plan-primary-maas-cluster.md](docs/plan-primary-maas-cluster.md)** for the full
architecture and demo narrative.

## Teardown

Run **Teardown Course Environment** (or `aap/playbooks/teardown.yml`) to delete the course
namespace and everything in it. The shared MaaS key is not per-course, so nothing is revoked.
See **[docs/teardown.md](docs/teardown.md)**.
