---
name: Educause Homelab Variant
overview: A GPU-free homelab version of the Educause demo running on a 3-node OpenShift 4.20 cluster, using external MaaS endpoints for inference, AAP Self-Service Portal as the professor frontend, and RHOAI workbenches (Jupyter, RStudio, MATLAB) for student environments.
todos:
  - id: operator-manifests
    content: Create Subscription YAML manifests for all required operators (RHOAI, AAP, Serverless, Service Mesh, Connectivity Link)
    status: pending
  - id: maas-external
    content: Configure RHOAI MaaS gateway with ExternalModel CR pointing to Red Hat-hosted inference endpoint
    status: pending
  - id: aap-portal
    content: Deploy AAP Self-Service Portal via Helm, configure sync with Controller job templates
    status: pending
  - id: ansible-playbooks
    content: "Build Ansible roles: course-namespace, course-model-access, course-workbenches, course-teardown"
    status: pending
  - id: workbench-image
    content: Build custom Jupyter workbench image with education libraries and course notebooks
    status: pending
  - id: rstudio-future
    content: (Future) Build RStudio Server workbench image via RHOAI BuildConfig
    status: pending
  - id: matlab-future
    content: (Future) Deploy MATLAB via Helm chart or custom workbench image with license config
    status: pending
isProject: false
---

# Educause Demo: Homelab Variant (No GPU)

## Constraints and Approach

- **Cluster:** 3-node OpenShift 4.22 (no GPUs)
- **Git:** Local Gitea server (all manifests, playbooks, and notebooks stored here)
- **Model inference:** External MaaS endpoints via RHOAI ExternalModel routing (Red Hat-hosted or other provider)
- **Frontend:** AAP Self-Service Automation Portal (Ansible Automation Catalog)
- **Student environments:** RHOAI Workbenches (Jupyter now; RStudio and MATLAB later)
- **Philosophy:** Keep it simple — operator installs via manifests, minimal custom code

This variant tells the same demo story as the primary plan but proves you don't need local GPUs to demonstrate the platform value. The automation, governance, and student experience are identical — only the inference backend changes.

All manifests, Ansible playbooks, workbench images, and course notebooks are version-controlled in the local Gitea server. AAP Controller syncs playbooks from Gitea via SCM credential, and workbench images can be built from Gitea-hosted Dockerfiles via OpenShift BuildConfigs.

---

## Architecture

```
Professor
    |
    v
AAP Self-Service Portal  (Helm chart on OCP)
    |  (guided form, submits job)
    v
AAP Controller  (operator on OCP)
    |-- Workflow Job Template --
    |                          |
    v                          v
OpenShift API               OpenShift AI (RHOAI)
  - Namespace                 - MaaS Gateway
  - Quotas/RBAC               - ExternalModel CR --> Red Hat hosted endpoint
  - NetworkPolicy              - Jupyter Workbenches
  - Routes/Ingress             - (future: RStudio, MATLAB)
```

Key insight: The MaaS gateway on your cluster acts as a local proxy. Students and notebooks hit a cluster-local URL (`https://maas.apps.yourcluster/llm/granite/v1/chat/completions`) with API keys managed by RHOAI, but the actual inference is routed to Red Hat's external endpoint. From the student's perspective, it looks exactly the same as a GPU-backed local deployment.

---

## Operators to Install

All installed via `Subscription` manifests (OperatorHub):

| Operator | Purpose | Namespace |
|----------|---------|-----------|
| Red Hat OpenShift AI (RHOAI) | Model serving gateway, workbenches, dashboard | redhat-ods-operator |
| Ansible Automation Platform | Controller, EDA, portal foundation | aap |
| OpenShift Serverless (Knative) | Required by KServe/MaaS gateway | openshift-serverless |
| Red Hat Connectivity Link (Kuadrant) | MaaS API gateway, rate limiting, auth | connectivity-link-operator |
| Service Mesh (Istio) | Required by KServe and Connectivity Link | istio-system |

**Not needed (no GPU):** NVIDIA GPU Operator, Node Feature Discovery

---

## Components to Deploy

