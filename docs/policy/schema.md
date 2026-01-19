# Policy Schema

Policy files configure sandbox restrictions for agent-sandbox containers. Currently supports outbound network allowlists, with future support planned for ingress rules, port forwarding, and mount restrictions.

## Format

```yaml
egress:
  services:
    - claude-code
    - github
    - vscode
  domains:
    - registry.npmjs.org
    - your-internal-api.example.com

# Future sections (not yet implemented):
# ingress:
#   ports: [8080, 3000]
# mounts:
#   readonly: [~/.ssh]
#   blocked: [~/.aws/credentials]
```

## Egress

Controls outbound network traffic. The firewall blocks all outbound except to destinations listed here.

### egress.services

A list of predefined service names. Each service expands to a set of domains with appropriate resolution logic.

| Service | Domains | Notes |
|---------|---------|-------|
| `claude-code` | Anthropic API and telemetry | api.anthropic.com, sentry.io, statsig.anthropic.com, statsig.com |
| `github` | GitHub web, API, and git endpoints | IPs fetched from api.github.com/meta and aggregated into CIDR blocks |
| `vscode` | VS Code marketplace and telemetry | marketplace.visualstudio.com, mobile.events.data.microsoft.com, vscode.blob.core.windows.net, update.code.visualstudio.com |

### egress.domains

A list of additional domain names to allow. Each domain is resolved via DNS at container startup, and the resulting IPs are added to the allowlist.

Use this for:
- Package registries (e.g., registry.npmjs.org, pypi.org)
- Internal APIs your project needs
- Any domain not covered by a service

## Examples

### Minimal policy (Claude Code only)

```yaml
egress:
  services:
    - claude-code
    - github
```

### With VS Code devcontainer support

```yaml
egress:
  services:
    - claude-code
    - github
    - vscode
```

### Adding project-specific domains

```yaml
egress:
  services:
    - claude-code
    - github
    - vscode
  domains:
    - api.stripe.com          # payment processing
    - pypi.org                # Python packages
    - registry.npmjs.org      # npm packages
```

## How It Works

At container startup, `init-firewall.sh` reads the policy file and:

1. For each service in `egress.services`, resolves the associated domains (or fetches IP ranges for github)
2. For each domain in `egress.domains`, performs DNS resolution
3. Adds all IPs to an ipset
4. Configures iptables to allow only traffic to IPs in the set
5. Verifies the firewall by checking that example.com is blocked

Changes to the policy require rebuilding the container.
