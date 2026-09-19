#!/usr/bin/env bats

setup_file() {
    export ORIGINAL_PATH="$PATH"
    export SCRIPT="$BATS_TEST_DIRNAME/../envgpg.sh"
    export MOCKSDIR="$BATS_TEST_DIRNAME/mocks"
}

setup() {
    export ENVGPG_PASSPHRASE="secret"
    export ENVGPG_CIPHER="AES256"
    WORKDIR="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORKDIR"/bin
    cd "$WORKDIR"
    export PATH="$WORKDIR/bin:$PATH"
}

teardown() {
    export PATH="$ORIGINAL_PATH"
}

create_encrypted_fixture() {
    cp "$MOCKSDIR/test.env.gpg" .
}

create_decrypted_fixture() {
    cp "$MOCKSDIR/test.env" .
}

set_gpg_encrypt_fail() {
    export ENVGPG_CIPHER="INVALID"
}

set_gpg_decrypt_fail() {
    export ENVGPG_PASSPHRASE="unknown"
}

create_fail_cmp() {
    cat > bin/cmp <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x bin/cmp
}

remove_fail_cmp() {
    rm -f bin/cmp
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
    BASH_PATH="$(command -v bash)"
    mkdir -p no-editor-bin
    touch no-editor-bin/gpg
    PATH="$WORKDIR/no-editor-bin"
    export PATH
    unset EDITOR
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

@test "encrypt rejects a missing input file" {
    run "$SCRIPT" encrypt missing.env

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: File missing.env does not exist."* ]]
}

@test "encrypt dry-run reports the output without creating it" {
    create_decrypted_fixture

    run "$SCRIPT" encrypt -n test.env

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry run: would generate test.env.gpg"* ]]
    [ ! -e test.env.gpg ]
}

@test "encrypt dry-run with remove flag reports the output without creating it" {
    create_decrypted_fixture

    run "$SCRIPT" encrypt -n -r test.env

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry run: would generate test.env.gpg"* ]]
    [[ "$output" == *"Dry run: would remove test.env"* ]]
    [ ! -e test.env.gpg ]
}

@test "encrypt preserves the original" {
    create_decrypted_fixture

    run "$SCRIPT" encrypt test.env

    [ "$status" -eq 0 ]
    [ -f test.env ]
    [ -f test.env.gpg ]
}

@test "encrypt from outside the current directory" {
    create_decrypted_fixture
    mkdir -p subdir
    mv test.env subdir

    run "$SCRIPT" encrypt subdir/test.env

    [ "$status" -eq 0 ]
    [ -f subdir/test.env ]
    [ -f subdir/test.env.gpg ]
}

@test "encrypt -r -y removes the original" {
    create_decrypted_fixture

    run "$SCRIPT" encrypt -r -y test.env

    [ "$status" -eq 0 ]
    [ ! -e test.env ]
    [ -f test.env.gpg ]
}

@test "encrypt -r accepts to remove the original" {
    create_decrypted_fixture

    run bash -c "printf 'y\n' | '$SCRIPT' encrypt -r test.env"

    [ "$status" -eq 0 ]
    [ ! -e test.env ]
    [ -f test.env.gpg ]
}

@test "encrypt -r declines to remove the original" {
    create_decrypted_fixture

    run bash -c "printf 'n\n' | '$SCRIPT' encrypt -r test.env"

    [ "$status" -eq 0 ]
    [ -f test.env ]
    [ -f test.env.gpg ]
}

@test "encrypt failure preserves the original file" {
    create_decrypted_fixture
    set_gpg_encrypt_fail

    run "$SCRIPT" encrypt -r -y test.env

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Failed to encrypt test.env."* ]]
    [ -f test.env ]
    [ ! -e test.env.gpg ]
}

@test "encrypt verification failure preserves the original file" {
    create_decrypted_fixture
    create_fail_cmp

    run "$SCRIPT" encrypt -r -y test.env

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: test.env and test.env.gpg do not match"* ]]
    [ -f test.env ]
    [ -f test.env.gpg ]
}

@test "encrypt overwrites an existing output with -y" {
    create_decrypted_fixture
    printf '%s\n' 'OLD_CIPHERTEXT=1' > test.env.gpg

    run "$SCRIPT" encrypt -y test.env

    [ "$status" -eq 0 ]
    ! grep -Fx 'OLD_CIPHERTEXT=1' test.env.gpg
}

@test "encrypt accepts to overwrite an existing output" {
    create_decrypted_fixture
    printf '%s\n' 'OLD_CIPHERTEXT=1' > test.env.gpg

    run bash -c "printf 'y\n' | '$SCRIPT' encrypt test.env"

    [ "$status" -eq 0 ]
    ! grep -Fx 'OLD_CIPHERTEXT=1' test.env.gpg
}

@test "encrypt declines to overwrite an existing output" {
    create_decrypted_fixture
    printf '%s\n' 'OLD_CIPHERTEXT=1' > test.env.gpg

    run bash -c "printf 'n\n' | '$SCRIPT' encrypt test.env"

    [ "$status" -eq 0 ]
    grep -Fx 'OLD_CIPHERTEXT=1' test.env.gpg
}

@test "decrypt rejects a missing input file" {
    run "$SCRIPT" decrypt missing.env

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: File missing.env does not exist."* ]]
}

@test "decrypt to standard output" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt test.env.gpg

    [ "$status" -eq 0 ]
    cmp "$MOCKSDIR/test.env" <(echo "$output")
}