### 1. OpenShift AI MaaS with External Model

Instead of deploying a local vLLM InferenceService, configure an `ExternalModel` CR that routes to Red Hat's hosted inference endpoint:

```yaml
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSModelRef
metadata:
  name: granite-3-8b
  namespace: redhat-ods-applications
spec:
  externalModel:
    name: granite-3-8b-instruct
    provider: redhat-hosted
    endpoint: "https://<red-hat-maas-endpoint>/v1"
    apiKeySecret:
      name: rh-maas-api-key
      key: token
```

Then create `MaaSSubscription` CRs to grant per-course/per-department access with token rate limits.

### 2. AAP Self-Service Automation Portal

Deployed via Helm chart on the cluster. Configuration:
- Syncs job templates from the AAP Controller
- Filters to only show education-tagged templates (`labels: ["self-service", "education"]`)
- Maps RBAC so professors see "Provision Course Environment" and "Teardown Course" templates
- Students see nothing (they only interact with their workbench)

Helm values (key sections):

```yaml
catalog:
  providers:
    rhaap:
      baseUrl: "https://aap-controller.apps.yourcluster"
      organization: "University"
      sync:
        jobTemplates:
          enabled: true
          surveyEnabled: true
          labels: ["self-service"]
```

### 3. AAP Controller + Playbooks

Same Ansible playbooks as the primary plan, minus the local model deployment step:

- `course-namespace` — create project, apply quotas, RBAC
- `course-model-access` — create MaaSSubscription CR, generate scoped API keys for the course
- `course-workbenches` — deploy RHOAI Jupyter workbenches per course with pre-loaded notebooks
- `course-teardown` — delete namespace, revoke API keys, cleanup

Workflow Job Template with Survey variables:
- Course name, course code
- Number of students
- Semester start/end dates
- Workbench type (Jupyter / RStudio / MATLAB)
- Model tier (standard / high-throughput)

### 4. RHOAI Jupyter Workbenches

Custom workbench image with education libraries pre-installed:
- `openai` (Python SDK for MaaS endpoint)
- `langchain`, `langchain-openai`
- `httpx`, `requests`
- `pandas`, `numpy`, `matplotlib` (standard data science)
- Course notebooks pre-loaded via PVC or git clone on startup

---

## Future Additions (RStudio and MATLAB)

### RStudio Server Workbench

Already supported as a workbench type in RHOAI (Technology Preview):

1. Create subscription-manager secret for RHEL builds
2. Trigger BuildConfig: `oc start-build rstudio-server-rhel9 -n redhat-ods-applications`
3. Label ImageStream: `oc label imagestream rstudio-rhel9 opendatahub.io/notebook-image='true' -n redhat-ods-applications`
4. RStudio appears as a workbench option in the RHOAI dashboard

Ansible can then provision RStudio workbenches for statistics/biostatistics courses the same way it provisions Jupyter.

### MATLAB

No native operator, but MathWorks provides:
- Official Docker container images (`containers.mathworks.com/matlab:r2025b`) with browser-based access
- Helm charts for MATLAB Production Server and Parallel Server
- MATLAB Parallel Server supports Kubernetes scheduling

Approach: Create a custom RHOAI workbench image based on the MathWorks container, or deploy MATLAB as a standalone Helm release per course. The Ansible playbook would add a `matlab-workbench` role alongside the existing `jupyter-workbench` role.

**Note:** MATLAB requires a license (concurrent license via network license manager). The university likely already has one — the Ansible playbook would configure the license server connection.

---

## Manifest-Based Deployment Strategy

All configuration lives as declarative YAML in a Gitea repo (`educause-demo`):

