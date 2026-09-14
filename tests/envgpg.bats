#!/usr/bin/env bats

setup_file() {
    export GNUPGHOME="$(mktemp -d)"
    printf '%s\n' "$GNUPGHOME" > "$BATS_FILE_TMPDIR/gnupg.path"
    gpg --batch --passphrase '' \
        --quick-generate-key 'envgpg Bats Test <envgpg-bats@example.test>' \
        rsa2048 encrypt 1d >/dev/null 2>&1
}

teardown_file() {
    rm -rf -- "$(cat "$BATS_FILE_TMPDIR/gnupg.path")"
}

setup() {
    export GNUPGHOME="$(cat "$BATS_FILE_TMPDIR/gnupg.path")"
    SCRIPT="$BATS_TEST_DIRNAME/../envgpg.sh"
    BASH_PATH="$(command -v bash)"
    ORIGINAL_PATH="$PATH"
    WORKDIR="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
}

create_encrypted_fixture() {
    printf '%s\n' \
        'API_KEY=secret-value' \
        'EMPTY_VALUE=' \
        '# a comment' > source.env
    gpg --batch --yes --trust-model always \
        --recipient 'envgpg Bats Test <envgpg-bats@example.test>' \
        --output fixture.env.gpg --encrypt -- source.env
    rm source.env
}

create_fail_gpg() {
    mkdir -p bin
    cat > bin/gpg <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x bin/gpg
    PATH="$WORKDIR/bin:$PATH"
    export PATH
}

create_fake_gpg() {
    mkdir -p bin
    cat > bin/gpg <<'EOF'
#!/usr/bin/env bash
output=""
input=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) output=$2; shift 2 ;;
        --) input=$2; shift 2 ;;
        *) shift ;;
    esac
done
[ -n "$output" ] && [ -n "$input" ] || exit 1
cp -- "$input" "$output"
EOF
    chmod +x bin/gpg
    PATH="$WORKDIR/bin:$PATH"
    export PATH
}

create_mock_editor() {
    cat > bin/mock-editor <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'EDITED_VALUE=updated' >> "$1"
EOF
    chmod +x bin/mock-editor
    EDITOR="$WORKDIR/bin/mock-editor"
    export EDITOR
}

create_fail_cmp() {
    cat > bin/cmp <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x bin/cmp
}

restore_cmp() {
    if [ -x "$WORKDIR/bin/cmp" ]; then
        rm -f "$WORKDIR/bin/cmp"
    fi
}

create_noop_editor() {
    cat > bin/noop-editor <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x bin/noop-editor
    EDITOR="$WORKDIR/bin/noop-editor"
    export EDITOR
}

create_no_editor_path() {
    mkdir -p no-editor-bin
    ln -s "$(command -v gpg)" no-editor-bin/gpg
    ln -s "$(command -v bash)" no-editor-bin/bash
    ln -s "$(command -v mktemp)" no-editor-bin/mktemp
    ln -s "$(command -v rm)" no-editor-bin/rm
    PATH="$WORKDIR/no-editor-bin"
    export PATH
}

@test "prints usage and fails without a command" {
    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: envgpg <command>"* ]]
}

@test "rejects an unknown command" {
    run "$SCRIPT" unknown

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: envgpg <command>"* ]]
}

@test "rejects an invalid encrypt flag" {
    run "$SCRIPT" encrypt -z

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: envgpg encrypt"* ]]
}

@test "rejects an invalid decrypt flag" {
    run "$SCRIPT" decrypt -z

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: envgpg decrypt"* ]]
}

@test "rejects an invalid edit flag" {
    run "$SCRIPT" edit -z

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: envgpg edit"* ]]
}

@test "encrypt dry-run reports the output without creating it" {
    printf '%s\n' 'API_KEY=secret-value' > .env

    run "$SCRIPT" encrypt -n .env

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry run: would generate .env.gpg"* ]]
    [ ! -e .env.gpg ]
}

@test "encrypt rejects a missing input file" {
    run "$SCRIPT" encrypt missing.env

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: File missing.env does not exist."* ]]
}

@test "encrypts the input file and preserves the original" {
    create_fake_gpg
    printf '%s\n' 'API_KEY=secret-value' > .env

    run "$SCRIPT" encrypt .env

    [ "$status" -eq 0 ]
    [ -f .env ]
    [ -f .env.gpg ]
    cmp .env .env.gpg
}

@test "encrypt -r -y removes the original after encryption" {
    create_fake_gpg
    printf '%s\n' 'API_KEY=secret-value' > .env

    run "$SCRIPT" encrypt -r -y .env

    [ "$status" -eq 0 ]
    [ ! -e .env ]
    [ -f .env.gpg ]
}

