# WhatsApp AI Prompt Pack (No API, Copy/Paste)

Use these prompts with your AI assistant by pasting WhatsApp message batches.

## Prompt 1: Incident Triage

Input to AI:
- Paste latest WhatsApp incident messages from Farm Ops Live.

Prompt:
"You are my farm operations triage assistant. Convert the messages into a table with columns: Incident ID, Date, Time, Reporter, Command Type, Details, Zone/Location, Severity (LOW/MEDIUM/HIGH/CRITICAL), Evidence Required (Yes/No), Evidence Attached (Yes/No), Owner Suggested, ETA Suggested, Status (OPEN/IN_PROGRESS/CLOSED), Follow-up Needed (Yes/No). Also list: (1) critical incidents needing immediate ACK, (2) incidents missing evidence, and (3) duplicate/repeat incidents by type+location." 

## Prompt 2: ACK Drafts

Input to AI:
- Paste current open incidents table.

Prompt:
"Draft concise manager replies in this exact format: ACK [incident-id] [severity] [owner] [ETA]. Prioritize CRITICAL then HIGH incidents. Keep each line under 100 characters."

## Prompt 3: Closure Drafts

Input to AI:
- Paste resolved incident notes from field team.

Prompt:
"Convert these resolution notes into closure messages using format: CLOSED [incident-id] [resolution]. Keep resolutions specific and under 120 characters."

## Prompt 4: End-of-Day Summary

Input to AI:
- Paste today’s incident table.

Prompt:
"Create a manager-ready end-of-day summary with: total incidents, critical count, high count, unresolved count, top 3 issue types, top 3 locations, and 3 actions for tomorrow. Keep it short and practical."

## Prompt 5: Weekly KPI Fill

Input to AI:
- Paste weekly incident table + current KPI tracker row.

Prompt:
"Compute and fill these KPI fields: Total Incidents, Critical Incidents, High Incidents, Evidence Completion %, Median ACK Minutes (Critical/High), Median Close Hours (All), Closure SLA %, Repeat Incident Rate %, Daily Reporting Compliance %, Egg Reporting Compliance %, Harvest Reporting Compliance %, Open Incidents End of Week, Top 3 Incident Types, Top 3 Incident Zones, Notes/Actions. Show formulas used in one line each."

## Prompt 6: Best Practices Generator

Input to AI:
- Paste weekly KPI row + repeat incidents.

Prompt:
"Generate 5 practical best-practice cards using this format: BEST PRACTICE [title] | Trigger | Action | Owner | Timing | Evidence. Focus on preventing repeated incidents next week."

## Prompt 7: Data Quality Check

Input to AI:
- Paste the current daily log sheet rows.

Prompt:
"Audit this log for quality issues: missing IDs, missing zone/location, severity mismatch, required evidence missing, invalid statuses, duplicate incidents. Return a fix list by priority."
