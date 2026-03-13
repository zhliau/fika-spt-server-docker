#!/bin/bash
# Script to update SPT and Fika versions in project files
# This can be run manually to update to the latest versions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for required commands
check_requirements() {
    local missing_deps=()

    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo_error "Missing required dependencies: ${missing_deps[*]}"
        echo_error "Please install them and try again"
        exit 1
    fi
}

# Get latest SPT version
get_spt_version() {
    echo_info "Fetching latest SPT version..."

    if [ ! -x "$SCRIPT_DIR/scripts/get-spt-version.sh" ]; then
        chmod +x "$SCRIPT_DIR/scripts/get-spt-version.sh"
    fi

    local version=$("$SCRIPT_DIR/scripts/get-spt-version.sh" latest)

    if [ $? -ne 0 ] || [ -z "$version" ]; then
        echo_error "Failed to fetch SPT version"
        return 1
    fi

    echo "$version"
}

# Get latest Fika version
get_fika_version() {
    echo_info "Fetching latest Fika version..."

    local github_api="https://api.github.com/repos/project-fika/Fika-Server-CSharp/releases/latest"
    local release_json=$(curl -s "$github_api")

    local version=$(echo "$release_json" | jq -r '.tag_name')

    if [ "$version" = "null" ] || [ -z "$version" ]; then
        echo_error "Failed to fetch Fika version"
        return 1
    fi

    # Remove 'v' prefix if present
    version="${version#v}"

    echo "$version"
}

# Update Dockerfile
update_dockerfile() {
    local spt_version="$1"
    local fika_version="$2"
    local dockerfile="$3"

    if [ ! -f "$dockerfile" ]; then
        echo_warn "Dockerfile not found: $dockerfile"
        return 1
    fi

    echo_info "Updating $dockerfile..."

    # Update SPT_VERSION
    sed -i "s/^ARG SPT_VERSION=.*/ARG SPT_VERSION=${spt_version}/" "$dockerfile"

    # Update FIKA_VERSION
    sed -i "s/^ARG FIKA_VERSION=.*/ARG FIKA_VERSION=${fika_version}/" "$dockerfile"

    echo_info "Updated $dockerfile"
}

# Update entrypoint.sh
update_entrypoint() {
    local spt_version="$1"
    local fika_version="$2"
    local entrypoint="$SCRIPT_DIR/entrypoint.sh"

    if [ ! -f "$entrypoint" ]; then
        echo_warn "entrypoint.sh not found"
        return 1
    fi

    echo_info "Updating entrypoint.sh..."

    # Update default SPT_VERSION
    sed -i "s/^spt_version=\${SPT_VERSION:-.*}/spt_version=\${SPT_VERSION:-${spt_version}\}/" "$entrypoint"

    # Update default FIKA_VERSION
    sed -i "s/^fika_version=\${FIKA_VERSION:-.*}/fika_version=\${FIKA_VERSION:-${fika_version}\}/" "$entrypoint"

    echo_info "Updated entrypoint.sh"
}

# Main function
main() {
    local force_update=false
    local dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force_update=true
                shift
                ;;
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: $0 [OPTIONS]

Update SPT and Fika versions in project files.

Options:
  -f, --force       Force update even if versions are the same
  -n, --dry-run     Show what would be updated without making changes
  -h, --help        Show this help message

Examples:
  $0                # Update to latest versions
  $0 --dry-run      # Check what would be updated
  $0 --force        # Force update all files
EOF
                exit 0
                ;;
            *)
                echo_error "Unknown option: $1"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done

    echo_info "Starting version update check..."

    # Check requirements
    check_requirements

    # Get latest versions
    local spt_version=$(get_spt_version)
    if [ $? -ne 0 ]; then
        exit 1
    fi

    local fika_version=$(get_fika_version)
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo ""
    echo_info "Latest versions:"
    echo "  SPT:  ${spt_version}"
    echo "  Fika: ${fika_version}"
    echo ""

    if [ "$dry_run" = true ]; then
        echo_info "DRY RUN: Would update the following files:"
        echo "  - Dockerfile"
        echo "  - Dockerfile.multiarch"
        echo "  - entrypoint.sh"
        echo ""
        echo_info "Run without --dry-run to apply changes"
        exit 0
    fi

    # Update files
    update_dockerfile "$spt_version" "$fika_version" "$SCRIPT_DIR/Dockerfile"
    update_dockerfile "$spt_version" "$fika_version" "$SCRIPT_DIR/Dockerfile.multiarch"
    update_entrypoint "$spt_version" "$fika_version"

    echo ""
    echo_info "Version update complete!"
    echo_info "Updated to:"
    echo "  SPT:  ${spt_version}"
    echo "  Fika: ${fika_version}"
    echo ""
    echo_warn "Please review the changes and test before committing"
}

# Run main function
main "$@"
