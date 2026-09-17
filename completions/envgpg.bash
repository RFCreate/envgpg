_envgpg()
{
    local current command
    local -a commands encrypt_options decrypt_options

    current="${COMP_WORDS[COMP_CWORD]}"
    command="${COMP_WORDS[1]}"

    commands=(encrypt decrypt edit)
    encrypt_options=(-n -r -v -y)
    decrypt_options=(-c -e -m)

    if (( COMP_CWORD == 1 )); then
        COMPREPLY=( $(compgen -W "${commands[*]}" -- "$current") )
        return 0
    fi

    case "$command" in
        encrypt)
            if [[ "$current" == -* ]]; then
                COMPREPLY=( $(compgen -W "${encrypt_options[*]}" -- "$current") )
            else
                _envgpg_complete_files "$current"
            fi
            ;;
        decrypt)
            if [[ "$current" == -* ]]; then
                COMPREPLY=( $(compgen -W "${decrypt_options[*]}" -- "$current") )
            else
                _envgpg_complete_files "$current"
            fi
            ;;
        edit)
            if [[ "$current" == -* ]]; then
                COMPREPLY=()
            else
                _envgpg_complete_files "$current"
            fi
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

_envgpg_complete_files()
{
    local cur=$1 match

    if declare -F _filedir >/dev/null; then
        _filedir
    else
        while IFS= read -r match; do
            COMPREPLY+=("$match")
        done < <(compgen -f -- "$cur")
    fi
}

complete -F _envgpg envgpg
