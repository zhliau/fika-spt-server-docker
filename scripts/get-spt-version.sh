#!/bin/bash
# Script to automatically fetch the latest SPT version information
# This queries the sp-tarkov/build GitHub releases API to get version details

set -e

# Function to get the latest SPT release version
get_latest_spt_version() {
    local github_api="https://api.github.com/repos/sp-tarkov/build/releases/latest"

    # Fetch the latest release info
    echo "Fetching latest SPT version from GitHub..." >&2

    local release_json=$(curl -s "$github_api")

    # Extract the tag name (version)
    local version=$(echo "$release_json" | jq -r '.tag_name')

    if [ "$version" = "null" ] || [ -z "$version" ]; then
        echo "Error: Could not fetch version from GitHub API" >&2
        return 1
    fi

    echo "$version"
}

# Function to get SPT version from server-csharp repository
# This gets the git commit SHA that corresponds to the version
get_spt_version_details() {
    local version="$1"

    if [ -z "$version" ]; then
        echo "Error: Version parameter required" >&2
        return 1
    fi

    # Query the server-csharp repo for the tag
    local github_api="https://api.github.com/repos/sp-tarkov/server-csharp/git/refs/tags/${version}"

    echo "Fetching commit details for version ${version}..." >&2

    local tag_json=$(curl -s "$github_api")
    local commit_sha=$(echo "$tag_json" | jq -r '.object.sha' | cut -c1-7)

    if [ "$commit_sha" = "null" ] || [ -z "$commit_sha" ]; then
        echo "Error: Could not fetch commit SHA for version ${version}" >&2
        return 1
    fi

    echo "$commit_sha"
}

# Function to construct the full SPT version string
# Format: VERSION-BUILD_NUMBER-COMMIT_SHA (e.g., 4.0.13-40087-2891fd4)
construct_version_string() {
    local version="$1"
    local build_number="${2:-40087}"  # Default to 40087 if not provided

    if [ -z "$version" ]; then
        echo "Error: Version parameter required" >&2
        return 1
    fi

    local commit_sha=$(get_spt_version_details "$version")

    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "${version}-${build_number}-${commit_sha}"
}

# Function to get build number from release assets
# The build number is typically in the archive name
get_build_number_from_release() {
    local version="$1"

    local github_api="https://api.github.com/repos/sp-tarkov/build/releases/tags/${version}"

    echo "Fetching release assets for version ${version}..." >&2

    local release_json=$(curl -s "$github_api")

    # Look for the 7z asset and extract build number from filename
    # Format: SPT-VERSION-BUILD-SHA.7z
    local asset_name=$(echo "$release_json" | jq -r '.assets[] | select(.name | endswith(".7z")) | .name' | head -n1)

    if [ -z "$asset_name" ] || [ "$asset_name" = "null" ]; then
        echo "Warning: Could not find 7z asset, using default build number" >&2
        echo "40087"  # Default fallback
        return 0
    fi

    # Extract build number from filename: SPT-4.0.13-40087-2891fd4.7z
    local build_number=$(echo "$asset_name" | sed -E 's/SPT-[0-9.]+//; s/-[a-f0-9]+\.7z//; s/-//')

    if [ -z "$build_number" ]; then
        echo "Warning: Could not parse build number from asset name, using default" >&2
        echo "40087"
    else
        echo "$build_number"
    fi
}

# Main script logic
main() {
    local command="${1:-latest}"

    case "$command" in
        latest)
            # Get the latest version and construct full version string
            local version=$(get_latest_spt_version)
            if [ $? -ne 0 ]; then
                exit 1
            fi

            local build_number=$(get_build_number_from_release "$version")
            local full_version=$(construct_version_string "$version" "$build_number")

            echo "$full_version"
            ;;

        version)
            # Just get the version number (e.g., 4.0.13)
            get_latest_spt_version
            ;;

        specific)
            # Get details for a specific version
            local version="$2"
            if [ -z "$version" ]; then
                echo "Error: Please provide a version (e.g., 4.0.13)" >&2
                exit 1
            fi

            local build_number=$(get_build_number_from_release "$version")
            local full_version=$(construct_version_string "$version" "$build_number")

            echo "$full_version"
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
