#!/usr/bin/env bats

SCRIPT="$(dirname "$BATS_TEST_FILENAME")/../bin/sarcasm.sh"

setup() {
    export NO_CLIPBOARD=1
}

# mocks for clipboards... bit of a disaster
setup_file() {
    export TEST_TMP_DIR=$(mktemp -d -t bats_sarcasm_XXXXXXX)
    cat > "$TEST_TMP_DIR/wl-copy" << 'EOF'
#!/usr/bin/env bash
echo "$1" > "$TEST_TMP_DIR/clipboard_wl.txt"
EOF

    cat > "$TEST_TMP_DIR/xclip" << 'EOF'
#!/usr/bin/env bash
cat > "$TEST_TMP_DIR/clipboard_xclip.txt"
EOF

    chmod +x "$TEST_TMP_DIR/wl-copy" "$TEST_TMP_DIR/xclip"
}

teardown_file() {
    rm -rf "$TEST_TMP_DIR"
}

setup() {
    export NO_CLIPBOARD=1
    export PATH="$TEST_TMP_DIR:$PATH"
    # rm clipboard mock files before each run as they persist between tests...
    rm -f "$TEST_TMP_DIR/clipboard_wl.txt" "$TEST_TMP_DIR/clipboard_xclip.txt"
}

stub_clipboard() {
    unset NO_CLIPBOARD
}

@test "spongecase works" {
    run "$SCRIPT" "howdy"
    [ "$status" -eq 0 ]
    echo "$output"
    [[ "$output" == "hOwDy" ]]
}

@test "-u starts with uppercase" {
    run "$SCRIPT" -u "howdy"
    [ "$status" -eq 0 ]
    [[ "$output" == "HoWdY" ]]
}

@test "default forces starting with lowercase" {
    run "$SCRIPT" "Howdy"
    [ "$status" -eq 0 ]
    [[ "$output" == "hOwDy" ]]
}

@test "mixing cases" {
    run "$SCRIPT" "mixing CASES"
    [ "$status" -eq 0 ]
    [[ "$output" == "miXiNg cAsEs" ]]
}

@test "force upper (L, T) and force lower (i, j)" {
    run "$SCRIPT" "ttlIJ"
    [ "$status" -eq 0 ]
    [[ "$output" == "TTLij" ]]
}

@test "preserve non-letters" {
    run "$SCRIPT" "Hello, World! 123 @ test"
    [ "$status" -eq 0 ]
    [[ "$output" == "hELLo, WoRLd! 123 @ TeST" ]]
}

@test "handles strings with special characters" {
    run "$SCRIPT" "How's this working? 🤔"
    [ "$status" -eq 0 ]
    [[ "$output" == "hOw's ThiS WoRkiNg? 🤔" ]]
}

@test "empty string" {
    run "$SCRIPT" ""
    [ "$status" -eq 0 ]
    [[ "$output" == "" ]]
}

@test "debug mode prints detailed output" {
    run "$SCRIPT" -d "Ho"
    [ "$status" -eq 0 ]
    readarray -t lines <<< "$output"
    [[ "${lines[0]}" == "Letter 1: H" ]]
    [[ "${lines[1]}" == "Letter 1 (processed): h" ]]
    [[ "${lines[2]}" == "Letter 2: o" ]]
    [[ "${lines[3]}" == "Letter 2 (processed): O" ]]
    [[ "${lines[4]}" == "hO" ]]
}

# Clipboard tests
@test "show clipboard message by default and writes to clipboard" {
    stub_clipboard

    run "$SCRIPT" "clipboard working?"
    [ "$status" -eq 0 ]
    [[ "$output" == '"cLiPbOaRd wOrKiNg?" written to clipboard.' ]]
    [[ "$(cat "$TEST_TMP_DIR/clipboard_wl.txt")" == "cLiPbOaRd wOrKiNg?" ]]
    [[ "$(cat "$TEST_TMP_DIR/clipboard_xclip.txt")" == "cLiPbOaRd wOrKiNg?" ]]
}

@test "-n suppresses clipboard and only prints output" {
    stub_clipboard

    run "$SCRIPT" -n "clipboard working?"
    [ "$status" -eq 0 ]
    [[ "$output" == "cLiPbOaRd wOrKiNg?" ]]
    [[ ! -f "$TEST_TMP_DIR/clipboard_wl.txt" ]]
    [[ ! -f "$TEST_TMP_DIR/clipboard_xclip.txt" ]]
}
