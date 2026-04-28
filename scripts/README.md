# Update Service Versions Script

Automated script to check and update service versions in `docker-compose.yml`.

## 📋 Features

- ✅ Checks latest stable versions via GitHub API and Docker Hub
- ✅ **Dry-run mode** (default) - shows what would be updated
- ✅ **--apply mode** - updates automatically
- ✅ **Automatic backups** with timestamp before updating
- ✅ Supports **GITHUB_TOKEN** to increase API rate limit
- ✅ Works on **Bash and Zsh**
- ✅ Colorful and intuitive output

## 🚀 Usage

### Check for available updates (dry-run)

```bash
./scripts/update-service-versions.sh
```

### Apply updates

```bash
./scripts/update-service-versions.sh --apply
```

### With detailed output

```bash
./scripts/update-service-versions.sh --verbose
./scripts/update-service-versions.sh --apply --verbose
```

### Skip backup

```bash
./scripts/update-service-versions.sh --apply --skip-backup
```

## 📊 Example Output

### Check (dry-run)

```
═══════════════════════════════════════════════════
 Docker Compose Version Checker
═══════════════════════════════════════════════════

ℹ GitHub token detected (rate limit: 5000 req/hour)

Checking Loki... ✓ Up to date (3.6.4)
Checking Tempo... ⚠ Update available: 2.10.0 → 2.11.0
Checking Prometheus... ✓ Up to date (v3.9.1)
Checking OTEL Collector... ⚠ Update available: 0.144.0 → 0.145.0
Checking Grafana... ✓ Up to date (12.3.2)

═══════════════════════════════════════════════════
 Summary
═══════════════════════════════════════════════════

Service              Current              Latest               Status         
===========================================================================
Loki                 3.6.4                3.6.4                ✓ Up to date   
Tempo                2.10.0               2.11.0               ⚠ Outdated     
Prometheus           v3.9.1               v3.9.1               ✓ Up to date   
OTEL Collector       0.144.0              0.145.0              ⚠ Outdated     
Grafana              12.3.2               12.3.2               ✓ Up to date   

⚠ Updates available! Run with --apply to update docker-compose.yml

Command:
  ./scripts/update-service-versions.sh --apply
```

### Applying updates

```
═══════════════════════════════════════════════════
 Applying Updates
═══════════════════════════════════════════════════

→ Creating backup...
✓ Backup created: docker-compose.yml.backup.20260428_145630

→ Updating Tempo: 2.10.0 → 2.11.0...
✓ Updated Tempo

→ Updating OTEL Collector: 0.144.0 → 0.145.0...
✓ Updated OTEL Collector

✓ Updated 2 service(s)

Next steps:
  1. Review changes: git diff docker-compose.yml
  2. Pull new images: docker compose pull
  3. Restart services: docker compose up -d
  4. Test thoroughly before committing
```

## 🔐 GitHub Token (Optional)

To increase the rate limit from 60 to 5000 requests per hour:

```bash
export GITHUB_TOKEN=ghp_your_token_here
./scripts/update-service-versions.sh
```

Generate a token at: https://github.com/settings/tokens

## 📝 Monitored Services

| Service | Current Version | Type |
|---------|-----------------|------|
| Loki | 3.6.4 | GitHub |
| Tempo | 2.10.0 | GitHub |
| Prometheus | v3.9.1 | GitHub |
| OTEL Collector | 0.144.0 | GitHub |
| Grafana | 12.3.2 | GitHub |

## 🔄 Recommended Workflow

```bash
# 1. Check for updates
./scripts/update-service-versions.sh

# 2. If updates available, apply them
./scripts/update-service-versions.sh --apply

# 3. Review changes
git diff docker-compose.yml

# 4. Test locally
docker compose pull
docker compose up -d

# 5. Check logs
docker compose logs -f

# 6. Commit if all is good
git add docker-compose.yml
git commit -m "Update service versions: Tempo, OTEL Collector"
```

## 🛠️ Requirements

- `bash` or `zsh`
- `curl` (for API calls)
- `sed` (for file updates)
- `jq` (optional - improves JSON parsing performance)

## 💾 Backup Management

Backups are created automatically in:
```
docker-compose.yml.backup.YYYYMMDD_HHMMSS
```

To restore from backup:
```bash
cp docker-compose.yml.backup.20260428_145630 docker-compose.yml
```

## 🐛 Troubleshooting

### "docker-compose.yml not found"

Make sure you're in the project root directory:
```bash
cd /home/devuser/projects/proxmox-homelab-iac
./scripts/update-service-versions.sh
```

### "Failed to get GitHub release"

1. Check internet connection
2. Verify the repository exists
3. If you hit rate limit, use `GITHUB_TOKEN`

### jq not installed

The script works without `jq`, but it's slower. To install:

```bash
# Debian/Ubuntu
sudo apt install jq

# macOS
brew install jq
```

## 📄 License

Based on the PowerShell script from the Proxmox VE community.
