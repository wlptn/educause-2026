# rhdp branch — cloud cluster notes

The `rhdp` branch targets a **pre-provisioned Red Hat Demo Platform (RHDP) cluster** that
already runs OpenShift AI + MaaS on GPU hardware. Unlike the `homelab`/`sno` branches, it does
**not** install the AI platform — it layers the Educause demo (course namespaces, model access,
workbenches) on top and installs **only AAP**.

## Target cluster (verified from a live audit)
- OpenShift **4.20.0** on AWS. Apps domain is **sandbox-specific** (e.g.
  `apps.ocp.CHANGEME.opentlc.com`) and **changes on every reprovision** — always pass
  it in via `CLUSTER_APPS_DOMAIN` (extra var / survey), never rely on a baked default.
- 1 GPU worker: **NVIDIA L40S** (GPU Operator 25.3.4 + NFD). Students do **not** need local
  GPUs — inference is central via MaaS, so course namespaces get CPU/memory quota only.
- **OpenShift AI 3.2.0** (channel `fast-3.x`), DataScienceCluster **v2**, KServe **RawDeployment
  + Gateway API** (no Knative/Serverless). Platform is **ArgoCD-managed** — do not re-apply it.
- MaaS = **Red Hat Connectivity Link (Kuadrant) 1.3.4** + Service Mesh 3 + Keycloak, in
  `kuadrant-system` / `maas-api`.

## Model access (shared-key approach)
- Model served: **`qwen3-4b-instruct`** (`LLMInferenceService` in ns `llm`).
- Gateway base URL: `http://maas.<apps-domain>/llm/qwen3-4b-instruct`
  (OpenAI clients use this + `/v1`).
- The demo uses **one shared MaaS API key** for all courses. `course-model-access` writes
  `MODEL_ENDPOINT` / `MODEL_API_KEY` / `MODEL_NAME` into a `model-config` Secret per course;
  the workbench reads them via `envFrom`. The authoritative values are injected by the AAP
  **"MaaS Gateway"** credential (created by `setup-controller.yml`).

## What this branch installs vs assumes
- **Installs:** AAP operator only — `operators/subscriptions/` (Namespace + OperatorGroup +
  Subscription) and `operators/operator-configs/ansible-automation-platform.yaml` — the unified **AnsibleAutomationPlatform** CR (Gateway + Controller; Hub/EDA/Lightspeed disabled). The self-service Portal (docs/portal-install.md) needs the Platform **Gateway** for OAuth apps / API tokens, so a standalone controller is not enough. Gateway route `aap` → `aap-aap.<apps-domain>`; admin login in secret `aap-admin-password` (user `admin`).
- **Assumes present (do not apply):** RHOAI/DSC, Serverless (n/a), Service Mesh, Connectivity
  Link, GPU stack — all already installed and ArgoCD-owned.

## ⚠️ Must verify before the demo
1. **Exact model endpoint.** Open the OpenShift AI dashboard → *AI asset endpoints* →
   *Models as a service* → `qwen3-4b-instruct` → **External endpoint → View**, and confirm the
   base URL + whether the OpenAI path is `.../qwen3-4b-instruct` or `.../qwen3-4b-instruct/v1`.
   Then `curl` `<base>/v1/models` (or `/models`) with the shared key to confirm it answers.
2. **Shared MaaS key.** Obtain/mint a key from the MaaS dev portal; pass it as `MODEL_API_KEY`
   into the AAP MaaS credential. Never commit it.
3. **Content repo.** The workbench init container, the image BuildConfig, and the AAP SCM
   project pull this repo from public GitHub
   (`https://github.com/wlptn/educause-2026`, `rhdp` branch) over anonymous HTTPS — reachable
   from any RHDP cluster. For a private fork, add a Source Control credential + BuildConfig secret.
4. **AAP channel.** Confirm `stable-2.7` is offered:
   `oc get packagemanifest ansible-automation-platform-operator -n openshift-marketplace -o jsonpath='{.status.channels[*].name}{"\n"}'`
   and adjust `operators/subscriptions/aap-subscription.yaml` if not.

## Suggested setup order
1. `oc apply -k operators/subscriptions/`  → wait for AAP CSV `Succeeded`
2. `oc apply -k operators/operator-configs/`  → AnsibleAutomationPlatform (Gateway + Controller) comes up (~10–15 min)
3. Set env (`CONTROLLER_*`, `GIT_URL`/`GIT_USER`, `MODEL_ENDPOINT/KEY/NAME`, `CLUSTER_APPS_DOMAIN`, `K8S_*`)
   then `ansible-playbook aap/playbooks/setup-controller.yml`
4. Launch **Provision Course Environment** from AAP.
