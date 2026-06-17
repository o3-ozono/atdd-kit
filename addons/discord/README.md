# Discord notifications addon

**Opt-in** addon for `full-autopilot` (#318). Streams each Issue's progress and escalations
to a **per-issue Discord thread**, so an unattended parallel run is observable from anywhere.

This is the only Discord-specific code in atdd-kit. The core stays notification-service-agnostic
(`full-autopilot` fires a generic `FA_NOTIFY_CMD <event> <issue> <detail>` hook); this addon is
one concrete implementation of that hook. (Supersedes the blanket removal from the earlier
notification cleanup — Discord is now allowed strictly as this isolated, opt-in addon.)

## Enable

Not auto-detected. Enable explicitly:

- `session-start` (init): answer `y` to `Enable Discord notifications addon?` (default **N**), or
- run `/atdd-kit:setup-discord`.

Then wire it before launching full-autopilot:

```bash
export FA_NOTIFY_CMD="bash .claude/addons/fa-notify-discord.sh"
export FA_DISCORD_WEBHOOK="<forum-channel webhook URL>"   # required
export FA_DISCORD_MENTION="<@USERID>"                      # optional, used on escalate
export FA_NOTIFY_LEVEL="normal"                            # quiet | normal | verbose
```

## Notification granularity (`FA_NOTIFY_LEVEL`)

Filtering is service-agnostic (applied in the core runtime), so it works for any notifier:

| Level | Sends |
|-------|-------|
| `quiet` | **alert** only — `escalate` / `merge-failed` / `worker-failed` (things that need attention) |
| `normal` (default) | alert + **milestone** — `dispatch` / `merged` |
| `verbose` | + **detail** — `merge-ready` / `progress` / `log` (everything) |

## Behavior

| Event | Posted to the issue's thread |
|-------|------------------------------|
| `dispatch` | 🚀 着手: headless worker 起動 |
| `merge-ready` | 🟢 merge-ready |
| `merged` | ✅ merged |
| `merge-failed` | ⚠️ merge-failed: \<detail\> |
| `worker-failed` | ❌ worker-failed |
| `escalate` | 🚨 ESCALATION \<mention\>: \<detail\> |

- Requires a Discord **forum** channel webhook (`thread_name` creates one thread per Issue;
  subsequent posts append via `thread_id`).
- Messages over ~1900 chars are split.
- `FA_DISCORD_WEBHOOK` unset ⇒ no-op (disabled). Nothing is sent unless configured.
- **Robust HTTP**: `curl --fail` (4xx/5xx → non-zero), `--connect-timeout`/`--max-time` (webhook hang can't stall the dispatcher), HTTP exit code checked and failures recorded to `FA_NOTIFY_ERRLOG` (notifications are never silently lost). `json_str` falls back python3 → jq → pure bash (works without python3).
- HTTP is injectable via `FA_HTTP_POST` (used by the tests to mock the webhook).

## Files

| File | Purpose |
|------|---------|
| `addon.yml` | Manifest (opt-in, deploy mapping, guidance) |
| `scripts/fa-notify-discord.sh` | The notifier (`FA_NOTIFY_CMD` implementation) |
| `tests/test_fa_notify_discord.bats` | Unit tests (DN-1..7: thread create/append, per-issue isolation, no-webhook no-op, chunking, escalate mention, **DN-7 HTTP failure detected & recorded**; HTTP mock-injected) |
