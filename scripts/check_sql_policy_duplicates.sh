#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

FILES=(SUPABASE*.sql)

if [[ "${1:-}" == "--include-hotfix" ]]; then
  FILES+=(scripts/supabase_security_hotfix.sql)
fi

echo "Scanning files: ${FILES[*]}"

tmp_all="$(mktemp)"
tmp_dups="$(mktemp)"
trap 'rm -f "$tmp_all" "$tmp_dups"' EXIT

awk '
  BEGIN { IGNORECASE=1 }
  /create policy "/ {
    file = FILENAME
    line = $0
    policy = line
    sub(/^.*create policy "/, "", policy)
    sub(/".*$/, "", policy)
    print policy "|" file
  }
' "${FILES[@]}" > "$tmp_all"

cut -d'|' -f1 "$tmp_all" | sort | uniq -cd | sed -E 's/^ *[0-9]+ //' > "$tmp_dups"

if [[ ! -s "$tmp_dups" ]]; then
  echo "✅ No duplicate policy names found in selected files."
  exit 0
fi

echo "❌ Duplicate policy names found:"
while IFS= read -r policy; do
  echo "- $policy"
  awk -F'|' -v p="$policy" '$1 == p {print "    " $2}' "$tmp_all"
done < "$tmp_dups"

if [[ "${1:-}" == "--include-hotfix" ]]; then
  echo "ℹ️ Includes hotfix file; duplicates there can be intentional override patches."
fi

exit 1
