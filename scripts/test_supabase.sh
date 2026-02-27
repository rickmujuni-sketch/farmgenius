#!/usr/bin/env bash
# simple script to test Supabase auth token and profiles endpoint
set -e
if [[ -z "$ANON_KEY" ]]; then
echo "Please set ANON_KEY environment variable to your anon public key" >&2
exit 1
fi
if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
echo "Usage: EMAIL=owner@example.com PASSWORD=secret $0" >&2
exit 1
fi

echo "requesting token for $EMAIL"
resp=$(curl -s -X POST "https://hrtlaxxzsewcnjvthsct.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
echo "response: $resp"

access=$(echo "$resp" | jq -r .access_token)
if [[ "$access" == "null" || -z "$access" ]]; then
echo "failed to obtain access token" >&2
exit 2
fi

echo "got access token, querying profiles"
curl -s "https://hrtlaxxzsewcnjvthsct.supabase.co/rest/v1/profiles" \
  -H "Authorization: Bearer $access" \
  -H "apikey: $ANON_KEY" \
  -H "Accept: application/json" | jq .
