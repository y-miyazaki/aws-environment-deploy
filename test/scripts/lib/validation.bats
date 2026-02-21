#!/usr/bin/env bats

# Tests for scripts/lib/validation.sh

setup() {
    source "scripts/lib/validation.sh"
}

@test "validate_dependencies detects missing tools" {
    run validate_dependencies "nonexistent_tool_xyz"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing required tools"* ]]
}

@test "validate_dependencies succeeds with existing tools" {
    run validate_dependencies "bash" "sh"
    [ "$status" -eq 0 ]
}

@test "validate_env_vars detects missing variables" {
    unset MISSING_VAR_TEST
    run validate_env_vars "MISSING_VAR_TEST"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing required environment variables"* ]]
}

@test "validate_env_vars succeeds with set variables" {
    export TEST_VAR="value"
    run validate_env_vars "TEST_VAR"
    [ "$status" -eq 0 ]
    unset TEST_VAR
}
