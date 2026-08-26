---
name: Educause Demo Plan
overview: Build an "AI Course Lab Platform" demo for Educause on top of the existing OpenShift AI MaaS workshop cluster, adding AAP automation, Jupyter workbenches, and Granite model serving to tell an education-specific provisioning story.
todos:
  - id: aap-install
    content: "Week 1: Install AAP operator on existing MaaS cluster, configure controller, connect to OpenShift API"
    status: pending
  - id: ansible-playbooks
    content: "Week 1: Build Ansible playbooks - namespace creation, RBAC, quotas, RHOAI workbench provisioning, model access token generation"
    status: pending
  - id: granite-model
    content: "Week 1: Deploy Granite 3.1 8B alongside existing Llama model on the MaaS cluster"
    status: pending
  - id: jupyter-workbenches
    content: "Week 2: Configure RHOAI Jupyter workbenches with education-specific image (langchain, openai SDK, course notebooks)"
    status: pending
  - id: workflow-template
    content: "Week 2: Create AAP Workflow Job Template chaining provisioning steps, build self-service trigger (Survey form or web app)"
    status: pending
  - id: course-notebooks
    content: "Week 2: Write 2-3 polished course notebooks demonstrating LLM calls, agentic workflows, and model comparison"
    status: pending
  - id: rehearsal
    content: "Week 3: End-to-end dry runs, pre-warming, fallback recordings, Educause talking points"
    status: pending
isProject: false
---

# Educause Demo: AI Course Lab Platform

## Base Environment (Already Provisioned)

Building on the **OpenShift AI MaaS Workshop** cluster which provides:

- OpenShift 4.20 with GPU nodes and NVIDIA GPU Operator
- OpenShift AI 3.0 operator, fully configured
- MaaS architecture with API gateway and token-based access control
- Llama model deployed and serving via Llama Stack
- MCP server integration (agentic AI capabilities)
- Grafana dashboards for usage analytics (tokens, cost, capacity)
- OpenShift Dev Spaces (available but not used in our demo)
- Multi-persona RBAC already configured

**What we are NOT rebuilding:** Model serving infrastructure, GPU operator, monitoring stack, base RHOAI configuration. These are done.

---

## What We Add on Top

| Component | Purpose | Effort |
|-----------|---------|--------|
| Ansible Automation Platform (operator) | Provisioning automation, the "how" story | Medium |
| Granite 3.1 8B model serving | Red Hat's own model alongside Llama | Low-Medium |
| RHOAI Jupyter Workbenches | Student-facing notebook environments | Low |
| AAP Workflow Job Template | Orchestrates the full provisioning flow | Medium |
| Self-service trigger | Professor-facing request form | Low |
| Course notebooks | Pre-built student lab exercises | Low |
| Education-framed Grafana dashboards | Per-course/department usage view | Low |

---

## Demo Narrative

**The Story:** Dr. Martinez teaches "Introduction to Generative AI and Agentic Development" to 40 graduate students. She needs each student to have a Jupyter notebook environment with access to LLM endpoints for their coursework. Instead of submitting a ticket and waiting 3 weeks, she uses a self-service portal backed by OpenShift AI and Ansible Automation Platform.

**The Punchline for IT Leaders:** "You just saw one platform serve models, provision 40 isolated student environments with GPU quotas, and tear them down at semester end — all governed by policy, all automated, all on infrastructure you control."

---

## Demo Flow (10-12 minutes live)

### Act 1: The Request (1-2 min)
- Show a self-service form (AAP Survey form or lightweight web app)
- Professor selects: course name, number of students, semester dates, model preference (Granite or Llama), GPU tier
- Submit triggers an Ansible Automation Platform workflow

