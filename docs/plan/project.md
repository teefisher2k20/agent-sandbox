# Agent Sandbox Project Plan

## Vision

Make it safe and easy to run AI coding agents in "yolo mode" (auto-approve all actions) by providing locked-down local sandboxes with:
- Minimal filesystem access (repo + scoped state only)
- Restricted outbound network (allowlist-based)
- Reproducible environments (pinned images)

Target: open source project for the developer community, starting with Claude Code support.

## Current State

A working devcontainer exists in `.devcontainer/` that:
- Uses iptables/ipset for network lockdown
- Installs Claude Code in a Debian container
- Runs as non-root user with limited sudo for firewall setup
- Blocks all outbound except allowlisted domains (GitHub, npm, Anthropic, etc.)

Empty scaffolding exists for: images, runtime, CLI, and devcontainer templates.

## Architecture Decisions

**Network enforcement approach:**
- Phase 1: iptables-based (simpler, already working)
- Phase 2: Add proxy option for request-level logging and centralized policy

**Image strategy:**
- Base image with common tools and hardening
- Agent-specific images extend base with only what that agent needs
- Pin by digest, update via PRs

## Milestones

### m1-devcontainer-template

Extract the current `.devcontainer/` into a reusable template that other projects can copy and configure.

**Goals:**
- Parameterize the devcontainer (agent choice, policy profile)
- Create the "minimal" template (iptables-based, no proxy)
- Document usage for new projects
- Test on a fresh project

**Out of scope:**
- Proxy-based template (m5)
- Pre-built images (m2)

### m2-images

Build the image hierarchy so devcontainers use pre-built images instead of building from scratch.

**Goals:**
- Create agent-sandbox-base Dockerfile
- Create agent-sandbox-claude Dockerfile extending base
- Set up GitHub Actions to build and publish images
- Update devcontainer template to use published images
- Pin images by digest

**Dependencies:** m1 (template exists to update)

### m3-cli

Create the `agentbox` CLI for managing sandbox configurations.

**Goals:**
- `agentbox init` - scaffold .devcontainer/ from template
- `agentbox bump` - update image digests to latest
- `agentbox policy` - manage allowlist domains

**Dependencies:** m1 (templates exist), m2 (images to reference)

### m4-multi-agent

Support additional coding agents beyond Claude Code.

**Goals:**
- agent-sandbox-codex image
- agent-sandbox-opencode image
- Agent-specific configuration in templates
- Documentation for adding new agents

**Dependencies:** m2 (image hierarchy established)

### m5-proxy-runtime

Add proxy-based network enforcement as an alternative to iptables.

**Goals:**
- Proxy image (squid or similar with allowlist config)
- Docker Compose stack (agent + proxy)
- Request-level structured logging
- "proxy-locked" devcontainer template
- Policy-as-code in `runtime/policy/`

**Dependencies:** m1, m2, m4

## Decisions

1. **Policy format**: YAML with domain-only granularity for m1-m4. Path/method filtering deferred to m5-proxy-runtime.
2. **CLI language**: Go. Single static binary, no runtime dependencies, easy cross-compilation.
3. **Registry**: GitHub Container Registry (ghcr.io). Free for public repos, native GitHub Actions integration.

## Open Questions

1. **Proxy choice**: Squid? Nginx? Custom Go proxy? Deferred to m5.

## Success Criteria

- A developer can add Agent Sandbox to their project in under 5 minutes
- Network lockdown is verifiable and auditable
- Images are reproducible and easy to update
- Documentation is clear enough for self-service adoption
