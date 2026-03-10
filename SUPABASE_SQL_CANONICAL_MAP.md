# Supabase SQL Canonical Map

This file defines the single source-of-truth SQL ownership to avoid drift.

## Canonical (active) files

1. [SUPABASE_SETUP.sql](SUPABASE_SETUP.sql)
   - Base schema (core tables, indexes, initial policies)

2. [SUPABASE_RLS_PRODUCTION.sql](SUPABASE_RLS_PRODUCTION.sql)
   - Canonical role helper functions
   - Strict production RLS policy layer

3. [SUPABASE_ASSET_TRACKING.sql](SUPABASE_ASSET_TRACKING.sql)
   - Asset tracking schema/policies
   - Depends on helper functions from `SUPABASE_RLS_PRODUCTION.sql`

4. [SUPABASE_FARM_INTELLIGENCE_ENGINE.sql](SUPABASE_FARM_INTELLIGENCE_ENGINE.sql)
   - Intelligence engine schema/policies/functions
   - Depends on helper functions from `SUPABASE_RLS_PRODUCTION.sql`

5. [scripts/supabase_security_hotfix.sql](scripts/supabase_security_hotfix.sql)
   - One-time patch for already-running environments
   - Intentionally redefines a small subset of policy names to force hardened checks

## Important note on “duplicates”

Policy-name overlap between canonical files and `scripts/supabase_security_hotfix.sql` is intentional.
It is an override patch, not a second source of truth.

When assessing duplication, treat the hotfix file as operational patching only.

## Safe execution order

1. [SUPABASE_SETUP.sql](SUPABASE_SETUP.sql)
2. [SUPABASE_RLS_PRODUCTION.sql](SUPABASE_RLS_PRODUCTION.sql)
3. [SUPABASE_ASSET_TRACKING.sql](SUPABASE_ASSET_TRACKING.sql)
4. [SUPABASE_FARM_INTELLIGENCE_ENGINE.sql](SUPABASE_FARM_INTELLIGENCE_ENGINE.sql)
5. [scripts/supabase_security_hotfix.sql](scripts/supabase_security_hotfix.sql)
