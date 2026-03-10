# FarmGenius Security Closeout (2026-03-05)

## Completed

- Supabase canonical SQL sequence applied.
- Supabase security hotfix reapplied (idempotent).
- Verification queries A–D executed successfully.
- SQL duplicate-policy checker added: `scripts/check_sql_policy_duplicates.sh`.
- GitHub Actions workflow added: `.github/workflows/sql-policy-duplicates.yml`.
- CI branch/PR flow tested and merged process validated.

## Current Protection State

- Profile self-insert constrained to `role = 'staff'`.
- Tasks/anomalies insert policies constrained to manager/owner role checks.
- Inventory read policies constrained to authenticated access.
- Duplicate SQL policy drift can now be detected automatically by CI.

## Remaining Operational Actions

1. Enable branch protection for `main` and require status check:
   - `SQL Policy Duplicate Check / check-duplicate-policies`
2. Run final app smoke test by role:
   - Owner: owner home/dashboard access only
   - Manager: manager routes/functions only
   - Staff: staff routes/functions only

## Suggested Evidence to Keep

- PR link for workflow merge.
- Screenshot of required status check in branch protection.
- One short note confirming role smoke-test pass/fail with date.

## Branch Protection Checklist (Main)

Use this path in GitHub:

- Repository `Settings` → `Branches` → `Add branch protection rule`
- Branch name pattern: `main`
- Enable: `Require a pull request before merging`
- Enable: `Require status checks to pass before merging`
- Required check: `SQL Policy Duplicate Check / check-duplicate-policies`
- Optional (recommended): `Include administrators`

Record completion:

- Completed by: __________________
- Date: __________________
- Screenshot saved at: __________________

## Role Smoke Test Checklist

Run the app and validate role isolation and route access.

| Role | Login Works | Correct Home Screen | Restricted Screens Blocked | Notes | Result |
|---|---|---|---|---|---|
| Owner | ☐ | ☐ | ☐ |  | PASS / FAIL |
| Manager | ☐ | ☐ | ☐ |  | PASS / FAIL |
| Staff | ☐ | ☐ | ☐ |  | PASS / FAIL |

Final sign-off:

- Tested by: __________________
- Date: __________________
- Overall result: PASS / FAIL
