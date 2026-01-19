# Learnings

Lessons learned during project execution. Review at the start of each planning session.

## Technical

- iptables rules must preserve Docker's internal DNS resolution (127.0.0.11 NAT rules) or container DNS breaks
- `aggregate` tool is useful for collapsing GitHub's many IP ranges into fewer CIDR blocks
- VS Code devcontainers need `--cap-add=NET_ADMIN` and `--cap-add=NET_RAW` for iptables to work

## Process

(none yet)
