# Deploying on a fresh RHDP sandbox

End-to-end runbook for standing up the self-service AI lab demo on a fresh Red Hat Demo
Platform (RHDP) cluster that already provides OpenShift AI + Models-as-a-Service (MaaS) +
GPU. It installs Ansible Automation Platform, the self-service portal, and the course
provisioning automation on top.

## Prerequisites
- An RHDP OpenShift cluster with OpenShift AI (RHOAI), MaaS serving `qwen3-4b-instruct`, and a
  schedulable GPU node. (These are ArgoCD-managed on the sandbox — do not rebuild them.)
- `oc` logged in as cluster-admin, `helm` 3.10+, `ansible-playbook` with the `ansible.controller`
  collection, and a MaaS API key (mint from the MaaS dev portal).

## Values you need (per sandbox)
See the environment-variable table in the [README](../README.md#environment-variables-setup-controlleryml).
The only value that varies structurally is your cluster's apps domain
(`apps.ocp.<sandbox>.opentlc.com`); most other values derive from it. Stable defaults that do
NOT normally change between same-blueprint sandboxes: AAP channel `stable-2.7`, portal chart
`redhat-rhaap-portal` `2.2.7`, and the workbench image
`image-registry.openshift-image-registry.svc:5000/redhat-ods-applications/s2i-minimal-notebook:2025.2`.

## Steps

### 1. Install AAP (operator + unified platform)
```bash
oc apply -k operators/subscriptions/       # AAP operator (channel stable-2.7)
oc get csv -n aap -w                        # wait for Succeeded
oc apply -k operators/operator-configs/     # AnsibleAutomationPlatform (Gateway + Controller)
```
Wait until `oc get ansibleautomationplatform aap -n aap` reports `Successful=True` (~10–20 min).
Gateway URL is the `aap` route (`aap-aap.<apps-domain>`); admin password:
```bash
oc get secret aap-admin-password -n aap -o jsonpath='{.data.password}' | base64 -d; echo
```

### 2. Deploy Mailpit (captures provisioning emails)
The provisioning playbook sends welcome emails to `mailpit-smtp.mailpit.svc:1025`.
Optionally set the route host to your apps domain in `infra/mailpit/deployment.yaml` (the SMTP
service works regardless — the route is only for the inbox UI), then apply:
```bash
oc apply -k infra/mailpit/
```
The inbox UI is the `mailpit` route in the `mailpit` namespace.

### 3. Install the self-service portal
Follow [docs/portal-install.md](portal-install.md). In short: in the AAP gateway create an OAuth
application (Authorization code, Confidential, **PKCE off**, organization `Default`) and an API
token (scope Write), enable external OAuth token creation, then create the `aap-portal` project,
its secrets, and `helm install redhat-rhaap-portal openshift-helm-charts/redhat-rhaap-portal
--version 2.2.7 -n aap-portal -f aap/helm-values-portal.yaml` (set your apps domain in the values
first). Finish by setting the OAuth redirect URI to the portal route's
`/api/auth/rhaap/handler/frame`.

### 4. Configure the AAP Controller
Export the environment variables (see the README table) and run:
```bash
ansible-playbook aap/playbooks/setup-controller.yml
```
Authentication uses a gateway API token via `CONTROLLER_OAUTH_TOKEN` — username/password does not
work behind the 2.5+ platform gateway. Create the token in the gateway under **Access Management ->
API Tokens -> Create API Token** (leave Application blank for a personal token, scope **Write**), then
`export CONTROLLER_OAUTH_TOKEN=<token>`. Note this is a *personal API token* and is NOT the same as the
portal's OAuth *application* (step 3) — different place, different purpose. This creates the project,
credentials, the Demo Inventory,
and the **Provision / Teardown Course Environment** job templates (with the course dropdown).

### 5. Provision a course
Launch **Provision Course Environment** from the portal (or the AAP UI), pick a course offering,
and set the student count and duration. It creates the course namespace, the model-access Secret,
and a per-student Jupyter workbench with the selected notebook pack, then emails access links.

Workbenches are reached through the OpenShift AI **data-science-gateway** at
`https://data-science-gateway.<apps-domain>/notebook/<namespace>/<name>/`.

## Troubleshooting
- **`setup-controller` "Failed to get token: 404"** — use `CONTROLLER_OAUTH_TOKEN` (gateway API
  token, Write scope), not username/password; `CONTROLLER_HOST` is the gateway URL.
- **Workbench shows "notebook image deleted" / dashboard can't resolve the image** — the RHOAI
  webhook requires the workbench container name to equal the Notebook name; the role sets this and
  the `notebooks.opendatahub.io/last-image-selection` annotation.
- **Workbench 500 at the data-science-gateway** — the image needs
  `--ServerApp.base_url=/notebook/<ns>/<name>` in `NOTEBOOK_ARGS` (it does not self-apply
  `NB_PREFIX`); use annotation `inject-auth` (not `inject-oauth`) and a hardware profile.
- **`ModuleNotFoundError: openai`** — the stock minimal image ships without it; the notebooks
  include a one-time `%pip install` cell. For a zero-setup experience, build the custom image under
  `workbenches/` with the packages preinstalled and point `workbench_images.jupyter` at it.
- **MaaS `503` / model not ready** — KServe serverless scale-to-zero and/or the GPU node is
  NotReady. Confirm `oc get llmisvc -n llm` is `Ready` and the GPU node schedules, and pre-warm the
  model with one call before demoing.
- **URLs in emails show a placeholder domain** — the job template passes `cluster_domain` as an
  extra var from `CLUSTER_APPS_DOMAIN`; the job pod does not inherit your shell environment.

## Roadmap: making this fully turnkey
Planned improvements: a root `.env.example` for all per-sandbox values, a single `install.sh`/
Makefile driver that stamps the domain and runs steps 1–4, a `preflight` check (including MaaS
model-ready + GPU-node-schedulable), and automation of the portal OAuth-app + Helm install.
