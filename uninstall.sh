#!/bin/bash

cowsay -f tux "Uninstalling bash tips and tricks collection :("

# Determine which shell config file was used during installation
shell_config=""
if [ -f ~/.term_tips/shell_config ]; then
    shell_config=$(cat ~/.term_tips/shell_config 2>/dev/null)
fi

# Function to remove cowtips entries from a config file
remove_from_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        # Remove the alias line
        sed -i '/alias cowtips='\''~\/.term_tips\/cowtips.sh'\''/d' "$config_file" 2>/dev/null
        # Remove the cowtips.sh execution line
        sed -i '/~\/.term_tips\/cowtips.sh/d' "$config_file" 2>/dev/null
    fi
}

# If we know which config file was used, clean only that one
if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
    remove_from_config "$shell_config"
    echo "Removed cowtips entries from $shell_config"
else
    # Fallback: clean all possible config files
    for config_file in ~/.profile ~/.bashrc ~/.zshrc; do
        if [ -f "$config_file" ] && grep -q "cowtips.sh" "$config_file" 2>/dev/null; then
            remove_from_config "$config_file"
            echo "Removed cowtips entries from $config_file"
        fi
    done
fi

# Remove the term_tips directory
if [ -d ~/.term_tips ]; then
    rm -rf ~/.term_tips
    echo "Bash tips and tricks collection folder uninstalled from the home directory."
else
    echo "No installation found at ~/.term_tips"
fi
