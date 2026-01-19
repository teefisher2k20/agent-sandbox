# m1-devcontainer-template

Extract the current `.devcontainer/` into a reusable template that other projects can copy and configure.

## Goals

- Split Dockerfile into base + claude images
- Define policy YAML schema for domain allowlists
- Extract hardcoded domains to policy file
- Create the "minimal" template (iptables-based, no proxy)
- Document usage for new projects
- Test on a fresh project

## Out of Scope

- Publishing images to GHCR (m2)
- CLI tooling (m3)
- Proxy-based network control (m5)

## Policy Schema

Decided: Option B with services and domains sections.

```yaml
# policy.yaml
services:
  - github  # known service with special handling (fetches from api.github.com/meta)

domains:
  - registry.npmjs.org
  - api.anthropic.com
  - sentry.io
  - statsig.anthropic.com
  - statsig.com
```

The firewall script has handlers for known services. Plain domains get DNS resolution at startup.

## Image Structure

```
images/
├── base/
│   └── Dockerfile          # Tools, firewall, zsh - no agent
└── agents/
    └── claude/
        └── Dockerfile      # FROM base, adds Claude Code
```

The base image includes everything needed for sandboxed development except the agent itself.

## Template Structure

Templates are organized by network approach, then by agent:

```
devcontainer/templates/
├── minimal/                    # iptables-based network control
│   ├── README.md               # Docs for minimal approach
│   └── claude/
│       ├── .devcontainer/
│       │   ├── devcontainer.json
│       │   ├── Dockerfile      # FROM agent-sandbox-claude (or builds locally)
│       │   ├── policy.yaml     # User-customizable allowlist
│       │   └── init-firewall.sh
│       └── README.md           # Claude-specific notes
└── proxy-locked/               # m5: proxy-based network control
    └── claude/
        └── ...
```

For m1, we create `minimal/claude/`. Other agents (codex, opencode) added in m4.

## Tasks

### m1.1-policy-schema

Define the YAML schema for policy files.

- Create example policy.yaml with services + domains structure
- Document the schema (what services are supported, domain format)

### m1.2-split-images

Split current Dockerfile into base + claude.

- Create images/base/Dockerfile with tools, firewall deps, zsh
- Create images/agents/claude/Dockerfile extending base with Claude Code
- Verify both build successfully

### m1.3-extract-policy

Extract domains from init-firewall.sh to policy.yaml.

- Create policy.yaml with current allowlist
- Keep init-firewall.sh working (reads from policy.yaml)

### m1.4-firewall-reads-policy

Update init-firewall.sh to parse policy.yaml.

- Add YAML parsing (yq or simple grep/awk)
- Handle "services" section (github-meta lookup)
- Handle "domains" section (DNS resolution)
- Maintain existing verification checks

### m1.5-create-template

Create the minimal/claude template structure.

- Set up devcontainer/templates/minimal/claude/.devcontainer/
- Include devcontainer.json, Dockerfile, policy.yaml, init-firewall.sh
- Template Dockerfile references local image build or placeholder for GHCR

### m1.6-template-docs

Document template usage.

- README with quickstart (copy to project, customize policy, open in devcontainer)
- Document policy customization (adding domains, removing services)
- Document testing/verification steps

### m1.7-test-template

Validate template on a fresh project.

- Copy template to a test project outside this repo
- Verify devcontainer builds and starts
- Verify firewall blocks unauthorized domains
- Verify allowed domains work

## Dependencies

None (first milestone)

## Definition of Done

- [ ] Base and claude Dockerfiles exist and build
- [ ] Policy YAML schema defined and documented
- [ ] Firewall script reads from policy file
- [ ] Template in devcontainer/templates/minimal/ is complete
- [ ] README documents usage
- [ ] Template tested on fresh project
