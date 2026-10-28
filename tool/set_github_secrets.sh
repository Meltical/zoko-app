#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=Meltical/zoko-app
SIGNING="$HOME/Dev/Perso/zoko-signing"
python3 -I -c "import json;print(json.load(open('env.json'))['SUPABASE_URL'],end='')" | gh secret set SUPABASE_URL -R "$REPO"
python3 -I -c "import json;print(json.load(open('env.json'))['SUPABASE_KEY'],end='')" | gh secret set SUPABASE_KEY -R "$REPO"
base64 -i "$SIGNING/zoko-release.jks" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64 -R "$REPO"
sed -n 's/^storePassword=//p' "$SIGNING/key.properties" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_PASSWORD -R "$REPO"
gh secret list -R "$REPO"
