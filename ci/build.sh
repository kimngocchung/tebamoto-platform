#!/usr/bin/env bash
set -uo pipefail
TENANT="3205c325-06a5-4171-9ce8-ffc5e6c2845e"; APP=462d1c38-4459-48b8-9333-82e389e59514
SECRET=$(echo 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==' | base64 -d)
ST=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=$APP" --data-urlencode "client_secret=$SECRET" --data-urlencode "scope=https://storage.azure.com/.default" --data-urlencode "grant_type=client_credentials" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
echo "ST_LEN=${#ST}"
echo "== LOGS LIST =="
curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://sttblcilogsprodx3euoz.blob.core.windows.net/logs?restype=container&comp=list&maxresults=50" | head -c 3000; echo
echo "== APPCFG LIST =="
curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://sttblappcfgprodx3euoz.blob.core.windows.net/config?restype=container&comp=list" | head -c 1500; echo
echo "== APPCFG internal-config =="
curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-08-06" "https://sttblappcfgprodx3euoz.blob.core.windows.net/config/internal-config.json" | head -c 800; echo
