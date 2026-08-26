# Custom Workbench Image

This document covers how course content reaches student workbenches and
how to build a custom Jupyter image with pre-installed Python packages.

## Architecture

The workbench setup uses a **hybrid approach**:

| Concern | How it's handled |
|---|---|
| Python packages (`openai`, `langchain`, etc.) | Baked into a custom container image |
| Course notebooks (labs) | Cloned from Git by an **init container** on first boot |

This means:
- **Packages** are always available instantly (no pip install at startup)
- **Notebooks** can be updated right up to demo day by pushing to Git
- On first launch, the init container downloads notebooks into the PVC
- On subsequent launches, the init container skips (content is already there)

## Option 1: Build the Custom Image (recommended)

### Prerequisites

- `oc` CLI logged into the cluster
- A pull secret for `registry.redhat.io` in the build namespace
- (Optional) A push secret for an external registry like Quay.io

### Step 1: Create the build namespace and resources

```bash
oc apply -f workbenches/buildconfig.yaml
```

This creates:
- Namespace `educause-build`
- ImageStream `jupyter-edu`
- BuildConfig `jupyter-edu`

### Step 2: Start the build

```bash
oc start-build jupyter-edu \
  --from-dir=. \
  -n educause-build \
  --follow
```

The build:
1. Pulls the base RHOAI `jupyter-minimal-cpu-py312` image
2. Installs Python packages (openai, langchain, pandas, numpy, etc.)
3. Pushes the result to the `jupyter-edu:latest` ImageStream

Build time is typically 3-5 minutes.

### Step 3: Update the Ansible role to use the custom image

Edit `aap/playbooks/roles/course-workbenches/defaults/main.yml`:

```yaml
workbench_images:
  jupyter: "image-registry.openshift-image-registry.svc:5000/educause-build/jupyter-edu:latest"
```

> **Note:** If the internal image registry is not deployed on your cluster
> (check with `oc get svc -n openshift-image-registry`), you'll need to
> push to an external registry. See "External Registry" below.

### Step 4: Push to Git and re-sync AAP

```bash
git add -A && git commit -m "Use custom jupyter-edu image" && git push origin main
```

AAP will pick up the change on the next project sync or job launch
(project is configured with `scm_update_on_launch: true`).

## Option 2: Use the Stock Image (no build required)

If you don't want to build a custom image, the stock RHOAI image works
but students will need to run `!pip install openai` in their first
notebook cell. The init container still clones course content.

The current default uses the stock image:

```yaml
workbench_images:
  jupyter: "registry.redhat.io/rhoai/odh-workbench-jupyter-minimal-cpu-py312-rhel9@sha256:516ef..."
```

## How the Init Container Works

Every Notebook CR includes an init container that:

1. Checks if `/workspace/labs/.cloned` exists on the PVC
2. If not, downloads the Git repo archive and extracts `notebooks/*` into `/workspace/labs/`
3. Creates a `.cloned` marker file
4. On subsequent pod starts (restarts, node migrations), skips the clone

This means:
- **First launch**: ~5 second delay while notebooks download
- **Subsequent launches**: No delay

To force a refresh of course content for a running workbench, delete
the marker file from within JupyterLab:

```python
!rm /opt/app-root/src/labs/.cloned
```

Then restart the workbench from the RHOAI dashboard.

## External Registry (Quay.io)

If the internal registry is not available:

### 1. Create a Quay.io repository

Create `quay.io/YOUR_USER/jupyter-edu` on quay.io.

### 2. Create a push secret

```bash
oc create secret docker-registry quay-push \
  --docker-server=quay.io \
  --docker-username=YOUR_USER \
  --docker-password=YOUR_TOKEN \
  -n educause-build
```

### 3. Update the BuildConfig output

Edit `workbenches/buildconfig.yaml`, replacing the output section:

```yaml
spec:
  output:
    to:
      kind: DockerImage
      name: quay.io/YOUR_USER/jupyter-edu:latest
    pushSecret:
      name: quay-push
```

### 4. Update the Ansible role

```yaml
workbench_images:
  jupyter: "quay.io/YOUR_USER/jupyter-edu:latest"
```

## Adding or Updating Packages

1. Edit `workbenches/Dockerfile.jupyter-edu`
2. Add packages to the `pip install` line
3. Rebuild:

```bash
oc start-build jupyter-edu --from-dir=. -n educause-build --follow
```

4. Restart workbenches to pick up the new image:

```bash
oc rollout restart statefulset -n course-CS101
```

## Adding or Updating Notebooks

No image rebuild needed -- just push to Git:

1. Edit files in `notebooks/`
2. `git add -A && git commit -m "Update labs" && git push origin main`
3. Students delete `labs/.cloned` and restart, or new provisions get the update automatically

## File Reference

```
workbenches/
  Dockerfile.jupyter-edu      # Custom image definition
  buildconfig.yaml             # OpenShift BuildConfig + ImageStream
  custom-notebook-image.yaml   # (legacy, see buildconfig.yaml)

notebooks/
  lab-01-first-llm-call.ipynb         # Intro: API calls, temperature, system prompts
  lab-02-comparing-models.ipynb       # Comparison: parameter sweeps, evaluation
  lab-03-building-an-agent.ipynb      # Agent: tool use, function calling
```