```
educause-demo/           (hosted on local Gitea server)
  operators/
    subscriptions/
      rhoai-subscription.yaml
      aap-subscription.yaml
      serverless-subscription.yaml
      service-mesh-subscription.yaml
      connectivity-link-subscription.yaml
    operator-configs/
      datasciencecluster.yaml
      automationcontroller.yaml
  maas/
    external-model-granite.yaml
    maas-tenant.yaml
    maas-subscription-template.yaml
  aap/
    helm-values-portal.yaml
    credentials/
      gitea-scm-credential.yaml
    job-templates/
      provision-course.yaml
      teardown-course.yaml
    playbooks/
      roles/
        course-namespace/
        course-model-access/
        course-workbenches/
        course-teardown/
  workbenches/
    custom-notebook-image.yaml
    Dockerfile.jupyter-edu
    rstudio-build.yaml       (future)
    matlab-helm-values.yaml  (future)
  notebooks/
    lab-01-first-llm-call.ipynb
    lab-02-comparing-models.ipynb
    lab-03-building-an-agent.ipynb
```

Apply operators: `oc apply -k operators/subscriptions/`
Configure: `oc apply -k operators/operator-configs/`
Deploy AAP Portal: `helm install aap-portal ... -f aap/helm-values-portal.yaml`

AAP Controller project syncs playbooks from: `https://gitea.yourlab/org/educause-demo.git`
Workbench BuildConfig sources Dockerfile from: `https://gitea.yourlab/org/educause-demo.git#main:workbenches/`

---

## Build Timeline (3 weeks)

### Week 1: Operators and MaaS Gateway
- Apply operator Subscription manifests (RHOAI, AAP, Serverless, Service Mesh, Connectivity Link)
- Wait for operators to reconcile
- Configure DataScienceCluster CR
- Configure MaaS gateway with ExternalModel CR pointing to Red Hat endpoint
- Validate: `curl` the local MaaS endpoint, confirm inference works through the proxy
- Install AAP Controller, create initial admin user and Organization

### Week 2: Automation Portal + Playbooks
- Deploy AAP Self-Service Portal via Helm
- Build Ansible playbooks (namespace, RBAC, quotas, workbench provisioning, API key generation)
- Create Workflow Job Template with Survey
- Configure portal sync (label templates, map RBAC)
- Build custom Jupyter workbench image with course libraries
- Write course notebooks (2-3 labs)
- End-to-end test: portal form -> AAP workflow -> namespace + workbench + model access created

### Week 3: Polish and Rehearsal
- Create demo users (professor, students)
- Rehearse full demo flow 3+ times
- Record fallback video
- Prep talking points and architecture slides
- Document the git repo structure for reproducibility

---

## Differences from Primary Plan (MaaS Workshop Cluster)

| Aspect | Primary (MaaS cluster) | Homelab (this plan) |
|--------|----------------------|---------------------|
| GPU | Local GPU nodes | None — external inference |
| Model serving | Local vLLM InferenceService | ExternalModel CR routing to Red Hat endpoint |
| Self-service frontend | AAP Survey form (or custom app) | AAP Self-Service Portal (richer UX) |
| Base infrastructure | Mostly pre-built | You install everything from manifests (git-tracked in Gitea) |
| Model latency | Low (on-cluster) | Higher (network hop to external) |
| Cost | GPU time | External API usage (likely free for SA demos) |
| Reproducibility | Tied to RHPDS environment | Fully portable git repo in Gitea — clone and apply anywhere |

---

## Demo Narrative Adjustment

The homelab version actually tells a **stronger** story for many universities:

"Not every institution can afford a rack of A100s. With OpenShift AI's MaaS gateway, you can start with external model endpoints today — same self-service experience, same governance, same automation. When you're ready to bring GPUs on-prem, you swap the ExternalModel for a local InferenceService. The student experience doesn't change. The Ansible automation doesn't change. You just flip the backend."

This is a compelling hybrid/growth story for budget-conscious education IT leaders.

---

## Open Questions

- **Which Red Hat-hosted endpoint to use?** Need to confirm what's available to SAs for demos (internal Red Hat AI inference service, or a partner endpoint)
- **AAP version:** AAP 2.7 is already installed on the cluster. Confirm Self-Service Portal availability.
- **Connectivity Link maturity:** This is newer — may need to check if MaaS gateway works without GPUs on the cluster (the docs assume at least one local model, but ExternalModel-only should work)
- **MATLAB licensing:** For future work, confirm the university has a network license manager accessible from the cluster