@test "decrypt rejects when gpg decryption fails" {
    create_encrypted_fixture
    set_gpg_decrypt_fail

    run "$SCRIPT" decrypt test.env.gpg

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Failed to decrypt test.env.gpg."* ]]
}

@test "decrypt clean leaves only variable assignments" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -c test.env.gpg

    [ "$status" -eq 0 ]
    cmp <(echo "$output") <<'EOF'
API_KEY=secret-value
EMPTY_VALUE=
SINGLE_QUOTE='single quoted value'
DOUBLE_QUOTE="double quoted value"
EOF
}

@test "decrypt masks variable values" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -m test.env.gpg

    [ "$status" -eq 0 ]
    cmp <(echo "$output") <<'EOF'
API_KEY=**** exec_command
EMPTY_VALUE=**** exec_command

# exec_command
exec_command
SINGLE_QUOTE=**** exec_command
DOUBLE_QUOTE=****;exec_command
EOF
}

@test "decrypt prepends export to variable assignments" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -e test.env.gpg

    [ "$status" -eq 0 ]
    cmp <(echo "$output") <<'EOF'
export API_KEY=secret-value exec_command
export EMPTY_VALUE= exec_command

# exec_command
exec_command
export SINGLE_QUOTE='single quoted value' exec_command
export DOUBLE_QUOTE="double quoted value";exec_command
EOF
}

@test "decrypt combines clean and masking transforms" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -c -m test.env.gpg

    [ "$status" -eq 0 ]
    cmp <(echo "$output") <<'EOF'
API_KEY=****
EMPTY_VALUE=****
SINGLE_QUOTE=****
DOUBLE_QUOTE=****
EOF
}

@test "decrypt combines clean and export transforms" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -c -e test.env.gpg

    [ "$status" -eq 0 ]
    cmp <(echo "$output") <<'EOF'
export API_KEY=secret-value
export EMPTY_VALUE=
export SINGLE_QUOTE='single quoted value'
export DOUBLE_QUOTE="double quoted value"
EOF
}

@test "decrypt combines export and masking transforms" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -e -m test.env.gpg

    [ "$status" -eq 0 ]
    cmp <(echo "$output") <<'EOF'
export API_KEY=**** exec_command
export EMPTY_VALUE=**** exec_command

# exec_command
exec_command
export SINGLE_QUOTE=**** exec_command
export DOUBLE_QUOTE=****;exec_command
EOF
}

@test "decrypt combines clean, masking, and export transforms" {
    create_encrypted_fixture

    run "$SCRIPT" decrypt -c -m -e test.env.gpg

    [ "$status" -eq 0 ]
    cmp <(echo "$output") <<'EOF'
export API_KEY=****
export EMPTY_VALUE=****
export SINGLE_QUOTE=****
export DOUBLE_QUOTE=****
EOF
}

@test "edit rejects a missing input file" {
    run "$SCRIPT" edit missing.env

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: File missing.env does not exist."* ]]
}

@test "edit preserves the encrypted file when the editor fails" {
    create_encrypted_fixture
    EDITOR=false
    export EDITOR

    run "$SCRIPT" edit test.env.gpg

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Editor failed."* ]]
    cmp "$MOCKSDIR/test.env.gpg" test.env.gpg
}

@test "edit preserves the encrypted file when gpg decryption fails" {
    create_encrypted_fixture
    set_gpg_decrypt_fail

    run "$SCRIPT" edit test.env.gpg

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Failed to decrypt test.env.gpg."* ]]
    cmp "$MOCKSDIR/test.env.gpg" test.env.gpg
}

@test "edit preserves the encrypted file when gpg encryption fails" {
    create_encrypted_fixture
    create_mock_editor
    set_gpg_encrypt_fail

    run "$SCRIPT" edit test.env.gpg

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Failed to re-encrypt test.env.gpg."* ]]
    cmp "$MOCKSDIR/test.env.gpg" test.env.gpg
}

@test "edit preserves the encrypted file when verification fails" {
    create_encrypted_fixture
    create_mock_editor
    create_fail_cmp

    run "$SCRIPT" edit test.env.gpg
    remove_fail_cmp

    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Re-encryption verification failed for test.env.gpg."* ]]
    cmp "$MOCKSDIR/test.env.gpg" test.env.gpg
}

@test "edit fails when no editor is available" {
    create_encrypted_fixture
    create_no_editor_path

    run "$BASH_PATH" "$SCRIPT" edit test.env.gpg

    [ "$status" -eq 1 ]
    [[ "$output" == *"No editor found"* ]]
}

@test "edit re-encrypts content when the editor makes no changes" {
    create_encrypted_fixture
    create_noop_editor

    run "$SCRIPT" edit test.env.gpg

    [ "$status" -eq 0 ]
    ! cmp "$MOCKSDIR/test.env.gpg" test.env.gpg
}

@test "edit re-encrypts content changed by a mock editor" {
    create_encrypted_fixture
    create_mock_editor

    run "$SCRIPT" edit test.env.gpg

    [ "$status" -eq 0 ]
    ! cmp "$MOCKSDIR/test.env.gpg" test.env.gpg
}
