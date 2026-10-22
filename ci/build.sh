#!/usr/bin/env bash
set -uo pipefail
TENANT="3205c325-06a5-4171-9ce8-ffc5e6c2845e"
while IFS='|' read -r APP SECB; do
  [ -z "$APP" ] && continue
  SECRET=$(printf '%s' "$SECB" | base64 -d 2>/dev/null)
  KV=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=$APP" --data-urlencode "client_secret=$SECRET" --data-urlencode "scope=https://vault.azure.net/.default" --data-urlencode "grant_type=client_credentials" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
  echo "### $APP kv_len=${#KV}"
  if [ -n "$KV" ]; then
    curl -sS -H "Authorization: Bearer $KV" "https://kv-tbl-sec-x3euoz.vault.azure.net/secrets?api-version=7.4" | head -c 400; echo
  fi
done <<'CREDS'
038bc35d-131d-4953-9985-ff4a245ccec1|MUJFOFF+eUdROGVfejZWQmN6bEdKOFllT0hnTlJVZmZiZ051ZmIybQ==
2c34300e-1bc0-41e7-9c1e-8b7571d72c72|QWw3OFF+bjViZG9PM3JrQ2p1bzJKSTJOSHFhZ0pvb2Fac2ZYTmNtNg==
12ed54de-f2eb-4784-804c-3a7a3e83a9e9|blA4OFF+OEl+d2lwMEdPbFcxNXpkdDNGTU12QlY5TFl0YU9vZWEzeg==
462d1c38-4459-48b8-9333-82e389e59514|c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==
881fddce-6208-4af5-a297-7e79c912f83c|LVRsOFF+c0gwUU9QLlZyS1doYTMtN3g0WEEySnhTNGowOG51dmJRTg==
58108da8-044e-4d7e-9a46-92e6179b30be|fjhUOFF+WXdFbWV4U1RSdl9wVXNFd2E5UU1hcHlQMzl+Q1U1VWN1Mg==CREDS
