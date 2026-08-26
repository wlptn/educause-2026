# Teardown Guide

This guide removes all Educause demo components **except AAP** (Ansible
Automation Platform), which is managed separately.

Run these steps in order. Each section is independent -- you can skip
sections for components you didn't install.

---

## 1. Remove Course Environments

If you provisioned any course namespaces via AAP, tear them down first.
Either use the AAP teardown job template or run manually:

```bash
# List course namespaces
oc get namespaces -l educause.redhat.com/managed-by=aap

# Delete each one (cascades all resources within)
oc delete namespace course-cs101
oc delete namespace course-bio200
# ... repeat for each course namespace
```

## 2. Remove the Ansible Automation Portal

```bash
# Uninstall the Helm release
helm uninstall redhat-rhaap-portal -n aap-portal

# Delete the project and all its resources
oc delete project aap-portal
```

Optionally, clean up the OAuth application in AAP Gateway:

1. Log in to `https://aap-aap.apps.ocp.CHANGEME.opentlc.com`
2. Go to **Administration > Applications**
3. Delete the `Ansible Automation Portal` application

## 3. Remove MaaS Configuration

```bash
# Delete MaaS resources
oc delete -k maas/

# Delete the API key secret
oc delete secret rh-maas-api-key -n redhat-ods-applications
```

## 4. Remove Custom Workbench Image

```bash
# Delete the BuildConfig and ImageStream
oc delete -f workbenches/custom-notebook-image.yaml

# Verify removal
oc get buildconfig,imagestream -n redhat-ods-applications | grep jupyter-edu
```

## 5. Remove OpenShift AI (RHOAI)

```bash
# Delete the DataScienceCluster CR
oc delete datasciencecluster default-dsc

# Wait for the operator to clean up managed resources
sleep 30

# Delete the operator subscription and CSV
oc delete subscription rhods-operator -n redhat-ods-operator
oc delete csv -n redhat-ods-operator -l operators.coreos.com/rhods-operator.redhat-ods-operator

# Delete the namespace
oc delete namespace redhat-ods-operator

# Clean up RHOAI application namespaces if they persist
oc delete namespace redhat-ods-applications --ignore-not-found
oc delete namespace redhat-ods-monitoring --ignore-not-found
```

## 6. Remove OpenShift Serverless

```bash
# Delete KnativeServing (created by the RHOAI operator or manually)
oc delete knativeserving knative-serving -n knative-serving --ignore-not-found

# Wait for cleanup
sleep 30

# Delete the operator subscription and CSV
oc delete subscription serverless-operator -n openshift-serverless
oc delete csv -n openshift-serverless -l operators.coreos.com/serverless-operator.openshift-serverless

# Delete the namespaces
oc delete namespace openshift-serverless
oc delete namespace knative-serving --ignore-not-found
oc delete namespace knative-eventing --ignore-not-found
```

## 7. Remove Kuadrant (Connectivity Link)

```bash
# Delete any Kuadrant CRs first
oc delete kuadrant kuadrant -n kuadrant-system --ignore-not-found 2>/dev/null

# Delete the operator subscription and CSV
oc delete subscription kuadrant-operator -n openshift-operators
oc delete csv -n openshift-operators -l operators.coreos.com/kuadrant-operator.openshift-operators

# Clean up CRDs (optional, only if no other consumers)
oc get crd -o name | grep kuadrant | xargs -r oc delete
oc get crd -o name | grep authorino | xargs -r oc delete
oc get crd -o name | grep limitador | xargs -r oc delete
```

## 8. Remove Service Mesh

```bash
# Delete any ServiceMeshControlPlane CRs
oc delete smcp -A --all --ignore-not-found 2>/dev/null

# Delete the operator subscription and CSV
oc delete subscription servicemeshoperator -n openshift-operators
oc delete csv -n openshift-operators -l operators.coreos.com/servicemeshoperator.openshift-operators

# Clean up the istio-system namespace if created
oc delete namespace istio-system --ignore-not-found
```

## 9. Clean Up OperatorGroups (if created for this demo)

```bash
oc delete operatorgroup redhat-ods-operator -n redhat-ods-operator --ignore-not-found
oc delete operatorgroup openshift-serverless -n openshift-serverless --ignore-not-found
```

## 10. Verify

Confirm no demo resources remain:

```bash
echo "=== Remaining subscriptions ==="
oc get subscriptions -A | grep -E 'rhods|serverless|servicemesh|kuadrant'

echo "=== Remaining CSVs ==="
oc get csv -A --no-headers | grep -E 'rhods|serverless|servicemesh|kuadrant'

echo "=== Remaining namespaces ==="
oc get namespaces | grep -E 'redhat-ods|knative|istio|course-'

echo "=== Remaining Helm releases ==="
helm list -A | grep rhaap
```

If any resources persist, delete them manually. CRDs from operators may
linger -- they are safe to leave unless they conflict with a future install.

---

## What This Does NOT Remove

- **AAP** (Controller, Hub, EDA, Gateway) -- managed separately
- **ODF / Storage operators** -- pre-existing cluster infrastructure
- **OpenShift Virtualization** -- pre-existing
- **The Git repository** -- your code is safe
- **This local git clone** -- only cluster resources are removed
