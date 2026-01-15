#!/bin/bash

# GitHub API endpoint for latest release
GITHUB_API_URL="https://api.github.com/repos/MonsieurCo/cowtips/releases/latest"

# Supported languages
languages=("french" "english")

# Supported technologies
technologies=("bash")

# Default fallback version
FALLBACK_VERSION="0.0.0"

# Update check interval in seconds (24 hours = 86400 seconds)
UPDATE_CHECK_INTERVAL=86400

# File to store the last update check timestamp
LAST_CHECK_FILE="$HOME/.term_tips/.last_update_check"

# Function to fetch the latest version from GitHub
fetch_latest_version() {
    local version=""

    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        echo ""
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo ""
        return 1
    fi

    # Fetch from GitHub API with timeout and error handling
    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$GITHUB_API_URL" 2>/dev/null)

    # Check if curl succeeded
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo ""
        return 1
    fi

    # Check for API rate limiting or error responses
    local message
    message=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)
    if [ -n "$message" ]; then
        # GitHub API returned an error (e.g., rate limiting)
        echo ""
        return 1
    fi

    # Extract version tag
    version=$(echo "$response" | jq -r '.tag_name // empty' 2>/dev/null)

    # Validate version is not empty or null
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        echo ""
        return 1
    fi

    # Basic version format validation (should start with v or be a semver-like pattern)
    if [[ ! "$version" =~ ^v?[0-9]+\.[0-9]+ ]]; then
        echo ""
        return 1
    fi

    echo "$version"
    return 0
}

# Function to compare versions (returns 0 if $1 > $2, 1 otherwise)
version_greater_than() {
    local ver1="$1"
    local ver2="$2"

    # Remove leading 'v' if present
    ver1="${ver1#v}"
    ver2="${ver2#v}"

    # Use sort -V to compare versions
    if [ "$(printf '%s\n' "$ver1" "$ver2" | sort -V | tail -n1)" = "$ver1" ] && [ "$ver1" != "$ver2" ]; then
        return 0
    fi
    return 1
}