@test "encrypt -r accepts interactive yes input" {
    create_fake_gpg
    printf '%s\n' 'API_KEY=secret-value' > .env

    run bash -c "printf 'y\n' | '$SCRIPT' encrypt -r .env"

    [ "$status" -eq 0 ]
    [ ! -e .env ]
    [ -f .env.gpg ]
}

@test "encrypt -r preserves the original after interactive no input" {
    create_fake_gpg
    printf '%s\n' 'API_KEY=secret-value' > .env

    run bash -c "printf 'n\n' | '$SCRIPT' encrypt -r .env"

    [ "$status" -eq 0 ]
    [ -f .env ]
    [ -f .env.gpg ]
}

@test "encryption failure preserves the original file" {
    create_fail_gpg
    printf '%s\n' 'API_KEY=secret-value' > .env

    run "$SCRIPT" encrypt -r -y .env

    [ "$status" -ne 0 ]
    [ -f .env ]
    [ ! -e .env.gpg ]
}

@test "encryption verification failure preserves the original file" {
    create_fake_gpg
    create_fail_cmp
    printf '%s\n' 'API_KEY=secret-value' > .env

    run "$SCRIPT" encrypt -r -y .env

    [ "$status" -ne 0 ]
    [ -f .env ]
    [ -f .env.gpg ]
}

@test "encrypt overwrites an existing output with -y" {
    create_fake_gpg
    printf '%s\n' 'API_KEY=new-value' > .env
    printf '%s\n' 'OLD_CIPHERTEXT=1' > .env.gpg

    run "$SCRIPT" encrypt -y .env

    [ "$status" -eq 0 ]
    cmp .env .env.gpg
}

@test "encrypt accepts to overwrite an existing output" {
    create_fake_gpg
    printf '%s\n' 'API_KEY=new-value' > .env
    printf '%s\n' 'OLD_CIPHERTEXT=1' > .env.gpg

    run bash -c "printf 'y\n' | '$SCRIPT' encrypt .env"

    [ "$status" -eq 0 ]
    cmp .env .env.gpg
}

@test "encrypt declines to overwrite an existing output" {
    create_fake_gpg
    printf '%s\n' 'API_KEY=new-value' > .env
    printf '%s\n' 'OLD_CIPHERTEXT=1' > .env.gpg

    run bash -c "printf 'n\n' | '$SCRIPT' encrypt .env"

    [ "$status" -eq 0 ]
    grep -Fx 'OLD_CIPHERTEXT=1' .env.gpg
}

@test "encrypt -y overwrites an existing output" {
    create_fake_gpg
    printf '%s\n' 'API_KEY=new-value' > .env
    printf '%s\n' 'OLD_CIPHERTEXT=1' > .env.gpg

    run "$SCRIPT" encrypt -y .env

    [ "$status" -eq 0 ]
    cmp .env .env.gpg
}

@test "decrypt dry-run reports stdout mode" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -n fixture.env.gpg

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry run: would decrypt fixture.env.gpg"* ]]
}

@test "decrypt rejects a missing input file" {
    run "$SCRIPT" decrypt missing.env

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: File missing.env does not exist."* ]]
}

@test "decrypts to standard output" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt fixture.env.gpg

    [ "$status" -eq 0 ]
    [[ "$output" == *"API_KEY=secret-value"* ]]
    [[ "$output" == *"EMPTY_VALUE="* ]]
}

@test "masks values without masking comments" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -m fixture.env.gpg

    [ "$status" -eq 0 ]
    [[ "$output" == *"API_KEY=****"* ]]
    [[ "$output" == *"EMPTY_VALUE=****"* ]]
    [[ "$output" == *"# a comment"* ]]
    [[ "$output" != *"secret-value"* ]]
}

@test "prepends export to variable assignments" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -e fixture.env.gpg

    [ "$status" -eq 0 ]
    [[ "$output" == *"export API_KEY=secret-value"* ]]
    [[ "$output" == *"export EMPTY_VALUE="* ]]
}

@test "combines export and masking transforms" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -e -m fixture.env.gpg

    [ "$status" -eq 0 ]
    [[ "$output" == *"export API_KEY=****"* ]]
    [[ "$output" == *"export EMPTY_VALUE=****"* ]]
    [[ "$output" == *"# a comment"* ]]
    [[ "$output" != *"secret-value"* ]]
}

