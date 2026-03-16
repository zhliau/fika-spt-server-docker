#!/bin/bash
# Script to automatically fetch the latest SPT version information
# This queries the sp-tarkov/build GitHub releases API to get version details

set -e

# Function to get the latest SPT release version from asset filename
get_latest_spt_version() {
    local github_api="https://api.github.com/repos/sp-tarkov/build/releases/latest"

    # Fetch the latest release info
    echo "Fetching latest SPT version from GitHub..." >&2

    local release_json=$(curl -s "$github_api")

    # Extract the 7z asset filename which contains the full version string
    # Format: SPT-4.0.13-40087-2891fd4.7z
    local asset_name=$(echo "$release_json" | jq -r '.assets[] | select(.name | endswith(".7z")) | .name' | head -n1)

    if [ -z "$asset_name" ] || [ "$asset_name" = "null" ]; then
        echo "Error: Could not find .7z asset in release" >&2
        return 1
    fi

    # Extract full version string from filename: SPT-4.0.13-40087-2891fd4.7z -> 4.0.13-40087-2891fd4
    local full_version=$(echo "$asset_name" | sed -E 's/^SPT-//; s/\.7z$//')

    if [ -z "$full_version" ]; then
        echo "Error: Could not parse version from asset name: $asset_name" >&2
        return 1
    fi

    echo "$full_version"
}

# Function to get full version string from a specific release
get_version_from_release() {
    local version_tag="$1"

    local github_api="https://api.github.com/repos/sp-tarkov/build/releases/tags/${version_tag}"

    echo "Fetching release assets for version ${version_tag}..." >&2

    local release_json=$(curl -s "$github_api")

    # Extract the 7z asset filename which contains the full version string
    local asset_name=$(echo "$release_json" | jq -r '.assets[] | select(.name | endswith(".7z")) | .name' | head -n1)

    if [ -z "$asset_name" ] || [ "$asset_name" = "null" ]; then
        echo "Error: Could not find .7z asset in release" >&2
        return 1
    fi

    # Extract full version string from filename
    local full_version=$(echo "$asset_name" | sed -E 's/^SPT-//; s/\.7z$//')

    if [ -z "$full_version" ]; then
        echo "Error: Could not parse version from asset name: $asset_name" >&2
        return 1
    fi

    echo "$full_version"
}

# Function to extract just the version number from full version string
get_version_number() {
    local full_version="$1"
    echo "$full_version" | cut -d'-' -f1
}

# Main script logic
main() {
    local command="${1:-latest}"

    case "$command" in
        latest)
            # Get the latest full version string from release asset
            get_latest_spt_version
            ;;

        version)
            # Just get the version number (e.g., 4.0.13)
            local full_version=$(get_latest_spt_version)
            if [ $? -ne 0 ]; then
                exit 1
            fi
            get_version_number "$full_version"
            ;;

        specific)
            # Get details for a specific version
            local version="$2"
            if [ -z "$version" ]; then
                echo "Error: Please provide a version (e.g., 4.0.13)" >&2
                exit 1
            fi

            get_version_from_release "$version"
            ;;

        help|--help|-h)
            cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  latest          Get the latest SPT version string (default)
  version         Get just the version number (e.g., 4.0.13)
  specific <ver>  Get version string for a specific version
  help            Show this help message

Examples:
  $0                    # Get latest full version string
  $0 latest             # Same as above
  $0 version            # Get just version number
  $0 specific 4.0.13    # Get full version string for 4.0.13

Output format: VERSION-BUILD_NUMBER-COMMIT_SHA
Example: 4.0.13-40087-2891fd4
EOF
            ;;

        *)
            echo "Error: Unknown command '$command'" >&2
            echo "Run '$0 help' for usage information" >&2
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