### Act 2: The Automation (3-4 min)
- Switch to AAP Controller UI — show the workflow job executing in real time
- The workflow:
  1. Creates an OpenShift namespace/project for the course (`cs595-genai-fall26`)
  2. Applies resource quotas and RBAC (students get limited access, professor gets admin)
  3. Generates MaaS API tokens scoped to the course's model allocation
  4. Provisions RHOAI Jupyter workbenches with per-student persistent volumes and course notebooks pre-loaded
  5. Configures network policies and ingress routes
  6. Sends notification to professor with access URLs and credentials
- Narrate each step as it runs — audience sees real Ansible tasks completing

### Act 3: The Student Experience (3-4 min)
- Open a browser tab as "Student Alice"
- Log into the Jupyter notebook environment (OpenShift OAuth)
- Show a pre-loaded course notebook that:
  - Connects to both Granite and Llama endpoints (demonstrate model choice)
  - Demonstrates a basic agentic workflow using tool-calling
  - Runs inference — show the response streaming back
- Quick switch to OpenShift console: show GPU utilization metrics, model serving pods, namespace isolation

### Act 4: The Governance Story (1-2 min)
- Switch to Grafana: show per-course token consumption, cost tracking, usage patterns
- Show resource quotas preventing a student from consuming all GPU memory
- Show the AAP scheduled job that tears down the environment after the semester end date
- Mention: audit trail, chargeback per department

### Closing Talking Points (1-2 min, no live demo needed)
- How this same platform connects to HPC (Slinky for Slurm integration, BMaaS for bare-metal GPU scheduling)
- How Event-Driven Ansible could auto-scale model replicas during assignment deadlines
- How multiple departments share one platform with proper isolation
- "Professor chose Granite for this course — a biology professor might serve a fine-tuned protein model instead"

---

## Technical Architecture

```
Professor Portal (AAP Survey / Web App)
         |
         v
Ansible Automation Platform Controller  [TO ADD]
    |-- Workflow Job Template --
    |                          |
    v                          v
OpenShift API               OpenShift AI 3.0 (RHOAI)  [EXISTS]
  - Namespace                 - MaaS Gateway  [EXISTS]
  - Quotas/RBAC               - Llama (Llama Stack)  [EXISTS]
  - NetworkPolicy              - Granite 3.1 8B  [TO ADD]
  - Routes/Ingress             - Jupyter Workbenches  [TO ADD]
         |                     |
         v                     v
GPU Node Pool  [EXISTS]     Grafana Analytics  [EXISTS - reframe dashboards]
```

---

## Infrastructure: What Exists vs. What to Build

### Already Done (from MaaS workshop)
- OpenShift 4.20 cluster with GPU nodes
- NVIDIA GPU Operator + NFD
- OpenShift AI 3.0 operator
- Llama model served via Llama Stack with MaaS API gateway
- Token-based access control and API keys
- Grafana dashboards (token consumption, cost, usage patterns)
- OpenShift Serverless + Service Mesh (for KServe, if used)
- MCP server integration

### To Install/Configure
- **Ansible Automation Platform operator** — install on-cluster, configure controller, create service account with cluster-admin for provisioning
- **Granite 3.1 8B Instruct** — deploy as additional model alongside Llama (via vLLM ServingRuntime or existing MaaS pattern)
- **RHOAI Workbench configuration** — custom notebook image with course libraries, workbench templates

### To Build (Ansible + Notebooks)
- **Ansible roles/playbooks:**
  - `course-namespace` — create project, apply quotas, RBAC
  - `course-model-access` — generate scoped API tokens for the course's model allocation
  - `course-workbenches` — deploy Jupyter workbenches per student (or shared with PV per student)
  - `course-teardown` — cleanup at semester end
- **AAP Workflow Job Template** — chains the above with survey variables (course name, students, model, dates)
- **Course notebooks** (2-3 polished .ipynb files):
  - "Lab 1: Your First LLM API Call" — basic prompt/response against Granite endpoint
  - "Lab 2: Comparing Models" — same prompt to Granite vs Llama, discuss tradeoffs
  - "Lab 3: Building an Agent" — tool-calling / agentic workflow using MaaS endpoint
