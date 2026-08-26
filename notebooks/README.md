# Course Content Packs

Each subdirectory is a **content pack** that can be selected when provisioning
a course through the AAP self-service portal.

| Pack | Survey value | Description | Labs |
|---|---|---|---|
| AI Fundamentals | `ai-fundamentals` | Intro to LLM APIs, parameter tuning, building agents | 3 |
| Data Science | `data-science` | AI-assisted data exploration and predictive modeling | 2 |
| NLP | `nlp` | Text analysis, sentiment, entity extraction, prompt engineering | 2 |

## Adding a new content pack

1. Create a new subdirectory under `notebooks/` (e.g. `notebooks/computer-vision/`)
2. Add Jupyter notebooks (they must use `MODEL_ENDPOINT`, `MODEL_API_KEY`, `MODEL_NAME` env vars)
3. Add the new option to the AAP survey in `aap/job-templates/provision-course.yaml`
4. Add any extra Python packages to `workbenches/Dockerfile.jupyter-edu`
5. Push to Gitea -- new provisions will pick up the content automatically
