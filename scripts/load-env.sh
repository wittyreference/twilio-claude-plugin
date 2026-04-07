#!/usr/bin/env bash
# ABOUTME: Lightweight alternative to direnv for platforms that don't support it.
# ABOUTME: Source this file to load .env and unset conflicting Twilio vars.

# Usage: source scripts/load-env.sh

_LOAD_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV_ROOT="$(cd "$_LOAD_ENV_DIR/.." && pwd)"

# Unset inherited Twilio vars to prevent shell contamination (same list as .envrc)
unset TWILIO_ACCOUNT_SID
unset TWILIO_AUTH_TOKEN
unset TWILIO_API_KEY
unset TWILIO_API_SECRET
unset TWILIO_PHONE_NUMBER
unset TWILIO_VERIFY_SERVICE_SID
unset TWILIO_SYNC_SERVICE_SID
unset TWILIO_MESSAGING_SERVICE_SID
unset TWILIO_TASKROUTER_WORKSPACE_SID
unset TWILIO_REGION
unset TWILIO_EDGE

# Load .env
if [ -f "$_LOAD_ENV_ROOT/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$_LOAD_ENV_ROOT/.env"
    set +a
    echo "Loaded .env from $_LOAD_ENV_ROOT"
else
    echo "WARNING: No .env file found at $_LOAD_ENV_ROOT/.env" >&2
fi
