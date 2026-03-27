#!/bin/bash

# This script installs the bash tips and tricks collection

# Supported languages
languages=("french" "english")

# Supported technologies
technologies=("bash")

# GitHub API endpoint for latest release
GITHUB_API_URL="https://api.github.com/repos/MonsieurCo/cowtips/releases/latest"

FALLBACK_VERSION="0.0.0"

fetch_latest_version() {
    local version=""

    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        echo "Warning: curl not found, cannot check for latest version" >&2
        echo "$FALLBACK_VERSION"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq not found, cannot parse version from GitHub API" >&2
        echo "$FALLBACK_VERSION"
        return 1
    fi

    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$GITHUB_API_URL" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "Warning: Failed to connect to GitHub API" >&2
        echo "$FALLBACK_VERSION"
        return 1
    fi

    local message
    message=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)
    if [ -n "$message" ]; then
        echo "Warning: GitHub API returned error: $message" >&2
        echo "$FALLBACK_VERSION"
        return 1
    fi

    # Extract version tag
    version=$(echo "$response" | jq -r '.tag_name // empty' 2>/dev/null)

    # Validate version is not empty or null
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        echo "Warning: Could not extract version from GitHub API response" >&2
        echo "$FALLBACK_VERSION"
        return 1
    fi

    # Basic version format validation (should start with v or be a semver-like pattern)
    if [[ ! "$version" =~ ^v?[0-9]+\.[0-9]+ ]]; then
        echo "Warning: Invalid version format received: $version" >&2
        echo "$FALLBACK_VERSION"
        return 1
    fi

    echo "$version"
    return 0
}

if [ -z "$1" ] || [[ ! " ${languages[@]} " =~ " $1 " ]]; then
    echo "Language not supported or not provided. Supported languages are: ${languages[*]}"
    exit 1
fi

if [ -z "$2" ] || [[ ! " ${technologies[@]} " =~ " $2 " ]]; then
    echo "Technology not supported or not provided. Supported technologies are: ${technologies[*]}"
    exit 1
fi

# Check for required dependencies
if ! command -v strfile &> /dev/null; then
    echo "Error: strfile command not found. Please install fortune-mod package."
    exit 1
fi

if ! command -v cowsay &> /dev/null; then
    echo "Error: cowsay command not found. Please install cowsay package."
    exit 1
fi

if ! command -v fortune &> /dev/null; then
    echo "Error: fortune command not found. Please install fortune-mod package."
    exit 1
fi

# Generate fortune data files
for dir in tips/*/; do
    for dir2 in "$dir"/*/; do
        for file in "$dir2"*.txt; do
            if [ -f "$file" ]; then
                strfile "$file" > /dev/null
            fi
        done
    done
done

# Create the app folder
if [ ! -d ~/.term_tips ]; then
    mkdir -p ~/.term_tips
fi

# Copy the tips and tricks to the app folder
cp -r tips/* ~/.term_tips/
cp ./uninstall.sh ~/.term_tips/
chmod +x ~/.term_tips/uninstall.sh

# Register the version of the install
echo "Checking latest version from GitHub..."
installed_version=$(fetch_latest_version)
echo "$installed_version" > ~/.term_tips/version
echo "Installed version: $installed_version"

# Determine which shell config file to use
detect_shell_config() {
    # Check if cowtips is already installed in any config file
    for config_file in ~/.profile ~/.bashrc ~/.zshrc; do
        if [ -f "$config_file" ] && grep -q "cowtips.sh" "$config_file" 2>/dev/null; then
            echo "$config_file"
            return 0
        fi
    done

    # Not installed yet, find the best config file to use
    # Prefer .profile if it exists, otherwise use shell-specific config
    if [ -f ~/.profile ]; then
        echo ~/.profile
    elif [ -f ~/.zshrc ]; then
        echo ~/.zshrc
    elif [ -f ~/.bashrc ]; then
        echo ~/.bashrc
    else
        # None exist, create .profile by default (or .zshrc if using zsh)
        if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
            echo ~/.zshrc
        else
            echo ~/.profile
        fi
    fi
}

# Setup command in shell config
shell_config=$(detect_shell_config)
command="~/.term_tips/cowtips.sh $1 $2;"

# Store which config file we're using for uninstall
echo "$shell_config" > ~/.term_tips/shell_config

if ! grep -q "cowtips.sh" "$shell_config" 2>/dev/null; then
    echo "$command" >> "$shell_config"
    echo "alias cowtips='~/.term_tips/cowtips.sh'" >> "$shell_config"
    echo "$1 $2" > ~/.term_tips/config

    cowsay "Bash tips and tricks collection installed in $shell_config :)"
else
    # Update config even if already installed
    echo "$1 $2" > ~/.term_tips/config
    cowsay "The fortune command is already added to $shell_config!"
fi
