#!/bin/bash
set -euo pipefail

# agentbox auth - Securely authenticate Claude Code inside a locked-down container
#
# This script temporarily relaxes the container firewall to allow the OAuth
# callback, runs `claude setup-token`, captures the token, and stores it in
# the macOS keychain for use by devcontainers.

CONTAINER_PATTERN="${1:-agent-sandbox}"
FIREWALL_RULE_COMMENT="agentbox-oauth-temp"
KEYCHAIN_SERVICE="agentbox-claude-token"
KEYCHAIN_ACCOUNT="oauth"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[agentbox]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[agentbox]${NC} $1"; }
log_error() { echo -e "${RED}[agentbox]${NC} $1"; }

# Find the container by exact name
# Sets CONTAINER global variable
find_container() {
    local name="$1"
    CONTAINER=""

    # Get all running containers
    while IFS=$'\t' read -r id cname; do
        if [[ "$cname" == "$name" ]]; then
            CONTAINER="$id"
            break
        fi
    done < <(docker ps --format "{{.ID}}\t{{.Names}}" 2>/dev/null || true)

    if [[ -z "$CONTAINER" ]]; then
        log_error "No running container found with name: $name" >&2
        log_error "" >&2
        log_error "Running containers:" >&2
        docker ps --format "  {{.Names}}" 2>/dev/null || true
        return 1
    fi

    return 0
}

# Check if firewall rule exists
firewall_rule_exists() {
    local container="$1"
    docker exec -u root "$container" iptables -C INPUT -j ACCEPT -m comment --comment "$FIREWALL_RULE_COMMENT" 2>/dev/null
}

# Relax firewall for OAuth
relax_firewall() {
    local container="$1"
    log_info "Relaxing firewall for OAuth callback..."
    docker exec -u root "$container" iptables -I INPUT 1 -j ACCEPT -m comment --comment "$FIREWALL_RULE_COMMENT"
}

# Re-lock firewall
lock_firewall() {
    local container="$1"
    if firewall_rule_exists "$container"; then
        log_info "Re-locking firewall..."
        docker exec -u root "$container" iptables -D INPUT -j ACCEPT -m comment --comment "$FIREWALL_RULE_COMMENT"
    fi
}

# Store token in macOS keychain
store_token() {
    local token="$1"
    log_info "Storing token in macOS keychain..."
    # Delete existing entry if present, then add new one
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1 || true
    security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w "$token" >/dev/null 2>&1
}

# Check if token exists in keychain
token_exists() {
    security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w >/dev/null 2>&1
}

# Cleanup on exit (ensure firewall is re-locked)
cleanup() {
    local exit_code=$?
    if [[ -n "${CONTAINER:-}" ]]; then
        lock_firewall "$CONTAINER"
    fi
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Main
main() {
    log_info "Finding container..."
    if ! find_container "$CONTAINER_PATTERN"; then
        exit 1
    fi
    log_info "Found container: $CONTAINER"

    # Check if token already exists in keychain
    if token_exists; then
        log_warn "A Claude token already exists in the keychain."
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted."
            exit 0
        fi
    fi

    relax_firewall "$CONTAINER"

    log_info "Starting OAuth flow..."
    log_info "1. Copy the URL and open it in your browser"
    log_info "2. Authorize the application"
    log_info "3. Paste the authorization code when prompted"
    echo

    # Run setup-token and capture output to a temp file
    temp_output=$(mktemp)
    trap "rm -f $temp_output" EXIT

    set +e
    docker exec -it "$CONTAINER" zsh -i -c 'claude setup-token' 2>&1 | tee "$temp_output"
    login_exit_code=$?
    set -e

    echo

    if [[ $login_exit_code -ne 0 ]]; then
        log_error "OAuth failed with exit code: $login_exit_code"
        exit 1
    fi

    # Extract token from output
    # Strip ANSI codes and newlines, then extract token up to "Store"
    token=$(sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$temp_output" | \
        tr -d '\n\r' | \
        sed -n 's/.*\(sk-ant-[a-zA-Z0-9_-]*\)Store.*/\1/p')

    if [[ -z "$token" ]]; then
        log_error "Failed to extract token from output."
        exit 1
    fi

    store_token "$token"

    log_info "Authentication successful."
    log_info "Token stored in keychain as '$KEYCHAIN_SERVICE'"
    log_info ""
    log_info "To use in devcontainer, add to your devcontainer.json:"
    log_info '  "initializeCommand": "echo CLAUDE_CODE_OAUTH_TOKEN=$(security find-generic-password -s agentbox-claude-token -a oauth -w) > .devcontainer/.env",'
    log_info '  "containerEnv": { "CLAUDE_CODE_OAUTH_TOKEN": "${localEnv:CLAUDE_CODE_OAUTH_TOKEN}" }'
    log_info ""
    log_info "Done."
}

main "$@"
