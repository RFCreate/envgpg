#!/bin/sh

usage() {
    case "$command" in
        "encrypt")
            echo "Usage: envgpg encrypt [<flags>] [<file>]"
            echo "Description: Encrypt .env file using GPG."
            echo "Options:"
            echo "  -n        Dry run expected result"
            echo "  -r        Remove original .env after encryption"
            echo "  -v        Print verbose output"
            echo "  -y        Assume yes for all prompts"
            echo "  <file>    File to encrypt (default: .env)"
            ;;
        "decrypt")
            echo "Usage: envgpg decrypt [<flags>] [<file>]"
            echo "Description: Decrypt the .env file using GPG to standard output."
            echo "Options:"
            echo "  -e        Prepend 'export' before each variable"
            echo "  -m        Mask secrets in the output"
            echo "  -n        Dry run expected result"
            echo "  -v        Print verbose output"
            echo "  -w        Write decrypted content to a file"
            echo "  -y        Assume yes for all prompts"
            echo "  <file>    File to decrypt (default: .env.gpg)"
            ;;
        "edit")
            echo "Usage: envgpg edit [<file>]"
            echo "Description: Edit encrypted .env file in \$EDITOR."
            echo "Options:"
            echo "  <file>    File to edit (default: .env.gpg)"
            ;;
        *)
            echo "Usage: envgpg <command> [<flags>] [<file>]"
            echo ""
            echo "Commands:"
            echo "  encrypt     encrypt .env file"
            echo "  decrypt     decrypt .env file"
            echo "  edit        edit encrypted .env in place"
            ;;
    esac
    echo ""
    exit 0
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

# Initialize flags
export_flag=false
mask_flag=false
dry_run_flag=false
remove_flag=false
verbose_flag=false
write_flag=false
yes_flag=false

# Check for flag match
OPTIND=1
while getopts ":emnrwvy" opt; do
    case $opt in
        e) export_flag=true ;;
        m) mask_flag=true ;;
        n) dry_run_flag=true ;;
        r) remove_flag=true ;;
        w) write_flag=true ;;
        v) verbose_flag=true ;;
        y) yes_flag=true ;;
        *) usage ;;
    esac
done

# Skip flags in script arguments
shift "$((OPTIND - 1))"

# Check for command match
case "$command" in
    "encrypt") encrypt_file "$@" ;;
    "decrypt") decrypt_file "$@" ;;
    "edit") edit_file "$1" ;;
    *) usage ;;
esac