# Function to check if we should perform an update check
should_check_for_updates() {
    # If last check file doesn't exist, we should check
    if [ ! -f "$LAST_CHECK_FILE" ]; then
        return 0
    fi

    # Get the last check timestamp
    local last_check
    last_check=$(cat "$LAST_CHECK_FILE" 2>/dev/null)

    # If we couldn't read the timestamp, check anyway
    if [ -z "$last_check" ] || ! [[ "$last_check" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    # Get current timestamp
    local current_time
    current_time=$(date +%s)

    # Calculate time since last check
    local time_diff=$((current_time - last_check))

    # Return true (0) if enough time has passed
    if [ "$time_diff" -ge "$UPDATE_CHECK_INTERVAL" ]; then
        return 0
    fi

    # Not time to check yet
    return 1
}

# Function to update the last check timestamp
update_last_check_time() {
    date +%s > "$LAST_CHECK_FILE" 2>/dev/null
}

# Function to check for updates
check_for_updates() {
    local updatable=0
    local latest_version=""
    local current_version=""

    # Get current installed version
    if [ -f ~/.term_tips/version ]; then
        current_version=$(cat ~/.term_tips/version 2>/dev/null)
    fi

    # Validate current version
    if [ -z "$current_version" ] || [ "$current_version" = "null" ]; then
        current_version="$FALLBACK_VERSION"
    fi

    # Check if we should perform the update check (rate limiting)
    if ! should_check_for_updates; then
        # Not time to check yet, return no update
        echo "0"
        echo ""
        echo "$current_version"
        return
    fi

    # Update the last check timestamp
    update_last_check_time

    # Fetch latest version from GitHub
    latest_version=$(fetch_latest_version)

    # If we couldn't fetch the latest version, skip update check silently
    if [ -z "$latest_version" ]; then
        echo "0"
        echo ""
        echo "$current_version"
        return
    fi

    # Compare versions
    if version_greater_than "$latest_version" "$current_version"; then
        echo "1"
        echo "$latest_version"
        echo "$current_version"
    else
        echo "0"
        echo "$latest_version"
        echo "$current_version"
    fi
}

# Perform update check
update_info=$(check_for_updates)
updatable=$(echo "$update_info" | sed -n '1p')
new_version=$(echo "$update_info" | sed -n '2p')
current_version=$(echo "$update_info" | sed -n '3p')

if [ "$updatable" = "1" ] && [ -n "$new_version" ]; then
    # Only prompt if running in a TTY
    if [ -t 1 ]; then
        read -p "A new version ($new_version) of cowtips is available (current: $current_version)! Do you want to update? [Y/n] " response
    else
        response="n"
    fi

    if [[ "$response" =~ ^[Yy]$ || -z "$response" ]]; then
        echo "Updating cowtips..."
        config=$(cat ~/.term_tips/config 2>/dev/null)

        if [ -z "$config" ]; then
            echo "Error: Could not read current configuration. Aborting update."
            exit 1
        fi

        # Download the new version first
        echo "Downloading version $new_version..."
        curl -sL --connect-timeout 30 --max-time 120 \
            "https://github.com/MonsieurCo/cowtips/archive/refs/tags/$new_version.tar.gz" \
            -o /tmp/cowtips_update.tar.gz

        # Check if download succeeded (file exists and is not empty)
        if [ ! -s /tmp/cowtips_update.tar.gz ]; then
            echo "Failed to download the latest release. Aborting update."
            rm -f /tmp/cowtips_update.tar.gz
            exit 1
        fi

        # Verify the tarball is valid
        if ! tar -tzf /tmp/cowtips_update.tar.gz &> /dev/null; then
            echo "Downloaded file is not a valid archive. Aborting update."
            rm -f /tmp/cowtips_update.tar.gz
            exit 1
        fi

        # Remove old temporary directory if exists
        if [ -d /tmp/cowtips_update_dir ]; then
            rm -rf /tmp/cowtips_update_dir
        fi

        # Create temporary directory and extract
        mkdir -p /tmp/cowtips_update_dir
        if ! tar -xzf /tmp/cowtips_update.tar.gz -C /tmp/cowtips_update_dir; then
            echo "Failed to extract the update archive. Aborting update."
            rm -f /tmp/cowtips_update.tar.gz
            rm -rf /tmp/cowtips_update_dir
            exit 1
        fi

        # Remove leading 'v' from version if present for directory name
        dir_version="${new_version#v}"

        # Check if the extracted directory exists (try both with and without 'v' prefix)
        install_dir=""
        if [ -d "/tmp/cowtips_update_dir/cowtips-$new_version" ]; then
            install_dir="/tmp/cowtips_update_dir/cowtips-$new_version"
        elif [ -d "/tmp/cowtips_update_dir/cowtips-$dir_version" ]; then
            install_dir="/tmp/cowtips_update_dir/cowtips-$dir_version"
        else
            echo "Could not find extracted directory. Aborting update."
            rm -f /tmp/cowtips_update.tar.gz
            rm -rf /tmp/cowtips_update_dir
            exit 1
        fi

        # Verify install script exists
        if [ ! -f "$install_dir/install.sh" ]; then
            echo "Install script not found in update package. Aborting update."
            rm -f /tmp/cowtips_update.tar.gz
            rm -rf /tmp/cowtips_update_dir
            exit 1
        fi

        # Remove old version
        ~/.term_tips/uninstall.sh > /dev/null 2>&1

        # Run the new installer
        cd "$install_dir"
        chmod +x ./install.sh
        if ./install.sh $config > /dev/null; then
            echo "Update completed successfully!"
            cowsay "Updated to version $new_version"
        else
            echo "Update installation failed."
        fi

        # Cleanup
        rm -f /tmp/cowtips_update.tar.gz
        rm -rf /tmp/cowtips_update_dir

        # Source the profile to get new settings
        if [ -f ~/.profile ]; then
            source ~/.profile 2>/dev/null
        fi

        exit 0
    else
        echo "Update skipped."
    fi
fi

# Handle commands
if [ "$1" == "uninstall" ]; then
    ~/.term_tips/uninstall.sh
    exit 0
fi

if [ "$1" == "help" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cowsay "For now only french/english and bash are available. :("
    echo ""
    echo "Usage: cowtips [language] [techno]"
    echo "       cowtips uninstall  - Uninstall cowtips"
    echo "       cowtips help       - Show this help"
    echo ""
    echo "Available languages: ${languages[*]}"
    echo "Available technologies: ${technologies[*]}"
    exit 0
fi

if [ "$1" == "version" ] || [ "$1" == "--version" ] || [ "$1" == "-v" ]; then
    if [ -f ~/.term_tips/version ]; then
        echo "cowtips version: $(cat ~/.term_tips/version)"
    else
        echo "cowtips version: unknown"
    fi
    exit 0
fi

# If no arguments, show a tip using saved config
if [ -z "$1" ]; then
    if [ -f ~/.term_tips/config ]; then
        config=$(cat ~/.term_tips/config)
        lang=$(echo "$config" | awk '{print $1}')
        tech=$(echo "$config" | awk '{print $2}')

        if [ -n "$lang" ] && [ -n "$tech" ] && [ -f ~/.term_tips/$lang/$tech/tips.txt ]; then
            fortune ~/.term_tips/$lang/$tech/tips.txt | cowsay
            exit 0
        fi
    fi
    echo "Usage: cowtips [language] [techno]"
    echo "Run 'cowtips help' for more information."
    exit 1
fi

# Validate language
if [[ ! " ${languages[@]} " =~ " $1 " ]]; then
    echo "Language not supported. Supported languages are: ${languages[*]}"
    exit 1
fi

# Validate technology
if [ -z "$2" ]; then
    echo "Technology not specified. Supported technologies are: ${technologies[*]}"
    exit 1
fi

if [[ ! " ${technologies[@]} " =~ " $2 " ]]; then
    echo "Technology not supported. Supported technologies are: ${technologies[*]}"
    exit 1
fi

# Check if tips file exists
if [ ! -f ~/.term_tips/$1/$2/tips.txt ]; then
    echo "Tips file not found for $1/$2. Please reinstall cowtips."
    exit 1
fi

# Display a fortune tip
fortune ~/.term_tips/$1/$2/tips.txt | cowsay
