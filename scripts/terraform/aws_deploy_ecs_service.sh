#!/bin/bash
#######################################
# Description: Deploy ECS service using ecspresso
#
# Usage: ./aws_deploy_ecs_service.sh [options] [action]
#   actions:
#     deploy   Deploy ECS service with auto-scaling configuration (default)
#     destroy  Destroy ECS service
#     verify   Verify ECS service configuration
#   options:
#     -h, --help             Display this help message
#     -e, --env ENV          Target environment: dev, qa, stg, prd (default: dev)
#     -p, --path PATH        Path to ECS service directory (required)
#     -r, --region REGION    AWS region (default: auto-detected via aws configure get region)
#######################################

# Error handling: exit on error, unset variable, or failed pipeline
set -euo pipefail

# Secure defaults
umask 027
export LC_ALL=C.UTF-8

# Get script directory for library loading
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

# Load all-in-one library
# shellcheck source=../lib/all.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/all.sh"

#######################################
# Global variables and default values
#######################################
ACTION="deploy"
ACCOUNT_ID=""
AWS_REGION="${AWS_REGION:-}"
NAME=""
ENV="dev"
SERVICE_PATH=""

#######################################
# show_usage: Display script usage information
#
# Description:
#   Displays usage information for the script, including actions, options, and examples
#
# Arguments:
#   None
#
# Returns:
#   None (outputs to stdout, then exits with status 0)
#
# Usage:
#   show_usage
#
#######################################
function show_usage {
    cat << EOF
Usage: $(basename "$0") [options] [action]

Description: Deploy ECS service using ecspresso

Actions:
  deploy   Deploy ECS service with auto-scaling configuration (default)
  destroy  Destroy ECS service
  verify   Verify ECS service configuration

Options:
  -h, --help             Display this help message
  -e, --env ENV          Target environment: dev, qa, stg, prd (default: dev)
  -p, --path PATH        Path to ECS service directory (required)
  -r, --region REGION    AWS region (default: auto-detected via aws configure)

Examples:
  $(basename "$0") -p ecs/ecs-service/test-server
  $(basename "$0") -p ecs/ecs-service/test-server -e prd deploy
  $(basename "$0") --path ecs/ecs-service/test-server --env dev verify
EOF
    exit 0
}

#######################################
# parse_arguments: Parse command line arguments
#
# Description:
#   Parses command line arguments and validates required options
#
# Arguments:
#   $@ - All command line arguments passed to the script
#
# Global Variables:
#   ACTION       - Set to the provided action (deploy, verify, destroy)
#   AWS_REGION   - Set to the provided AWS region
#   ENV          - Set to the provided target environment
#   SERVICE_PATH - Set to the provided ECS service directory path
#
# Returns:
#   Exits with error if required options are missing or unknown arguments are given
#
# Usage:
#   parse_arguments "$@"
#
#######################################
function parse_arguments {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h | --help)
                show_usage
                ;;
            -e | --env)
                ENV="$2"
                shift 2
                ;;
            -p | --path)
                SERVICE_PATH="$2"
                shift 2
                ;;
            -r | --region)
                AWS_REGION="$2"
                shift 2
                ;;
            -*)
                error_exit "Unknown option: $1"
                ;;
            deploy | destroy | verify)
                ACTION="$1"
                shift
                ;;
            *)
                error_exit "Unexpected argument: $1"
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "${SERVICE_PATH}" ]]; then
        echo "Error: --path is required" >&2
        show_usage
    fi
}

#######################################
# deploy_service: Deploy ECS service with auto-scaling configuration
#
# Description:
#   Step 1: Checks diffs to determine what has changed
#   Step 2: If changes detected, reads auto-scaling configuration from the
#           environment-specific jsonnet file and deploys using ecspresso
#   Skips deploy if no changes detected (prevents unnecessary task definition
#   revisions and deployment cycles)
#
# Arguments:
#   None
#
# Global Variables:
#   ACCOUNT_ID - AWS account ID
#   AWS_REGION - AWS region
#   ENV        - Target environment name
#   NAME - ECS service name
#
# Returns:
#   Exits with status 0 if no changes detected, non-zero on failure
#
# Usage:
#   deploy_service
#
#######################################
function deploy_service {
    echo_section "Checking diffs before deploy"

    # Check for changes in task definition or service definition
    # Empty stdout = no changes, non-zero exit = error (first deploy)
    local diff_output diff_exit_code
    diff_output=$(ecspresso diff \
        --config ecspresso.jsonnet \
        --ext-str ENV="$ENV" \
        --ext-str NAME="$NAME" \
        --ext-str ACCOUNT_ID="$ACCOUNT_ID" \
        --ext-str AWS_REGION="$AWS_REGION" 2>&1 || true)
    diff_exit_code=$?

    # Filter out log messages: remove lines starting with timestamp patterns or log level markers
    # Improved pattern: ISO timestamps, bracketed log levels, and empty lines
    local actual_diff
    actual_diff=$(echo "$diff_output" | grep -vE '^(\[|[0-9]{4}-[0-9]{2}-[0-9]{2}|time=|level=|\s*$)' || true)

    if [[ -z "$actual_diff" && $diff_exit_code -eq 0 ]]; then
        log "INFO" "Service definition: no changes detected, skipping deploy"
        return 0
    elif [[ -n "$actual_diff" ]]; then
        log "INFO" "Service definition has changes:"
        echo "$actual_diff"
    else
        log "INFO" "Task definition: cannot compare (may be first deploy), will deploy"
    fi

    echo_section "Deploying ECS service"

    # Read auto-scaling config from the environment-specific jsonnet
    local env_config min_capacity max_capacity
    if ! env_config=$(jsonnet \
        -V ENV="$ENV" \
        -V ACCOUNT_ID="$ACCOUNT_ID" \
        -V AWS_REGION="$AWS_REGION" \
        "env/${ENV}.jsonnet" 2>&1); then
        error_exit "Failed to render jsonnet config: $env_config"
    fi

    min_capacity=$(echo "$env_config" | jq -r '.auto_scaling.min_capacity // 1')
    max_capacity=$(echo "$env_config" | jq -r '.auto_scaling.max_capacity // 10')

    # Validate auto-scaling values
    if [[ ! "$min_capacity" =~ ^[0-9]+$ ]] || [[ ! "$max_capacity" =~ ^[0-9]+$ ]]; then
        error_exit "Invalid auto-scaling values: min=$min_capacity, max=$max_capacity"
    fi
    if [[ $min_capacity -gt $max_capacity ]]; then
        error_exit "min_capacity ($min_capacity) cannot exceed max_capacity ($max_capacity)"
    fi

    log "INFO" "Auto-scaling: min=${min_capacity}, max=${max_capacity}"

    if ! ecspresso deploy \
        --config ecspresso.jsonnet \
        --ext-str ENV="$ENV" \
        --ext-str NAME="$NAME" \
        --ext-str ACCOUNT_ID="$ACCOUNT_ID" \
        --ext-str AWS_REGION="$AWS_REGION" \
        --auto-scaling-min="$min_capacity" \
        --auto-scaling-max="$max_capacity"; then
        error_exit "ecspresso deploy failed"
    fi

    log "INFO" "Deployment completed"
}

