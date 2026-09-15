#!/usr/bin/env bash

if ! command -v gpg &> /dev/null; then
    echo "Error: GPG is not installed." >&2
    exit 1
fi

# Non-interactive GPG arguments
GPG_ARGS=(--batch --yes --quiet)

temp_files=()

cleanup_temp_files() {
    local temp_file
    for temp_file in "${temp_files[@]}"; do
        rm -f -- "$temp_file"
    done
}

trap cleanup_temp_files EXIT

usage() {
    case "${command:-unknown}" in
        "encrypt")
            cat << 'EOF'
Encrypt .env file using GPG.

Usage: envgpg encrypt [<flags>] [<file>]

Arguments:
  <file>    File to encrypt (default: .env)

Options:
  -n        Dry run expected result
  -r        Remove original .env after encryption
  -v        Print verbose output
  -y        Assume yes for all prompts
EOF
            ;;
        "decrypt")
            cat << 'EOF'
Decrypt .env file using GPG.

Usage: envgpg decrypt [<flags>] [<file>]

Arguments:
  <file>    File to decrypt (default: .env.gpg)

Options:
  -e        Prepend 'export' before each variable
  -m        Mask secrets in the output
  -n        Dry run expected result
  -v        Print verbose output
EOF
            ;;
        "edit")
            cat << 'EOF'
Edit encrypted .env file in $EDITOR.

Usage: envgpg edit [<file>]

Arguments:
  <file>    File to edit (default: .env.gpg)
EOF
            ;;
        *)
            cat << 'EOF'
EnvGPG - Manage .env files with GPG encryption

Usage: envgpg <command> [<flags>] [<file>]

Commands:
  encrypt     Encrypt .env file
  decrypt     Decrypt .env file
  edit        Edit encrypted .env
EOF
            ;;
    esac
    exit 1
}

# Check that there are arguments
if [ $# != 0 ]; then
    # Save first argument
    command="$1"

    # Skip first argument
    shift 1
else
    # Print usage if arguments are empty
    usage
fi

get_file() {
    local file_argument=$1
    local file_default=$2
    local file="${file_argument:-$file_default}"

    # Check if the file exists
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist." >&2
        return 1
    fi
    printf "%s" "$file"
}

get_yes_no() {
    local response="N"
    local question=$1
    read -r -p "$question [y/N] " response
    [ "$response" != "y" ] && [ "$response" != "Y" ] && return 1
    return 0
}

mktemp_to_var() {
    local var_name=$1
    [ -z "$var_name" ] && return 1
    local new_file
    new_file="$(mktemp)" || return 1
    temp_files+=("$new_file")
    printf -v "$var_name" "%s" "$new_file"
}

verify_encryption() {
    local decrypted_file=$1
    local encrypted_file=$2

    # Verify that the decrypted file matches encrypted file
    local temp_file
    mktemp_to_var temp_file || return 1
    if ! gpg "${GPG_ARGS[@]}" -d -o "$temp_file" -- "$encrypted_file"; then
        return 1
    fi
    cmp -s "$decrypted_file" "$temp_file"
    local cmp_exit_code=$?

    # Return the comparison exit code
    return $cmp_exit_code
}

encrypt_file() {
    # Initialize flags
    local dry_run_flag=false
    local remove_flag=false
    local verbose_flag=false
    local yes_flag=false

    # Check for flag match
    local OPTIND=1
    while getopts ":nrvy" opt; do
        case $opt in
            n) dry_run_flag=true ;;
            r) remove_flag=true ;;
            v) verbose_flag=true ;;
            y) yes_flag=true ;;
            *) usage ;;
        esac
    done

    # Skip flags in script arguments
    shift "$((OPTIND - 1))"

    # Get file argument
    local file
    file="$(get_file "$1" ".env")" || return 1
    local encrypted_file="${file}.gpg"

    # Handle dry run scenario
    if [ "$dry_run_flag" = true ]; then
        echo "Dry run: would generate $encrypted_file"
        [ "$remove_flag" = true ] && echo "Dry run: would remove $file"
        return 0
    fi

    # Check if the encrypted file already exists
    if [ -f "$encrypted_file" ]; then
        if [ "$yes_flag" = false ]; then
            if get_yes_no "Are you sure you want to overwrite $encrypted_file?"; then
                rm -f "$encrypted_file"
            else
                return 0
            fi
        fi
    fi

    # Encrypt the file using GPG
    [ "$verbose_flag" = true ] && echo "Encrypting file: $file"
    if ! gpg "${GPG_ARGS[@]}" -c -o "$encrypted_file" -- "$file"; then
        echo "Error: Failed to encrypt $file." >&2
        return 1
    fi
    [ "$verbose_flag" = true ] && echo "Generated file: $encrypted_file"

    # Verify that the encryption was successful
    if verify_encryption "$file" "$encrypted_file"; then
        [ "$verbose_flag" = true ] && echo "Verification successful: $file matches $encrypted_file, safe to remove $file"
    else
        echo "Warning: $file and $encrypted_file do not match" >&2
        return 1
    fi

    # Remove the original file if requested
    if [ "$remove_flag" = true ]; then
        # Prompt for confirmation before removing the original file
        if [ "$yes_flag" = false ]; then
            get_yes_no "Are you sure you want to remove $file?" || return 0
        fi
        # Remove if confirmed
        rm "$file" && [ "$verbose_flag" = true ] && echo "Removed original file: $file"
    fi
    return 0
}

