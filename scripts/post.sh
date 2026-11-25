#!/usr/bin/env bash
# Posts the first item in queue/ as an Instagram story, then moves it to posted/ (or failed/).
# Order: file names sorted; "0-..." (post now) comes before "1-..." (scheduled).
set -uo pipefail
API="https://graph.facebook.com/v25.0"
RAW="https://raw.githubusercontent.com/$GITHUB_REPOSITORY/main"

f=$(ls -1 queue 2>/dev/null | grep -v '^\.gitkeep$' | sort | head -n1)
[ -z "$f" ] && { echo "queue empty"; exit 0; }

git config user.name "ig-story-bot"
git config user.email "ig-story-bot@users.noreply.github.com"
finish() { # $1=dest dir, $2=message
  mkdir -p "$1"; git mv "queue/$f" "$1/$f"; git commit -qm "$2"; git push -q; echo "$2"
}
fail() { finish failed "FAILED $f: $1"; exit 1; }

lower=$(echo "$f" | tr 'A-Z' 'a-z')
if [[ "$lower" == *.url ]]; then url=$(tr -d '\r\n' < "queue/$f"); else url="$RAW/queue/$f"; fi
if [[ "$(echo "$url" | tr 'A-Z' 'a-z')" =~ \.(mp4|mov)(\?|$) ]]; then field=video_url; else field=image_url; fi

resp=$(curl -sS -X POST "$API/$IG_USER_ID/media" --data-urlencode "media_type=STORIES" \
  --data-urlencode "$field=$url" --data-urlencode "access_token=$IG_TOKEN")
cid=$(echo "$resp" | jq -r '.id // empty')
[ -n "$cid" ] || fail "$(echo "$resp" | jq -c '.error.message // .')"

for i in $(seq 1 30); do
  st=$(curl -sS "$API/$cid?fields=status_code&access_token=$IG_TOKEN" | jq -r '.status_code')
  [ "$st" = "FINISHED" ] && break
  { [ "$st" = "ERROR" ] || [ "$st" = "EXPIRED" ]; } && fail "container $st"
  sleep 10
done

resp=$(curl -sS -X POST "$API/$IG_USER_ID/media_publish" --data-urlencode "creation_id=$cid" \
  --data-urlencode "access_token=$IG_TOKEN")
mid=$(echo "$resp" | jq -r '.id // empty')
[ -n "$mid" ] || fail "$(echo "$resp" | jq -c '.error.message // .')"
finish posted "posted $f media_id=$mid"