#######################################
# destroy_service: Destroy ECS service
#
# Description:
#   Destroys the ECS service using ecspresso destroy
#
# Arguments:
#   None
#
# Global Variables:
#   ACCOUNT_ID - AWS account ID
#   AWS_REGION - AWS region
#   ENV        - Target environment name
#
# Returns:
#   Exits with non-zero status on failure
#
# Usage:
#   destroy_service
#
#######################################
function destroy_service {
    ecspresso destroy \
        --config ecspresso.jsonnet \
        --ext-str ENV="$ENV" \
        --ext-str NAME="$NAME" \
        --ext-str ACCOUNT_ID="$ACCOUNT_ID" \
        --ext-str AWS_REGION="$AWS_REGION"

    log "INFO" "Destroy completed"
}

#######################################
# verify_service: Verify ECS service configuration
#
# Description:
#   Verifies that the ECS service configuration is valid using ecspresso verify
#
# Arguments:
#   None
#
# Global Variables:
#   ACCOUNT_ID - AWS account ID
#   AWS_REGION - AWS region
#   ENV        - Target environment name
#
# Returns:
#   Exits with non-zero status on failure
#
# Usage:
#   verify_service
#
#######################################
function verify_service {
    ecspresso verify \
        --config ecspresso.jsonnet \
        --ext-str ENV="$ENV" \
        --ext-str NAME="$NAME" \
        --ext-str ACCOUNT_ID="$ACCOUNT_ID" \
        --ext-str AWS_REGION="$AWS_REGION"

    log "INFO" "Verify completed"
}

#######################################
# main: Script entry point
#
# Description:
#   Main function to execute the ECS service deployment workflow
#
# Arguments:
#   $@ - All command line arguments passed to the script
#
# Global Variables:
#   ACTION       - Action to perform (deploy, verify, destroy)
#   ACCOUNT_ID   - AWS account ID
#   AWS_REGION   - AWS region
#   ENV          - Target environment name
#   SERVICE_PATH - Path to ECS service directory
#
# Returns:
#   Exits with status 0 on success, non-zero on failure
#
# Usage:
#   main "$@"
#
#######################################
function main {
    # Parse arguments
    parse_arguments "$@"

    # Validate required dependencies
    validate_dependencies "aws" "ecspresso" "jq" "jsonnet"

    # Check AWS credentials before any AWS CLI usage
    check_aws_credentials || error_exit "AWS credentials are not set or invalid."

    # Auto-detect ACCOUNT_ID and AWS_REGION from AWS CLI
    ACCOUNT_ID=$(get_aws_account_id) || error_exit "Failed to get AWS account ID"
    AWS_REGION="${AWS_REGION:-$(get_aws_region)}"

    # Resolve service path to absolute path
    local abs_path
    abs_path="$(cd "${SERVICE_PATH}" 2> /dev/null && pwd)" \
        || error_exit "Service path does not exist: ${SERVICE_PATH}"

    echo_section "${ACTION}: ECS service in ${abs_path} -> ${ENV}"
    log "INFO" "Account ID: ${ACCOUNT_ID}"
    log "INFO" "Region: ${AWS_REGION}"

    # Derive service name from the directory name.
    # This NAME value must match the corresponding key in registry.jsonnet
    # so that the service can be correctly looked up in the registry.
    NAME=$(basename "${abs_path}")
    log "INFO" "Service name: ${NAME}"

    # Change to service directory so ecspresso can find ecspresso.jsonnet and env/
    cd "${abs_path}"

    case "$ACTION" in
        deploy)
            deploy_service
            ;;
        destroy)
            destroy_service
            ;;
        verify)
            verify_service
            ;;
        *)
            error_exit "Unknown action: ${ACTION}. Use: deploy, destroy, verify"
            ;;
    esac

    echo_section "Process completed successfully"
}

# Only call main function if script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
