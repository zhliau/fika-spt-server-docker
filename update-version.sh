#!/bin/bash
# Update SPT and Fika versions in project files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for required commands
for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Missing required command: $cmd" >&2
        exit 1
    fi
done

# Parse arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Update SPT and Fika versions in project files.

Options:
  -n, --dry-run     Show what would be updated without making changes
  -h, --help        Show this help message

Examples:
  $0                # Update to latest versions
  $0 --dry-run      # Check what would be updated
EOF
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Run '$0 --help' for usage" >&2
            exit 1
            ;;
    esac
done

# Get latest versions
echo "Fetching latest versions..."

chmod +x "$SCRIPT_DIR/scripts/get-spt-version.sh"
SPT_VERSION=$("$SCRIPT_DIR/scripts/get-spt-version.sh" latest)
FIKA_VERSION=$(curl -s https://api.github.com/repos/project-fika/Fika-Server-CSharp/releases/latest | jq -r '.tag_name' | sed 's/^v//')

if [ -z "$SPT_VERSION" ] || [ -z "$FIKA_VERSION" ] || [ "$FIKA_VERSION" = "null" ]; then
    echo "Error: Failed to fetch versions" >&2
    exit 1
fi

echo "Latest versions:"
echo "  SPT:  $SPT_VERSION"
echo "  Fika: $FIKA_VERSION"
echo

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: Would update:"
    echo "  - Dockerfile"
    echo "  - Dockerfile.multiarch"
    echo "  - entrypoint.sh"
    exit 0
fi

# Update files
echo "Updating files..."

sed -i "s/^ARG SPT_VERSION=.*/ARG SPT_VERSION=${SPT_VERSION}/" "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/Dockerfile.multiarch"
sed -i "s/^ARG FIKA_VERSION=.*/ARG FIKA_VERSION=${FIKA_VERSION}/" "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/Dockerfile.multiarch"

sed -i "s/^spt_version=\${SPT_VERSION:-.*\}/spt_version=\${SPT_VERSION:-${SPT_VERSION}\}/" "$SCRIPT_DIR/entrypoint.sh"
sed -i "s/^fika_version=\${FIKA_VERSION:-.*\}/fika_version=\${FIKA_VERSION:-${FIKA_VERSION}\}/" "$SCRIPT_DIR/entrypoint.sh"

echo "✓ Updated successfully"
echo
echo "Updated to:"
echo "  SPT:  $SPT_VERSION"
echo "  Fika: $FIKA_VERSION"
