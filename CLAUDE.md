# Instagram story queue (@lox_amane_ao)

This repo is the posting queue. GitHub Actions posts items from `queue/`; you only add files. Keep replies short.

## When the user sends media or a URL in chat
- Media file (image/video the user attached): save it into `queue/` as
  - `1-YYYYMMDD-HHMMSS.<ext>` for 予約/ストック/あとで (posted at the next scheduled time, oldest first)
  - `0-YYYYMMDD-HHMMSS.<ext>` for 今すぐ/投稿して (posted right away)
  - Use JST time. Images must be JPEG: convert png/webp/heic to .jpg before saving. Video: .mp4/.mov, max 60s.
- Direct media URL (ends with .jpg/.png/.mp4/.mov): write the URL as the only line of `queue/<same name rule>.url`.
- Web page / share links (lin.ee, Google Drive, X, YouTube...) cannot be posted; tell the user.
- No instruction words → ask one line: 今すぐ or 予約.
- Commit to `main` and push. Commit message must contain `#now` for 今すぐ (this triggers the post), otherwise `queue: add <name>`.

## Daily rotation (posted every day)
- Files in `rotation/` are posted every day at 19:00 / 20:00 / 21:00 JST, one per slot, order reshuffled daily, 0-7 min random delay.
- 毎日/繰り返し → save the file into `rotation/` (any name, JPEG or mp4/mov). Remove a file to stop it.
- One-off 予約 items in `queue/` take the slot first; the rotation item for that slot is skipped that day.

## Status
- Waiting: files in `queue/`. Posted: `posted/`. Failed: `failed/` (commit message has the reason).
- Schedule: `.github/workflows/post-story.yml` (cron is UTC; JST = UTC+9). Change only when asked.
- Never print or ask for tokens. They are GitHub secrets `IG_TOKEN`, `IG_USER_ID`.
