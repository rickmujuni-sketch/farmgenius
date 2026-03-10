# WhatsApp Farm Activity System (MVP, No Complex APIs)

Date: 2026-02-28  
Goal: Track farm activities, capture evidence, and share best practices using simple WhatsApp messages, driven by AI assist from day one.

## 1) System Overview

This is a practical, low-tech-first operating model:

- Staff send short command-style WhatsApp messages in a single farm operations group.
- Photos are attached as evidence for high-risk/critical events.
- AI assist triages messages, classifies severity, suggests ACK/CLOSED responses, and flags missing evidence.
- Duty manager approves AI suggestions and assigns action.
- Recorder (or AI operator) updates the tracker using AI-generated structured rows.
- AI generates end-of-day summary and weekly best-practice notes for manager review.

No API is required to start.

---

## 1.1) AI Assist Layer (No API Mode)

Use AI in a human-in-the-loop process:

1. Copy WhatsApp incident messages (or exported chat snippet) into AI.
2. Ask AI to return:
  - normalized command rows
  - severity level
  - missing evidence flags
  - suggested ACK/CLOSED texts
3. Manager reviews and posts final replies in WhatsApp.
4. Recorder pastes AI output into daily log sheet.

AI is the decision support engine; manager remains final authority.

---

## 2) Channels and Roles

### WhatsApp Groups

1. Farm Ops Live (all reporting happens here)
2. Farm Leads (manager coordination only)
3. Optional: Best Practices (read-only tips)

### Roles

- Reporter (staff): sends command + evidence
- AI Assistant Operator: runs AI triage/summarization prompts 2–3 times daily
- Duty Manager: approves AI suggestions, acknowledges, classifies severity, assigns owner
- Recorder: updates daily log sheet from AI-structured output
- Reviewer (weekly): validates AI insights and publishes best-practice actions

---

## 3) Command Standard (Simple and Consistent)

Use uppercase command first, then short details.

| Event | Command Format | Example |
|---|---|---|
| Animal looks sick | SICK [animal] [symptoms] + photo | SICK goat limping + photo |
| Animal died | DEAD [animal] [count] | DEAD chicken 1 |
| Broken fence | FENCE BROKEN [location] + photo | FENCE BROKEN near road + photo |
| No water | NO WATER [place] | NO WATER goat pen |
| Eggs collected | EGGS [type] [count] | EGGS chicken 45 |
| Harvest started | HARVEST [crop] [amount] + photo | HARVEST bananas 30 bunches + photo |
| Saw predator | PREDATOR [what] [where] + photo | PREDATOR snake poultry house + photo |
| Animals escaped | ESCAPE [which] [where] | ESCAPE goats roadside |
| Fire | FIRE [location] + photo if safe | FIRE near plot 12 |
| Done with task | DONE [task] + photo when relevant | DONE fixing fence + photo |

Rules:

- Keep one event per message.
- Start with command word.
- Add photo for physical incidents (sick, dead, broken, predator, fire, harvest, done-repair).
- If urgent danger: send command first, then call manager.

---

## 4) Evidence Capture System

## Evidence Required

Priority A (must include photo if safe):
- SICK, DEAD, FENCE BROKEN, PREDATOR, FIRE, HARVEST, DONE (repairs)

Priority B (photo optional):
- NO WATER, ESCAPE, EGGS

## Evidence Quality Checklist

- Wide shot (shows location context)
- Close shot (shows issue detail)
- If possible, include landmark or marker in frame
- Do not alter images

## Acknowledgement Format (Manager)

Manager replies under each incident with:

- ACK [incident-id] [severity] [owner] [ETA]

Example:
- ACK FG-20260228-014 HIGH Peter 30min

Completion reply:
- CLOSED [incident-id] [resolution]

Example:
- CLOSED FG-20260228-014 Fence patched temporary, full repair tomorrow

---

## 5) Simple Record Keeping (No API)

Use one daily sheet (Google Sheet/Excel) with these columns:

1. Incident ID
2. Date
3. Time
4. Reporter
5. Command Type
6. Details
7. Zone/Location
8. Severity (LOW/MEDIUM/HIGH/CRITICAL)
9. Evidence (Yes/No)
10. Owner Assigned
11. ETA
12. Status (OPEN/IN_PROGRESS/CLOSED)
13. Closed Time
14. Resolution Notes
15. Follow-up Needed (Yes/No)

## Daily Process (10–15 minutes per shift)

- Morning: verify unresolved incidents from previous day.
- During day: AI operator runs triage prompt every 2–3 hours; manager ACKs all critical/high incidents quickly.
- End of day: recorder updates sheet from AI-generated structured rows.
- Night: AI drafts short summary and manager posts final version:
  - total incidents
  - critical incidents
  - unresolved items

---

## 6) Measuring Success (Simple KPIs)

Track weekly:

1. Reporting compliance
- Number of command-formatted reports / total reports
- Target: 90%+

2. Evidence completeness
- Incidents requiring photo that include photo
- Target: 95%+

3. Response speed
- Median minutes from report to ACK (critical/high)
- Target: under 10 minutes for critical

4. Closure speed
- Median hours from report to CLOSED by type
- Target: improving trend week to week

5. Repeat incident rate
- Same issue in same zone within 7 days
- Target: decline over time

6. Daily operations reliability
- EGGS and HARVEST reporting consistency by day
- Target: no missing expected days unless explicitly marked

---

## 7) Best Practices Loop

Every Friday (30 minutes):

- Ask AI to identify top 5 incident patterns from weekly log.
- Convert each pattern to one practical rule card:
  - Trigger: what happened
  - Preventive step: what to do earlier
  - Owner: who does it
  - Timing: when to do it
- Manager validates and shares cards in WhatsApp Best Practices group.

Template:

- BEST PRACTICE: [title]
- Trigger: [event pattern]
- Action: [clear step]
- Owner: [role]
- Timing: [exact time/frequency]
- Evidence: [what photo/check proves completion]

---

## 8) Rollout Plan (14 Days)

Day 1–2
- Train all staff on 10 commands
- Pin quick reference message in group

Day 3–5
- Enforce command format + manager ACK format
- Start daily sheet updates

Day 6–10
- Track KPI baseline
- Coach staff on weak command/evidence areas

Day 11–14
- First weekly best-practice review
- Adjust wording or command rules only if needed

---

## 9) Practical Guardrails

- Keep command set small (avoid adding many new commands early).
- Prefer consistency over detail.
- If a report is unclear, manager asks one clarifying question only.
- Use one source of truth for records (daily sheet).
- Never skip ACK for high/critical events.
- AI suggestions are advisory; manager approval is mandatory for critical actions.
- If AI output is uncertain, fall back to manual manager decision immediately.

---

## 10) Future Upgrade Path (Optional, Later)

When ready, add lightweight automation (still simple):

- Export WhatsApp chat daily and parse commands with a script
- Auto-fill the same log format
- Keep human manager approval before closing incidents

This preserves the same command language while reducing manual work.