decrypt_file() {
    # Initialize flags
    local export_flag=false
    local mask_flag=false
    local dry_run_flag=false
    local verbose_flag=false

    # Check for flag match
    local OPTIND=1
    while getopts ":emnrwvy" opt; do
        case $opt in
            e) export_flag=true ;;
            m) mask_flag=true ;;
            n) dry_run_flag=true ;;
            v) verbose_flag=true ;;
            *) usage ;;
        esac
    done

    # Skip flags in script arguments
    shift "$((OPTIND - 1))"

    # Get file argument
    local file
    file="$(get_file "$1" ".env.gpg")" || return 1

    # Handle dry run scenario
    if [ "$dry_run_flag" = true ]; then
        echo "Dry run: would decrypt $file"
        return 0
    fi

    # Decrypt the file
    [ "$verbose_flag" = true ] && echo "Decrypting file: $file"
    local decrypted_temp_file
    mktemp_to_var decrypted_temp_file || return 1
    if ! gpg "${GPG_ARGS[@]}" -d -o "$decrypted_temp_file" -- "$file"; then
        echo "Error: Failed to decrypt $file." >&2
        return 1
    fi

    # Mask the output if requested
    if [ "$mask_flag" = true ]; then
        if ! sed -i 's/^\(.*\)=.*$/\1=****/' "$decrypted_temp_file"; then
            echo "Error: Failed to mask $decrypted_temp_file." >&2
            return 1
        fi
        [ "$verbose_flag" = true ] && echo "Masked secret values of all variables."
    fi

    # Preprend export if requested
    if [ "$export_flag" = true ]; then
        if ! sed -i 's/^\(.*\)=\(.*\)$/export \1=\2/' "$decrypted_temp_file"; then
            echo "Error: Failed to prepend export to $decrypted_temp_file." >&2
            return 1
        fi
        [ "$verbose_flag" = true ] && echo "Prepended export to all variables."
    fi

    # Send the decrypted content to standard output
    cat "$decrypted_temp_file"
    return 0
}

edit_file() {
    # Print usage on any flag
    while getopts ":" opt; do
        case $opt in
            *) usage ;;
        esac
    done

    # Get file argument
    local file
    file="$(get_file "$1" ".env.gpg")" || return 1

    # Get editor
    if [ -z "$EDITOR" ]; then
        if command -v vim &> /dev/null; then
            EDITOR=vim
        elif command -v nano &> /dev/null; then
            EDITOR=nano
        else
            echo "No editor found. Please set the EDITOR environment variable."
            return 1
        fi
    fi

    # Open the decrypted file in the editor
    local decrypted_temp_file
    mktemp_to_var decrypted_temp_file || return 1
    if ! gpg "${GPG_ARGS[@]}" -d -o "$decrypted_temp_file" -- "$file"; then
        echo "Error: Failed to decrypt $file." >&2
        return 1
    fi
    if ! "$EDITOR" "$decrypted_temp_file"; then
        echo "Error: Editor failed." >&2
        return 1
    fi

    # Re-encrypt the file after editing
    local encrypted_temp_file
    mktemp_to_var encrypted_temp_file || return 1
    if ! gpg "${GPG_ARGS[@]}" -c -o "$encrypted_temp_file" -- "$decrypted_temp_file"; then
        echo "Error: Failed to re-encrypt $file." >&2
        return 1
    fi

    # Verify that the re-encryption was successful
    verify_encryption "$decrypted_temp_file" "$encrypted_temp_file"
    local verify_code=$?

    # Check the result of the verification
    if [ $verify_code -ne 0 ]; then
        echo "Warning: Re-encryption failed for $file" >&2
        return 1
    fi
    mv "$encrypted_temp_file" "$file"
}

# Check for command match
case "$command" in
    "encrypt") encrypt_file "$@" ;;
    "decrypt") decrypt_file "$@" ;;
    "edit") edit_file "$@" ;;
    *) usage ;;
esac

# Perform cleanup
exit_code=$?
cleanup_temp_files
exit "$exit_code"
