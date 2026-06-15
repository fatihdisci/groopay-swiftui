#!/bin/sh

set -eu

REPOSITORY_PATH="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}"
SECRETS_FILE="$REPOSITORY_PATH/Config/Secrets.xcconfig"

: > "$SECRETS_FILE"

if [ -n "${SUPABASE_URL:-}" ]; then
    # In xcconfig files, an unescaped // starts a comment.
    SUPABASE_URL_XCCONFIG=$(printf '%s' "$SUPABASE_URL" | sed 's#://#:/$()/#')
    printf 'SUPABASE_URL = %s\n' "$SUPABASE_URL_XCCONFIG" >> "$SECRETS_FILE"
fi

if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
    printf 'SUPABASE_ANON_KEY = %s\n' "$SUPABASE_ANON_KEY" >> "$SECRETS_FILE"
fi

if [ -n "${REVENUECAT_API_KEY:-}" ]; then
    printf 'REVENUECAT_API_KEY = %s\n' "$REVENUECAT_API_KEY" >> "$SECRETS_FILE"
fi
