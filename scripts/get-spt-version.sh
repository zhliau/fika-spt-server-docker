#!/bin/bash
# Script to automatically fetch the latest SPT version information
# This queries the sp-tarkov/build GitHub releases API to get version details

set -e

# Function to get the latest SPT release version info from GitHub
get_latest_spt_release_info() {
    local github_api="https://api.github.com/repos/sp-tarkov/build/releases/latest"

    echo "Fetching latest SPT release from GitHub..." >&2

    local release_json=$(curl -s "$github_api")

    # Extract the tag name (version number like 4.0.13)
    local version=$(echo "$release_json" | jq -r '.tag_name')

    # Extract the build number from release name like "SPT 4.0.13 (40087)"
    local release_name=$(echo "$release_json" | jq -r '.name')
    local build_number=$(echo "$release_name" | grep -oP '\(\K[0-9]+(?=\))')

    if [ "$version" = "null" ] || [ -z "$version" ]; then
        echo "Error: Could not fetch version from GitHub API" >&2
        return 1
    fi

    if [ -z "$build_number" ]; then
        echo "Error: Could not extract build number from release name: $release_name" >&2
        return 1
    fi

    echo "$version:$build_number"
}

# Function to get commit SHA from server-csharp repository for a specific version
get_commit_sha() {
    local version="$1"

    local github_api="https://api.github.com/repos/sp-tarkov/server-csharp/git/refs/tags/${version}"

    echo "Fetching commit SHA for version ${version}..." >&2

    local tag_json=$(curl -s "$github_api")
    local commit_sha=$(echo "$tag_json" | jq -r '.object.sha' | cut -c1-7)

    if [ "$commit_sha" = "null" ] || [ -z "$commit_sha" ]; then
        echo "Error: Could not fetch commit SHA for version ${version}" >&2
        return 1
    fi

    echo "$commit_sha"
}

# Function to construct and verify the full SPT version string
get_latest_spt_version() {
    local release_info=$(get_latest_spt_release_info)
    if [ $? -ne 0 ]; then
        return 1
    fi

    local version=$(echo "$release_info" | cut -d':' -f1)
    local build_number=$(echo "$release_info" | cut -d':' -f2)

    local commit_sha=$(get_commit_sha "$version")
    if [ $? -ne 0 ]; then
        return 1
    fi

    local full_version="${version}-${build_number}-${commit_sha}"

    # Verify the archive exists at the download URL
    local download_url="https://spt-releases.modd.in/SPT-${full_version}.7z"
    echo "Verifying archive exists: ${download_url}" >&2

    if curl --head --silent --fail "$download_url" > /dev/null 2>&1; then
        echo "$full_version"
    else
        echo "Warning: Archive not found at ${download_url}" >&2
        echo "Returning version string anyway: ${full_version}" >&2
        echo "$full_version"
    fi
}

# Function to get full version string from a specific release
get_version_from_release() {
    local version_tag="$1"

    local github_api="https://api.github.com/repos/sp-tarkov/build/releases/tags/${version_tag}"

    echo "Fetching release info for version ${version_tag}..." >&2

    local release_json=$(curl -s "$github_api")

    # Extract the build number from release name
    local release_name=$(echo "$release_json" | jq -r '.name')
    local build_number=$(echo "$release_name" | grep -oP '\(\K[0-9]+(?=\))')

    if [ -z "$build_number" ]; then
        echo "Error: Could not extract build number from release name: $release_name" >&2
        return 1
    fi

    local commit_sha=$(get_commit_sha "$version_tag")
    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "${version_tag}-${build_number}-${commit_sha}"
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
            # Get the latest full version string
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
