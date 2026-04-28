#!/usr/bin/env bash
# =====================================================
# Update Docker Compose Service Versions
# =====================================================
# Checks for latest stable versions of all services in docker-compose.yml
# and optionally updates them automatically.
#
# Usage:
#   ./update-service-versions.sh              # Check only (dry-run)
#   ./update-service-versions.sh --apply      # Apply updates
# =====================================================

set -euo pipefail

# =====================================================
# Configuration
# =====================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$PROJECT_ROOT/docker-compose.yml.backup.$BACKUP_TIMESTAMP"

# Flags
APPLY_UPDATES=0
SKIP_BACKUP=0
VERBOSE=0

# Parse arguments
while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        --apply)
            APPLY_UPDATES=1
            ;;
        --skip-backup)
            SKIP_BACKUP=1
            ;;
        --verbose|-v)
            VERBOSE=1
            ;;
    esac
    shift || true
done

# =====================================================
# Colors for output
# =====================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =====================================================
# Output Functions
# =====================================================

write_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN} ${1}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
}

write_step() {
    echo -e "${YELLOW}→${NC} ${1}"
}

write_success() {
    echo -e "${GREEN}✓${NC} ${1}"
}

write_warning() {
    echo -e "${YELLOW}⚠${NC} ${1}"
}

write_error() {
    echo -e "${RED}✗${NC} ${1}"
}

write_verbose() {
    if [[ ${VERBOSE} -eq 1 ]]; then
        echo -e "${CYAN}ℹ${NC} ${1}"
    fi
}

# =====================================================
# API Functions
# =====================================================

get_github_latest_release() {
    local repo="${1}"
    local attempt=1
    local max_retries=3
    local retry_delay=1

    while [[ ${attempt} -le ${max_retries} ]]; do
        write_verbose "GitHub API: ${repo} (attempt ${attempt}/${max_retries})"

        local headers="-H 'Accept: application/vnd.github.v3+json' -H 'User-Agent: bash-version-checker/1.0'"

        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            headers="${headers} -H 'Authorization: token ${GITHUB_TOKEN}'"
        fi

        local response
        response=$(eval "curl -s -f ${headers} 'https://api.github.com/repos/${repo}/releases/latest' 2>/dev/null" || echo "")

        if [[ -n "${response}" ]]; then
            local tag_name
            if command -v jq &> /dev/null; then
                tag_name=$(echo "${response}" | jq -r '.tag_name // empty' 2>/dev/null || echo "")
            else
                tag_name=$(echo "${response}" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
            fi

            if [[ -n "${tag_name}" ]]; then
                echo "${tag_name#v}"
                return 0
            fi
        fi

        if [[ ${attempt} -lt ${max_retries} ]]; then
            sleep "${retry_delay}"
            retry_delay=$((retry_delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    write_verbose "Failed to get GitHub release for ${repo} after ${max_retries} attempts"
    return 1
}

# =====================================================
# Version Comparison
# =====================================================

get_current_tag() {
    local image_base="${1}"
    local tag

    tag=$(grep "image:.*${image_base}:" "${COMPOSE_FILE}" | head -1 | sed "s/.*${image_base}://; s/[[:space:]]*$//" || echo "")

    if [[ -n "${tag}" ]]; then
        echo "${tag}"
        return 0
    fi

    return 1
}

compare_versions() {
    local current="${1}"
    local latest="${2}"

    if [[ "${current}" == "${latest}" ]]; then
        echo "UpToDate"
        return 0
    fi

    # Simple semantic versioning comparison
    local current_clean latest_clean
    current_clean=$(echo "${current}" | sed 's/^v//')
    latest_clean=$(echo "${latest}" | sed 's/^v//')

    # Split versions and compare
    local -a current_parts=( $(echo "${current_clean}" | tr '.' ' ' || echo "0") )
    local -a latest_parts=( $(echo "${latest_clean}" | tr '.' ' ' || echo "0") )

    local max_parts
    if [[ ${#latest_parts[@]} -gt ${#current_parts[@]} ]]; then
        max_parts=${#latest_parts[@]}
    else
        max_parts=${#current_parts[@]}
    fi

    for ((i=0; i<max_parts; i++)); do
        local curr="${current_parts[$i]:-0}"
        local late="${latest_parts[$i]:-0}"

        # Remove non-numeric characters for comparison
        curr="${curr//[^0-9]/}"
        late="${late//[^0-9]/}"

        if [[ -z "${curr}" ]]; then curr="0"; fi
        if [[ -z "${late}" ]]; then late="0"; fi

        if [[ ${late} -gt ${curr} ]]; then
            echo "Outdated"
            return 0
        elif [[ ${late} -lt ${curr} ]]; then
            echo "Ahead"
            return 0
        fi
    done

    echo "UpToDate"
    return 0
}

# =====================================================
# Update Functions
# =====================================================

update_compose_file() {
    local image_base="${1}"
    local new_tag="${2}"

    # Use sed to replace the image tag (escape special characters)
    local escaped_base
    escaped_base=$(echo "${image_base}" | sed 's/[\/&]/\\&/g')

    sed -i.bak "s|image:.*${escaped_base}:.*|image: ${image_base}:${new_tag}|" "${COMPOSE_FILE}"
}

# =====================================================
# Main Script
# =====================================================

if [[ ! -f "${COMPOSE_FILE}" ]]; then
    write_error "docker-compose.yml not found at: ${COMPOSE_FILE}"
    exit 1
fi

write_header "Docker Compose Version Checker"

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo -e "${CYAN}ℹ${NC} GitHub token detected (rate limit: 5000 req/hour)"
else
    echo -e "${YELLOW}ℹ${NC} No GitHub token found (rate limit: 60 req/hour). To increase: export GITHUB_TOKEN=your_token"
fi

echo ""

# Services to check
# Format: "Display Name|Image Base|Default Version|GitHub Repo"
declare -a SERVICES=(
    "Loki|grafana/loki|3.6.4|grafana/loki"
    "Tempo|grafana/tempo|2.10.0|grafana/tempo"
    "Prometheus|prom/prometheus|v3.9.1|prometheus/prometheus"
    "OTEL Collector|otel/opentelemetry-collector-contrib|0.144.0|open-telemetry/opentelemetry-collector-releases"
    "Grafana|grafana/grafana|12.3.2|grafana/grafana"
)

# Arrays to store results
declare -a RESULTS_NAME
declare -a RESULTS_CURRENT
declare -a RESULTS_LATEST
declare -a RESULTS_STATUS
declare -a RESULTS_IMAGE

UPDATES_AVAILABLE=0

# Check each service
for service_entry in "${SERVICES[@]}"; do
    IFS='|' read -r display_name image_base default_version repo <<< "${service_entry}"

    echo -n "Checking ${display_name}... "

    # Get current version
    current=$(get_current_tag "${image_base}" || echo "${default_version}")

    # Get latest version
    latest=$(get_github_latest_release "${repo}" 2>/dev/null || echo "")

    if [[ -z "${latest}" ]]; then
        echo -e "${YELLOW}[SKIP - API Error]${NC}"
        RESULTS_NAME+=("${display_name}")
        RESULTS_CURRENT+=("${current}")
        RESULTS_LATEST+=("N/A")
        RESULTS_STATUS+=("Unknown")
        RESULTS_IMAGE+=("${image_base}")
        continue
    fi

    # Compare versions
    status=$(compare_versions "${current}" "${latest}")

    RESULTS_NAME+=("${display_name}")
    RESULTS_CURRENT+=("${current}")
    RESULTS_LATEST+=("${latest}")
    RESULTS_STATUS+=("${status}")
    RESULTS_IMAGE+=("${image_base}")

    case "${status}" in
        "UpToDate")
            echo -e "${GREEN}✓ Up to date (${current})${NC}"
            ;;
        "Outdated")
            echo -e "${YELLOW}⚠ Update available: ${current} → ${latest}${NC}"
            UPDATES_AVAILABLE=1
            ;;
        "Ahead")
            echo -e "${CYAN}ℹ Using newer version (${current} > ${latest})${NC}"
            ;;
        *)
            echo -e "${YELLOW}? Unable to compare${NC}"
            ;;
    esac
done

# =====================================================
# Summary Table
# =====================================================

write_header "Summary"

printf "%-20s %-20s %-20s %-15s\n" "Service" "Current" "Latest" "Status"
printf '%s\n' "$(printf '=%.0s' {1..75})"

for i in "${!RESULTS_NAME[@]}"; do
    status_display=""
    case "${RESULTS_STATUS[$i]}" in
        "UpToDate")
            status_display="✓ Up to date"
            ;;
        "Outdated")
            status_display="⚠ Outdated"
            ;;
        "Ahead")
            status_display="→ Ahead"
            ;;
        *)
            status_display="? Unknown"
            ;;
    esac

    printf "%-20s %-20s %-20s %-15s\n" \
        "${RESULTS_NAME[$i]}" \
        "${RESULTS_CURRENT[$i]}" \
        "${RESULTS_LATEST[$i]}" \
        "${status_display}"