@test "writes decrypted content to a file" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -w fixture.env.gpg

    [ "$status" -eq 0 ]
    [ -f fixture.env ]
    grep -Fx 'API_KEY=secret-value' fixture.env
}

@test "declines to overwrite an existing decrypted file" {
    create_encrypted_fixture
    printf '%s\n' 'KEEP_ME=1' > fixture.env

    run bash -c "printf 'n\n' | '$SCRIPT' decrypt -w fixture.env.gpg"

    [ "$status" -eq 0 ]
    grep -Fx 'KEEP_ME=1' fixture.env
}

@test "accepts to overwrite an existing decrypted file" {
    create_encrypted_fixture
    printf '%s\n' 'OLD_VALUE=1' > fixture.env

    run bash -c "printf 'y\n' | '$SCRIPT' decrypt -w fixture.env.gpg"

    [ "$status" -eq 0 ]
    grep -Fx 'API_KEY=secret-value' fixture.env
    ! grep -Fx 'OLD_VALUE=1' fixture.env
}

@test "decrypt -y overwrites an existing decrypted file" {
    create_encrypted_fixture
    printf '%s\n' 'OLD_VALUE=1' > fixture.env

    run "$SCRIPT" decrypt -w -y fixture.env.gpg

    [ "$status" -eq 0 ]
    grep -Fx 'API_KEY=secret-value' fixture.env
    ! grep -Fx 'OLD_VALUE=1' fixture.env
}

@test "failed decryption does not overwrite the destination" {
    printf '%s\n' 'KEEP_ME=1' > bad.env
    printf '%s\n' 'not encrypted data' > bad.env.gpg

    run "$SCRIPT" decrypt -w bad.env.gpg

    [ "$status" -ne 0 ]
    grep -Fx 'KEEP_ME=1' bad.env
}

@test "does not write to a file when gpg fails" {
    create_fail_gpg
    printf '%s\n' 'API_KEY=before' > fixture.env.gpg

    run "$SCRIPT" decrypt -w fixture.env.gpg

    [ "$status" -ne 0 ]
    [ ! -f fixture.env ]
}

@test "edit rejects a missing input file" {
    run "$SCRIPT" edit missing.env

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: File missing.env does not exist."* ]]
}

@test "edit preserves the encrypted file when the editor fails" {
    create_encrypted_fixture
    cp fixture.env.gpg original.env.gpg
    EDITOR=false
    export EDITOR

    run "$SCRIPT" edit fixture.env.gpg

    [ "$status" -ne 0 ]
    cmp fixture.env.gpg original.env.gpg
}

@test "edit preserves the encrypted file when gpg fails" {
    create_fail_gpg
    printf '%s\n' 'API_KEY=before' > fixture.env.gpg
    cp fixture.env.gpg original.env.gpg

    run "$SCRIPT" edit fixture.env.gpg

    [ "$status" -ne 0 ]
    cmp fixture.env.gpg original.env.gpg
}

@test "edit preserves the encrypted file when verification fails" {
    create_fake_gpg
    create_mock_editor
    create_fail_cmp
    printf '%s\n' 'API_KEY=before' > fixture.env.gpg
    cp fixture.env.gpg original.env.gpg

    run "$SCRIPT" edit fixture.env.gpg

    [ "$status" -ne 0 ]
    restore_cmp
    cmp fixture.env.gpg original.env.gpg
}

@test "edit fails when no editor is available" {
    create_fake_gpg
    create_no_editor_path
    unset EDITOR
    printf '%s\n' 'API_KEY=before' > fixture.env.gpg

    run "$BASH_PATH" "$SCRIPT" edit fixture.env.gpg
    PATH="$ORIGINAL_PATH"
    export PATH

    [ "$status" -eq 1 ]
    [[ "$output" == *"No editor found"* ]]
}

@test "edit preserves encrypted content when the editor makes no changes" {
    create_fake_gpg
    create_noop_editor
    printf '%s\n' 'API_KEY=unchanged' > fixture.env.gpg
    cp fixture.env.gpg original.env.gpg

    run "$SCRIPT" edit fixture.env.gpg

    [ "$status" -eq 0 ]
    cmp fixture.env.gpg original.env.gpg
}

@test "edit re-encrypts content changed by a mock editor" {
    create_fake_gpg
    create_mock_editor
    printf '%s\n' 'API_KEY=before' > fixture.env.gpg

    run "$SCRIPT" edit fixture.env.gpg

    [ "$status" -eq 0 ]
    grep -Fx 'API_KEY=before' fixture.env.gpg
    grep -Fx 'EDITED_VALUE=updated' fixture.env.gpg
}