- **Custom workbench image** (or pip install list) — langchain, openai SDK, httpx, standard data science stack

---

## Build Timeline (3 weeks, compressed from original 6)

### Week 1: Platform Additions
- Install AAP operator on the MaaS cluster
- Configure Automation Controller (admin user, project, credentials for OCP API)
- Deploy Granite 3.1 8B as additional model serving instance
- Validate Granite endpoint works with OpenAI-compatible API calls
- Begin writing Ansible playbooks (namespace, RBAC, quotas)

### Week 2: Automation + Student Experience
- Complete Ansible playbooks (workbench provisioning, token generation, teardown)
- Build AAP Workflow Job Template with Survey form
- Configure custom Jupyter workbench image
- Write course notebooks (Labs 1-3)
- Create demo users (professor, 2-3 students)
- Add education-framed Grafana dashboard panels (optional polish)

### Week 3: Rehearsal + Hardening
- Full end-to-end dry runs (at least 3 complete walkthroughs)
- Pre-warm models so cold-start isn't an issue during demo
- Time the demo — trim to 10-12 min
- Record fallback video in case of network/cluster issues at venue
- Prepare architecture slide and Q&A talking points

---

## Key Technical Decisions

- **Models:** Granite 3.1 8B Instruct (Red Hat's own) + Llama (already deployed). Showing both reinforces the "model choice freedom" message.
- **Notebook platform:** RHOAI Workbenches (Jupyter-based, native to the operator, professors and students expect Jupyter)
- **Self-service trigger:** AAP Survey Form for v1 (zero custom code needed, built into Controller). Upgrade to a web app later if polish is needed.
- **Model API compatibility:** Both models should be accessible via OpenAI-compatible API (vLLM and Llama Stack both support this), so notebooks use the same `openai` Python SDK regardless of backend model.
- **GPU sharing:** Leverage whatever the existing MaaS workshop uses; for the demo narrative, mention NVIDIA time-slicing as how 40 students share GPUs.

---

## Future: Portability to Your Own Cluster

The existing MaaS workshop cluster is ideal for building and demoing. For long-term portability to your own cluster (which currently lacks GPUs):

- **Option A:** Add cloud GPU nodes (AWS p4d/g5 instances, or Azure NC-series) to your cluster via MachineSet
- **Option B:** Use a smaller model (Granite 3.0 2B) that runs on CPU for development, GPU for demo day
- **Option C:** Keep the MaaS workshop cluster as your demo platform and use your own cluster for the non-GPU pieces (AAP, namespace provisioning) with a remote model endpoint
- **Decision can wait** until after Educause — get the demo working on the MaaS cluster first

---

## Risk Mitigation

- **Model cold-start is slow:** Pre-load both models before the demo; existing MaaS infrastructure likely keeps them warm
- **AAP job takes too long live:** Pre-run once so images are cached on nodes; the live run will be fast (30-60s)
- **Granite doesn't fit alongside Llama on available GPUs:** Use a smaller Granite variant (3B) or serve on CPU for demo purposes if needed
- **Network issues at venue:** Record a backup video of the full demo flow
- **"Why not Google Colab?":** Data sovereignty, FERPA compliance, cost control at scale, institutional identity integration, no per-seat SaaS licensing, model choice freedom, on-prem option

---

## Differentiators to Emphasize

1. **Single platform** — not stitching together 5 SaaS products
2. **Automation** — repeatable across 100 courses, not artisanal per-professor setup
3. **Governance** — quotas, RBAC, audit trail, chargeback built in
4. **Model choice freedom** — serve Granite, Llama, Mistral, or domain-specific models without vendor lock-in
5. **On-prem option** — keeps student data and research IP on institutional infrastructure
6. **Red Hat ecosystem** — same skills your Linux admins already have (Ansible, OpenShift, RHEL)
7. **Already working** — the MaaS infrastructure, monitoring, and API gateway are production-grade today