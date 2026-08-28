#!/usr/bin/env bash
# Source this (do NOT execute):  source scripts/setup-env.sh
#
# Derives the environment for aap/playbooks/setup-controller.yml on the RHDP/MaaS cluster
# you're currently logged into with oc. You supply CONTROLLER_OAUTH_TOKEN; everything else
# auto-derives, including a freshly minted, longer-lived MaaS model token (verified before use).
#
# Usage:
#   export CONTROLLER_OAUTH_TOKEN=<gateway API token, Write scope>   # Access Management > API Tokens
#   source scripts/setup-env.sh
#   ansible-playbook aap/playbooks/setup-controller.yml

if [ -z "${CONTROLLER_OAUTH_TOKEN:-}" ]; then
  echo "!! Set CONTROLLER_OAUTH_TOKEN first (AAP gateway API token, Write scope), then re-source:" >&2
  echo "     export CONTROLLER_OAUTH_TOKEN=<token>; source scripts/setup-env.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# --- cluster-derived ---
export CLUSTER_APPS_DOMAIN="$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')"
export CONTROLLER_HOST="https://$(oc get route aap -n aap -o jsonpath='{.spec.host}')"
export K8S_HOST="$(oc whoami --show-server)"
export K8S_BEARER_TOKEN="$(oc whoami -t)"

# --- defaults (override by exporting before sourcing) ---
export GIT_URL="${GIT_URL:-https://github.com}"
export GIT_USER="${GIT_USER:-wlptn}"
export MODEL_NAME="${MODEL_NAME:-qwen3-4b-instruct}"
export MODEL_ENDPOINT="${MODEL_ENDPOINT:-http://maas.${CLUSTER_APPS_DOMAIN}/llm/${MODEL_NAME}/v1}"

# --- MaaS model token: mint a fresh 24h one (discovering the gateway SA); keep existing on failure ---
if [ "${REMINT_MODEL_KEY:-1}" = "1" ]; then
  _ns="$(oc get ns -o name 2>/dev/null | grep -oE 'maas-default-gateway-tier-[a-z0-9]+' | head -1 | cut -d/ -f2)"
  _sa="$(oc get sa -n "${_ns:-nonexistent}" -o name 2>/dev/null | grep -oE 'admin-[a-z0-9]+' | head -1 | cut -d/ -f2)"
  if [ -n "${_ns:-}" ] && [ -n "${_sa:-}" ]; then
    _tok="$(oc create token "$_sa" -n "$_ns" --audience=maas-default-gateway-sa --duration=24h 2>/dev/null)"
    [ -n "${_tok:-}" ] && export MODEL_API_KEY="$_tok"
  fi
fi

# --- verify the model key works, so a dead/wrong key fails fast (not at the demo) ---
if [ -n "${MODEL_API_KEY:-}" ]; then
  _code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $MODEL_API_KEY" "$MODEL_ENDPOINT/models")"
  echo "MaaS /v1/models check -> HTTP $_code $([ "$_code" = 200 ] && echo '(OK)' || echo '(<-- key NOT accepted; mint a fresh one)')"
else
  echo "!! MODEL_API_KEY not set and auto-mint failed — set it manually (oc create token ... or the MaaS dev portal)"
fi

echo "env ready:"
echo "  CLUSTER_APPS_DOMAIN = $CLUSTER_APPS_DOMAIN"
echo "  CONTROLLER_HOST     = $CONTROLLER_HOST"
echo "  MODEL_ENDPOINT      = $MODEL_ENDPOINT   (MODEL_NAME=$MODEL_NAME)"
echo "  K8S_HOST            = $K8S_HOST"
echo "  tokens set: CONTROLLER_OAUTH_TOKEN, K8S_BEARER_TOKEN, MODEL_API_KEY"
echo "next: ansible-playbook aap/playbooks/setup-controller.yml"
