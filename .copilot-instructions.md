# Copilot Instructions

## Project Overview

This is a **Proxmox Homelab IaC** project that provides an observability stack (LGTM: Loki, Grafana, Tempo, Prometheus) with OpenTelemetry Collector integration, Docker Compose configuration, and automation scripts.

## Language Policy

**📝 All documentation must be in English:**
- README.md files
- Code comments (for clarity)
- Commit messages (for consistency)
- Issue descriptions and pull request titles
- Configuration documentation
- Script comments and docstrings

**🗣️ Code can be in any language, but prefer English for variables and function names.**

## Code Style & Conventions

### Bash/Shell Scripts
- Use `#!/usr/bin/env bash` shebang for cross-platform compatibility
- Include error handling with `set -euo pipefail`
- Add script headers with description and usage examples
- Use meaningful variable names in UPPERCASE for constants
- Add comments for complex logic
- Always test on both Bash and Zsh

### Python Scripts
- Follow PEP 8 style guide
- Use type hints for function arguments and returns
- Include docstrings for modules, classes, and functions
- Use `#!/usr/bin/env python3` shebang

### Docker & Compose
- Keep docker-compose.yml organized and well-commented
- Use named volumes for persistence (not bind mounts to `/data`)
- Include healthchecks where applicable
- Document environment variables with examples in `.env.example`

### YAML Configuration Files
- Add headers explaining what the file does
- Include inline comments for non-obvious settings
- Use consistent indentation (2 or 4 spaces, not tabs)
- Keep logical groupings (inputs, processors, exporters)

## Documentation Requirements

### README Files
**Every major component should have a README.md in English** with:
1. **Overview** - What does this do?
2. **Features** - What are the main capabilities?
3. **Usage** - How to use it (examples required)
4. **Configuration** - How to configure it
5. **Directory Structure** - If applicable
6. **Troubleshooting** - Common issues and solutions

### Code Documentation
- Add headers to scripts explaining purpose and usage
- Include examples in comments
- Document non-obvious algorithms
- Keep comments up-to-date with code changes

### Configuration Files
- Add comments explaining sections
- Document environment variables
- Include examples for common configurations
- Explain what each setting does

## File Organization

```
<root-folder>/
├── README.md                    # Project overview (ENGLISH)
├── CLAUDE.md                    # Claude-specific instructions
├── .env.example                 # Example environment variables
├── docker-compose.yml           # Main compose file
├── scripts/
│   ├── update-service-versions.sh
│   └── README.md               # Script documentation (ENGLISH)
└── observability/
    ├── loki/config.yml
    ├── tempo/config.yml
    ├── prometheus/prometheus.yml
    ├── otel-collector/config.yml
    └── grafana/provisioning/
```

## Git Commit Messages

**Format:** `<type>: <subject>`

Types:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Tests
- `chore:` Build, deps, tooling

Examples:
- `feat: add update-service-versions script for docker-compose`
- `docs: update observability stack README in English`
- `fix: correct Prometheus YAML configuration for Tempo metrics`

## Pull Requests

**Always include:**
1. Clear description of changes
2. Reason for the change
3. Steps to test (if applicable)
4. Screenshots/logs (if UI changes)
5. Documentation updates

## Architecture Decisions

### Volumes
- Use Docker **named volumes** for persistence (not bind mounts)
- Format: `service_data:/container/path`
- Ensures portability across environments

### Networking
- All services on `observability-network` (bridge)
- External stacks can attach with `external: true`
- Use service names for internal communication

### Configuration
- Self-contained in docker-compose.yml with sensible defaults
- Optional `.env` for environment-specific overrides
- Use `${VAR_NAME:-default}` syntax for fallbacks

## Automation & Scripts

### New Script Guidelines
1. Add `#!/usr/bin/env bash` shebang
2. Include error handling (`set -euo pipefail`)
3. Add script header with description and usage
4. Support both `bash` and `zsh`
5. Test before committing
6. Create corresponding README.md documentation (in English)
7. Add to this instructions file if it's a significant utility

### Existing Utilities
- **update-service-versions.sh** - Check and update docker-compose service versions
  - Supports dry-run (default) and --apply modes
  - Creates automatic backups
  - See: `scripts/README.md`

## Testing Requirements

Before committing:
1. ✅ Validate docker-compose.yml syntax: `docker compose config`
2. ✅ Test scripts on both bash and zsh
3. ✅ Verify all services start: `docker compose up -d`
4. ✅ Check service health: `docker compose ps`
5. ✅ Review logs: `docker compose logs -f <service>`
6. ✅ Test configuration changes don't break services

## Common Pitfalls to Avoid

- ❌ Don't use bind mounts to `/data` - use named volumes
- ❌ Don't commit `.env` files - use `.env.example` with defaults
- ❌ Don't mix English and Portuguese in documentation
- ❌ Don't skip error handling in scripts
- ❌ Don't document in Portuguese - use English
- ❌ Don't modify docker-compose.yml directly - use environment variables

## When Adding New Services

1. Create config file in `observability/<service>/config.yml`
2. Add to `docker-compose.yml` with:
   - Named volume for persistence
   - Healthcheck if applicable
   - Port mapping with env var override
3. Update README.md with service details
4. Test full stack: `docker compose up -d`
5. Verify logs: `docker compose logs <service>`

## Useful Commands

```bash
# Validate compose file
docker compose config

# Start services
docker compose up -d

# View all services
docker compose ps

# View logs
docker compose logs -f <service>

# Check service health
curl http://localhost:3000/api/health

# Update service versions
./scripts/update-service-versions.sh --apply

# Reload Prometheus config
curl -X POST http://localhost:9090/-/reload
```

## Questions?

Refer to:
- `/README.md` - Project overview
- `/scripts/README.md` - Script documentation
- `docker-compose.yml` - Service configuration
- `./observability/<service>/config.yml` - Individual service settings
