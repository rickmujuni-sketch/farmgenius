# WhatsApp Farm Ops Quick Reference

Use these exact message styles in Farm Ops Live group.

## Commands

- SICK [animal] [symptoms] + photo
- DEAD [animal] [count]
- FENCE BROKEN [location] + photo
- NO WATER [place]
- EGGS [type] [count]
- HARVEST [crop] [amount] + photo
- PREDATOR [what] [where] + photo
- ESCAPE [which] [where]
- FIRE [location] (+ photo if safe)
- DONE [task] + photo (for repairs/field work)

## Examples

- SICK goat limping + photo
- DEAD chicken 1
- FENCE BROKEN near road + photo
- NO WATER goat pen
- EGGS chicken 45
- HARVEST bananas 30 bunches + photo
- PREDATOR snake poultry house + photo
- ESCAPE goats roadside
- FIRE near plot 12
- DONE fixing fence + photo

## Manager Response Format

- ACK [incident-id] [severity] [owner] [ETA]
- CLOSED [incident-id] [resolution]

Example:
- ACK FG-20260228-014 HIGH Peter 30min
- CLOSED FG-20260228-014 Temporary fix complete, permanent repair tomorrow

## AI Assist (No API)

Run AI support 2–3 times daily using copied WhatsApp messages.

Ask AI for:

- Incident normalization table (ID, command, zone, severity, owner, status)
- Missing evidence list (which incident needs photo/details)
- Suggested ACK lines for open high/critical incidents
- End-of-day summary draft (totals, unresolved, urgent next actions)

## Severity Guide

- CRITICAL: FIRE, major ESCAPE, severe disease signs, security breach
- HIGH: DEAD, FENCE BROKEN, PREDATOR, NO WATER for animals
- MEDIUM: SICK single animal, delayed HARVEST risk
- LOW: routine DONE update

## Golden Rules

- One event per message
- Start with command word
- Add photo for physical incidents
- If danger is immediate: send message, then call manager
