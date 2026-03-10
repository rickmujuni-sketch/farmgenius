# WhatsApp AI Operator Daily Checklist

Goal: Keep farm reporting, response, and tracking consistent in under 20 minutes/day.

## Morning (07:00–07:10)

- Pull new WhatsApp incident messages from last 12 hours.
- Run Prompt 1 (Incident Triage) from `WHATSAPP_AI_PROMPT_PACK.md`.
- Post AI draft ACK lines to manager for approval.
- Ensure all CRITICAL/HIGH incidents have ACK.
- Update daily log with structured rows.

## Midday (12:30–12:40)

- Pull new messages since morning.
- Re-run Prompt 1 for new incidents only.
- Run Prompt 2 (ACK Drafts) for open critical/high incidents.
- Flag missing evidence (photos/details) and send follow-up requests.
- Update statuses in daily log (OPEN / IN_PROGRESS / CLOSED).

## Evening (18:00–18:10)

- Pull final messages for the day.
- Run Prompt 4 (End-of-Day Summary).
- Send manager-ready summary text for final posting.
- Confirm unresolved incidents are clearly assigned with ETA.
- Finalize daily log rows and hand over open items.

## Non-Negotiables

- Never leave CRITICAL incidents without ACK.
- Keep one incident per row in the log.
- Mark missing evidence the same day.
- Manager approval required before posting final critical action decisions.

## Quick Done Check (End of Day)

- Critical incidents ACKed: Yes/No
- High incidents ACKed: Yes/No
- Missing evidence flagged: Yes/No
- Daily log updated: Yes/No
- End-of-day summary sent: Yes/No
