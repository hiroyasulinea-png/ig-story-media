#!/usr/bin/env bash
# Posts Instagram stories from queue/ and moves each file to posted/ (or failed/).
#   push with "#now" : posts every "0-..." (post now) item
#   schedule / manual: posts the first item ("0-..." before "1-...", then oldest first)
# Always works on the latest main, so an item is never posted twice.
set -uo pipefail
API="https://graph.facebook.com/v25.0"
RAW="https://raw.githubusercontent.com/$GITHUB_REPOSITORY/main"
git config user.name "ig-story-bot"
git config user.email "ig-story-bot@users.noreply.github.com"

sync() { git fetch -q origin main && git reset -q --hard origin/main; }
next() { ls -1 queue 2>/dev/null | grep -v '^\.gitkeep$' | sort | grep "^${1:-}" | head -n1; }

finish() { # $1=file $2=dest dir $3=message ; retries push if someone else pushed meanwhile
  for t in 1 2 3; do
    sync; [ -f "queue/$1" ] || return 0
    mkdir -p "$2"; git mv "queue/$1" "$2/$1"; git commit -qm "$3"
    git push -q origin HEAD:main && { echo "$3"; return 0; }
    sleep 3
  done
  echo "push failed: $3"; exit 1
}

post_one() { # $1=file name ; returns 1 on failure
  local f="$1" lower url field resp cid st mid
  lower=$(echo "$f" | tr 'A-Z' 'a-z')
  if [[ "$lower" == *.url ]]; then url=$(tr -d '\r\n' < "queue/$f"); else url="$RAW/queue/$f"; fi
  if [[ "$(echo "$url" | tr 'A-Z' 'a-z')" =~ \.(mp4|mov)(\?|$) ]]; then field=video_url; else field=image_url; fi

  resp=$(curl -sS -X POST "$API/$IG_USER_ID/media" --data-urlencode "media_type=STORIES" \
    --data-urlencode "$field=$url" --data-urlencode "access_token=$IG_TOKEN")
  cid=$(echo "$resp" | jq -r '.id // empty')
  [ -n "$cid" ] || { finish "$f" failed "FAILED $f: $(echo "$resp" | jq -c '.error.message // .')"; return 1; }

  for i in $(seq 1 30); do
    st=$(curl -sS "$API/$cid?fields=status_code&access_token=$IG_TOKEN" | jq -r '.status_code')
    [ "$st" = "FINISHED" ] && break
    if [ "$st" = "ERROR" ] || [ "$st" = "EXPIRED" ]; then finish "$f" failed "FAILED $f: container $st"; return 1; fi
    sleep 10
  done

  resp=$(curl -sS -X POST "$API/$IG_USER_ID/media_publish" --data-urlencode "creation_id=$cid" \
    --data-urlencode "access_token=$IG_TOKEN")
  mid=$(echo "$resp" | jq -r '.id // empty')
  [ -n "$mid" ] || { finish "$f" failed "FAILED $f: $(echo "$resp" | jq -c '.error.message // .')"; return 1; }
  finish "$f" posted "posted $f media_id=$mid"
}

rc=0
sync
if [ "${GITHUB_EVENT_NAME:-}" = "push" ]; then
  while f=$(next 0-); [ -n "$f" ]; do post_one "$f" || rc=1; sync; done
else
  f=$(next); [ -z "$f" ] && { echo "queue empty"; exit 0; }
  post_one "$f" || rc=1
fi
exit $rc
