#!/usr/bin/env bats

# Tests for scripts/lib/common.sh

setup() {
    # Source library (tests run from repo root)
    source "scripts/lib/common.sh"
}

@test "execute_command executes the command and logs when VERBOSE=true" {
    DRY_RUN=false
    VERBOSE=true
    run execute_command echo hi_there
    [ "$status" -eq 0 ]
    # Should include the debug log line about Executing and the command output
    [[ "$output" == *"Executing: echo hi_there"* ]]
    [[ "$output" == *"hi_there"* ]]
}

@test "execute_command in dry-run mode only logs planned command" {
    DRY_RUN=true
    run execute_command echo hello world
    [ "$status" -eq 0 ]
    # Use substring match to avoid regex quoting issues
    [[ "$output" == *"DRY-RUN: Would execute: echo hello world"* ]]
}

@test "is_dry_run returns non-zero when DRY_RUN is false/unset" {
    unset DRY_RUN
    run is_dry_run
    [ "$status" -ne 0 ]
}

@test "is_dry_run returns success when DRY_RUN=true" {
    DRY_RUN=true
    run is_dry_run
    [ "$status" -eq 0 ]
}

@test "log prints ERROR messages regardless of VERBOSE" {
    unset VERBOSE
    run log ERROR "fatal"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR] fatal"* ]]
}

@test "error_exit displays error and exits with code 1" {
    run error_exit "test error"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: test error"* ]]
}

@test "error_exit exits with custom code" {
    run error_exit "test error" 42
    [ "$status" -eq 42 ]
}

@test "validate_dependencies with multiple missing tools" {
    run validate_dependencies "bash" "nonexistent1" "nonexistent2"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nonexistent1"* ]]
    [[ "$output" == *"nonexistent2"* ]]
}

@test "validate_env_vars with multiple variables" {
    export VAR1="value1"
    export VAR2="value2"
    run validate_env_vars "VAR1" "VAR2"
    [ "$status" -eq 0 ]
    unset VAR1 VAR2
}

@test "get_start_time returns numeric timestamp" {
    run get_start_time
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}
