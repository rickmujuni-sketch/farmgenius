# Farm Weekly KPI — How To Calculate

Use this guide with:
- FARM_WEEKLY_KPI_TRACKER_TEMPLATE.csv
- FARM_DAILY_LOG_TEMPLATE.csv

Keep calculations simple and consistent each week.

## 1) Define the Week

- Week Start: Monday date
- Week End: Sunday date
- Include only incidents reported within this date range

## 2) Core Counts

From the daily log, count:

- Total Incidents = all incident rows in week
- Critical Incidents = rows where Severity = CRITICAL
- High Incidents = rows where Severity = HIGH
- Open Incidents End of Week = rows with Status not CLOSED by week end

## 3) Evidence KPIs

- Incidents With Required Evidence = rows where Evidence Required = Yes
- Incidents With Evidence Attached = rows where Evidence Attached = Yes and Evidence Required = Yes
- Evidence Completion % = (With Evidence Attached / With Required Evidence) × 100

If denominator is 0, set Evidence Completion % = 100.

## 4) ACK Speed KPI

For Critical + High incidents only:

- ACK Minutes for one incident = minutes between report time and manager ACK time
- Median ACK Minutes = median of all ACK Minutes values in week

Tip: if ACK time is not in the log yet, add a column in your daily sheet: ACK Time.

## 5) Closure KPIs

- Close Hours for one incident = hours between report time and closed time
- Median Close Hours (All) = median of all closed incidents in week

- Incidents Closed Within SLA = count of incidents meeting your SLA target
- Closure SLA % = (Closed Within SLA / Total Closed Incidents) × 100

Set clear SLAs, example:
- Critical: 2 hours
- High: 8 hours
- Medium: 24 hours
- Low: 48 hours

## 6) Repeat Incident KPIs

- Repeat Incident = same Command Type + same Zone/Location occurring again within 7 days
- Repeat Incidents = count of repeated cases
- Repeat Incident Rate % = (Repeat Incidents / Total Incidents) × 100

## 7) Reporting Compliance KPIs

- Daily Reporting Compliance % = (Days with expected report submitted / Expected days) × 100

Egg reporting:
- Egg Reporting Days Expected = number of days eggs should be reported in week
- Egg Reporting Days Received = number of days EGGS entry exists
- Egg Reporting Compliance % = (Received / Expected) × 100

Harvest reporting:
- Harvest Reporting Days Expected = planned harvest-reporting days
- Harvest Reporting Days Received = days HARVEST entry exists
- Harvest Reporting Compliance % = (Received / Expected) × 100

If Expected = 0, set compliance = 100.

## 8) Top 3 Incident Types and Zones

- Top 3 Incident Types = most frequent Command Type values in week
- Top 3 Incident Zones = most frequent Zone/Location values in week

Format:
- "FENCE BROKEN; NO WATER; SICK"
- "Plot 12; Goat Pen; Poultry House"

## 9) Weekly Notes / Actions

In Notes/Actions, write 2–4 practical actions for next week:

- What pattern happened?
- What preventive step will be done?
- Who owns it?
- By when?

Example:
- "Increase fence check at road-side boundary every morning 07:00, owner: Peter."

## 10) Quick Quality Rules

Before finalizing weekly row:

- All percentages between 0 and 100
- No missing Week Start/Week End
- Open incidents count matches daily log
- Notes/Actions include owner + timing
