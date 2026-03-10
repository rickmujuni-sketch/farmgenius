# Supabase Security Hardening Runbook

This runbook applies and verifies the FarmGenius Supabase security fixes.

Canonical SQL ownership and execution map:

- [SUPABASE_SQL_CANONICAL_MAP.md](SUPABASE_SQL_CANONICAL_MAP.md)

## Scope

Fixes these high-risk issues:

1. Self-signup role escalation (`owner` / `manager` by client input)
2. Overly permissive insert policies (`with check (true)`-style exposure)
3. Over-broad inventory read access policy

## Execute (Supabase SQL Editor)

Run this file first:

- [scripts/supabase_security_hotfix.sql](scripts/supabase_security_hotfix.sql)

This is idempotent and safe to re-run.

## Recommended order for full environment rebuild

If you are rebuilding policies from scratch, run in this order:

1. [SUPABASE_SETUP.sql](SUPABASE_SETUP.sql)
2. [SUPABASE_RLS_PRODUCTION.sql](SUPABASE_RLS_PRODUCTION.sql)
3. [SUPABASE_ASSET_TRACKING.sql](SUPABASE_ASSET_TRACKING.sql)
4. [SUPABASE_FARM_INTELLIGENCE_ENGINE.sql](SUPABASE_FARM_INTELLIGENCE_ENGINE.sql)
5. [scripts/supabase_security_hotfix.sql](scripts/supabase_security_hotfix.sql)

## Pass criteria

After running, all of these must hold:

- No dangerous permissive policies in verification output
- `profiles` self-insert policies enforce `role = 'staff'`
- `tasks` and `anomalies` insert policies are role-restricted
- `inventory_items` select policies require authenticated context

## App runtime requirement

App now requires `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `--dart-define` (no hardcoded anon key fallback).

Example:

`flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon-key>`