done

# =====================================================
# Apply Updates
# =====================================================

if [[ ${UPDATES_AVAILABLE} -eq 1 ]]; then
    echo ""

    if [[ ${APPLY_UPDATES} -eq 1 ]]; then
        write_header "Applying Updates"

        if [[ ${SKIP_BACKUP} -eq 0 ]]; then
            write_step "Creating backup..."
            cp "${COMPOSE_FILE}" "${BACKUP_FILE}"
            write_success "Backup created: docker-compose.yml.backup.${BACKUP_TIMESTAMP}"
        fi

        updated_count=0

        for i in "${!RESULTS_NAME[@]}"; do
            if [[ "${RESULTS_STATUS[$i]}" == "Outdated" ]]; then
                name="${RESULTS_NAME[$i]}"
                current="${RESULTS_CURRENT[$i]}"
                latest="${RESULTS_LATEST[$i]}"
                image="${RESULTS_IMAGE[$i]}"

                write_step "Updating ${name}: ${current} → ${latest}..."
                update_compose_file "${image}" "${latest}"
                write_success "Updated ${name}"
                updated_count=$((updated_count + 1))
            fi
        done

        echo ""
        write_success "Updated ${updated_count} service(s)"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "  1. Review changes: git diff docker-compose.yml"
        echo "  2. Pull new images: docker compose pull"
        echo "  3. Restart services: docker compose up -d"
        echo "  4. Test thoroughly before committing"
        echo ""
    else
        echo ""
        write_warning "Updates available! Run with --apply to update docker-compose.yml"
        echo ""
        echo -e "${CYAN}Command:${NC}"
        echo "  ${SCRIPT_DIR}/update-service-versions.sh --apply"
        echo ""
    fi
else
    echo ""
    write_success "All services are up to date! 🎉"
    echo ""
fi

exit 0
