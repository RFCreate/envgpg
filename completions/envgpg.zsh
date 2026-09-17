#compdef envgpg

_envgpg() {
    local -a commands

    commands=(
        'encrypt:Encrypt .env file'
        'decrypt:Decrypt .env file'
        'edit:Edit encrypted .env'
    )

    if (( CURRENT == 2 )); then
        _describe 'command' commands
        return
    fi

    case "$words[2]" in
        encrypt)
            _arguments \
                '1: :()' \
                '(-n -r -v -y)'{-n,-r,-v,-y} \
                '*:file:_files'
            ;;
        decrypt)
            _arguments \
                '1: :()' \
                '(-c -e -m)'{-c,-e,-m} \
                '*:file:_files'
            ;;
        edit)
            _arguments '1: :()' '*:file:_files'
            ;;
    esac
}
