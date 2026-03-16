#!/bin/bash
# Script to automatically fetch the latest SPT version information
# This extracts the download URL from sp-tarkov/build release notes

set -e

# Function to get the latest SPT version from release download URL
get_latest_spt_version() {
    local github_api="https://api.github.com/repos/sp-tarkov/build/releases/latest"

    echo "Fetching latest SPT release from GitHub..." >&2

    local release_json=$(curl -s "$github_api")
    local release_body=$(echo "$release_json" | jq -r '.body')

    if [ "$release_body" = "null" ] || [ -z "$release_body" ]; then
        echo "Error: Could not fetch release body from GitHub API" >&2
        return 1
    fi

    # Extract the download URL from release notes
    # Format: https://spt-releases.modd.in/SPT-4.0.13-40087-2891fd4.7z
    local download_url=$(echo "$release_body" | grep -oP 'https://spt-releases\.modd\.in/SPT-[0-9.]+-[0-9]+-[a-f0-9]+\.7z' | head -n1)

    if [ -z "$download_url" ]; then
        echo "Error: Could not find download URL in release notes" >&2
        echo "Release body:" >&2
        echo "$release_body" | head -20 >&2
        return 1
    fi

    # Extract version string from URL
    # From: https://spt-releases.modd.in/SPT-4.0.13-40087-2891fd4.7z
    # To: 4.0.13-40087-2891fd4
    local full_version=$(echo "$download_url" | sed -E 's|https://spt-releases\.modd\.in/SPT-||; s|\.7z$||')

    if [ -z "$full_version" ]; then
        echo "Error: Could not parse version from URL: $download_url" >&2
        return 1
    fi

    echo "Found version: $full_version" >&2
    echo "Download URL: $download_url" >&2

    echo "$full_version"
}

# Function to get version from a specific release tag
get_version_from_release() {
    local version_tag="$1"

    local github_api="https://api.github.com/repos/sp-tarkov/build/releases/tags/${version_tag}"

    echo "Fetching release info for version ${version_tag}..." >&2

    local release_json=$(curl -s "$github_api")
    local release_body=$(echo "$release_json" | jq -r '.body')

    if [ "$release_body" = "null" ] || [ -z "$release_body" ]; then
        echo "Error: Could not fetch release body from GitHub API" >&2
        return 1
    fi

    # Extract the download URL from release notes
    local download_url=$(echo "$release_body" | grep -oP 'https://spt-releases\.modd\.in/SPT-[0-9.]+-[0-9]+-[a-f0-9]+\.7z' | head -n1)

    if [ -z "$download_url" ]; then
        echo "Error: Could not find download URL in release notes for ${version_tag}" >&2
        return 1
    fi

    # Extract version string from URL
    local full_version=$(echo "$download_url" | sed -E 's|https://spt-releases\.modd\.in/SPT-||; s|\.7z$||')

    if [ -z "$full_version" ]; then
        echo "Error: Could not parse version from URL: $download_url" >&2
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
            # Get the latest full version string from release notes
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

Note: This script extracts the actual download URL from the release notes,
ensuring the version string matches an existing archive.
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
