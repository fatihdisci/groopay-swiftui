#!/bin/sh

set -eu

REPOSITORY_PATH="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}"
SECRETS_FILE="$REPOSITORY_PATH/Config/Secrets.xcconfig"

: "${SUPABASE_URL:?Add SUPABASE_URL to the Xcode Cloud environment variables.}"
: "${SUPABASE_ANON_KEY:?Add SUPABASE_ANON_KEY to the Xcode Cloud environment variables.}"
: "${REVENUECAT_API_KEY:?Add REVENUECAT_API_KEY to the Xcode Cloud environment variables.}"

# In xcconfig files, an unescaped // starts a comment.
SUPABASE_URL_XCCONFIG=$(printf '%s' "$SUPABASE_URL" | sed 's#://#:/$()/#')

cat > "$SECRETS_FILE" <<EOF
SUPABASE_URL = $SUPABASE_URL_XCCONFIG
SUPABASE_ANON_KEY = $SUPABASE_ANON_KEY
REVENUECAT_API_KEY = $REVENUECAT_API_KEY
EOF
