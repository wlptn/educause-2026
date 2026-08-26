# Installing the Ansible Automation Portal

The Ansible automation portal is a **separate component** from the AAP Gateway.
It is a self-service web UI built on Red Hat Developer Hub (Backstage) that
gives non-technical users (professors in our case) a guided, point-and-click
interface to launch automation. It syncs job templates from AAP Controller and
presents them as step-by-step forms.

**Key facts:**

- Deployed via Helm chart on OpenShift (not part of the AAP operator)
- Uses OAuth to authenticate against your existing AAP instance
- Syncs job templates, organizations, users, and teams from AAP
- Supports auto-generated templates (from job template surveys) and custom
  self-service templates (from a git repo)
- Your AAP subscription includes the RHDH license for portal use

**Reference:**
[AAP 2.7 Portal Install Docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-assembly_self_service_about)

---

## Prerequisites

- AAP 2.7 operator installed with Controller, Hub, and Gateway running
- `oc` CLI logged in as cluster-admin
- `helm` CLI v3.10+ installed
- A Red Hat registry service account (for OCI plugin delivery)
  - Create one at: https://access.redhat.com/terms-based-registry/

## Step 1: Select or Create an Organization

The portal connects to a single AAP organization. If you haven't created one:

1. Log in to AAP Gateway: `https://aap-aap.apps.ocp.CHANGEME.opentlc.com`
2. Navigate to **Access Management > Organizations**
3. Create an organization (e.g., `University`)

## Step 2: Create an OAuth Application

The portal authenticates via OAuth against AAP. You need to create an OAuth
app **before** deploying the Helm chart, using a placeholder redirect URI.

1. In AAP Gateway, go to **Administration > Applications**
2. Click **Add**
3. Fill in:
   - **Name:** `Ansible Automation Portal`
   - **Organization:** `University` (or your org name)
   - **Authorization grant type:** `Authorization code`
   - **Client type:** `Confidential`
   - **Redirect URIs:** `https://placeholder.example.com` (updated after deploy)
4. Click **Save**
5. **Copy the `Client ID` and `Client Secret`** -- you'll need these for the
   OpenShift secret. The secret is only shown once.

## Step 3: Enable OAuth Token Creation for External Users

1. In AAP Gateway, go to **Settings > Platform gateway settings**
2. Click **Edit platform gateway settings**
3. Set **Allow external users to create OAuth2 tokens** to **Enabled**
4. Click **Save**

## Step 4: Generate an API Token

1. In AAP Gateway, go to **Access Management > API Tokens**
2. Click **Create API Token**
3. Add a description (e.g., `Portal sync token`)
4. Select your OAuth application (`Ansible Automation Portal`)
5. Set **Scope** to `Write`
6. Click **Create Token**
7. **Copy the token value** -- you'll need it for the OpenShift secret.

## Step 5: Create an OpenShift Project

```bash
oc new-project aap-portal
```

## Step 6: Create Secrets

### AAP authentication secret

```bash
oc create secret generic secrets-rhaap-portal \
  --from-literal=aap-host-url="https://aap-aap.apps.ocp.CHANGEME.opentlc.com" \
  --from-literal=oauth-client-id="<YOUR_OAUTH_CLIENT_ID>" \
  --from-literal=oauth-client-secret="<YOUR_OAUTH_CLIENT_SECRET>" \
  --from-literal=aap-token="<YOUR_API_TOKEN>" \
  -n aap-portal
```

### Registry auth secret (for OCI plugin delivery)

Create an `auth.json` file with your Red Hat registry credentials:

```json
{
  "auths": {
    "registry.redhat.io": {
      "auth": "<base64-encoded-username:password>"
    }
  }
}
```

You can generate this from your registry service account token, or copy it
from an existing pull secret:

```bash
oc get secret/pull-secret -n openshift-config \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps({'auths':{'registry.redhat.io':d['auths']['registry.redhat.io']}}, indent=2))" \
  > auth.json
```

Then create the secret (the name must match `<helm-release-name>-dynamic-plugins-registry-auth`):

```bash
oc create secret generic redhat-rhaap-portal-dynamic-plugins-registry-auth \
  --from-file=auth.json=./auth.json \
  -n aap-portal
```

## Step 7: Install the Helm Chart

```bash
helm repo add openshift-helm-charts https://charts.openshift.io/
helm install redhat-rhaap-portal openshift-helm-charts/redhat-rhaap-portal \
  -n aap-portal \
  -f aap/helm-values-portal.yaml
```

See `aap/helm-values-portal.yaml` in this repo for the values file. Key
things the values override (and why):

| Override | Reason |
|----------|--------|
| `backend.database.connection.user: postgres` | OpenShift PostgreSQL image doesn't create the Bitnami `bn_backstage` user |
| `backend.auth.externalAccess` | Chart's `extraEnvVars` override drops the chart's default BACKEND_SECRET wiring |
| `ENABLE_AUTH_PROVIDER_MODULE_OVERRIDE: "true"` | Required so the RHAAP dynamic auth plugin can register its provider factory |
| `POSTGRESQL_ADMIN_PASSWORD` from secret | Maps to the `postgres` superuser password since we connect as `postgres` |
| `AAP_HOST_URL`, `AAP_TOKEN`, `OAUTH_*` from secret | Chart defaults expect these from `secrets-rhaap-portal` but custom `extraEnvVars` drops them |

## Step 8: Update the OAuth Redirect URI

After the Helm chart deploys, get the portal route:

```bash
oc get route -n aap-portal
```

Then go back to AAP Gateway:

1. Navigate to **Administration > Applications**
2. Edit the `Ansible Automation Portal` application
3. Replace the placeholder redirect URI with:
   `https://<portal-route-hostname>/api/auth/rhaap/handler/frame`
4. Save

## Step 9: Set Up RBAC

After first login, only AAP administrators can see templates. To grant
professors access:

1. Log in to the portal as an AAP admin
2. Go to **Settings > RBAC**
3. Create roles that grant the `catalog-entity.read` permission
4. Assign roles to the professor user or team

## Step 10: Verify

1. Open the portal URL in a browser
2. Log in with AAP credentials
3. Verify that your job templates appear as self-service templates
4. Test launching a template (e.g., "Provision Course Environment")

---

## Troubleshooting

**Portal pods not starting:**
```bash
oc get pods -n aap-portal
oc logs deployment/redhat-rhaap-portal -c backstage-backend -n aap-portal
```

**PostgreSQL auth failures (`password authentication failed`):**
- The OpenShift PostgreSQL image only creates a `postgres` superuser, not
  the Bitnami `bn_backstage` user. Ensure your values set
  `backend.database.connection.user: postgres` with `POSTGRESQL_ADMIN_PASSWORD`.

**`No auth provider found for rhaap`:**
- Add `ENABLE_AUTH_PROVIDER_MODULE_OVERRIDE: "true"` to `extraEnvVars`.
  Without this, the built-in auth module tries to look up "rhaap" in a
  hardcoded provider list and fails before the dynamic plugin can register.

**Templates not syncing:**
- Verify the `secrets-rhaap-portal` secret values are correct
- Check that the API token has `Write` scope
- Confirm the organization name in Helm values matches AAP exactly

**OAuth errors:**
- Verify the redirect URI matches the portal route exactly
- Confirm "Allow external users to create OAuth2 tokens" is enabled
