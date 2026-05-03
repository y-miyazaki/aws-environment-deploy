# Specification

## Overview

This document defines the normative specification for ECS service, scheduled task, and Lambda SAM configuration in this repository.

Audience:
- Engineers implementing or reviewing infrastructure-related changes
- AI coding agents making implementation decisions

## Scope

This specification applies to:
- Jsonnet configuration under `ecs/`
- SAM configuration under `lambda/`
- Deployment scripts under `scripts/terraform/`
- User-facing documentation consistency requirements

## Source of Truth and Priority

Priority order for technical decisions:
1. `docs/specification.md` (this file)
2. Other technical docs under `docs/` that define explicit rules
3. Implementation in code (`ecs/`, `lambda/`, `scripts/terraform/`)
4. User-facing guidance in `README.md`

Interpretation rules:
- `README.md` is optimized for usability and examples.
- `docs/` is normative for architecture and behavior.
- If implementation conflicts with this spec, treat it as drift and report it.

## Core Invariants

### Naming Invariant

For both ECS services and scheduled tasks, the following values must be identical:
- Directory name under `ecs/ecs-service/` or `ecs/ecs-scheduled-task/`
- Registry key in `ecs/registry.jsonnet`
- `NAME` external variable used by Jsonnet/ecspresso

Reason:
- Templates resolve data via `registry.services[name][env]` and `registry.scheduled_tasks[name][env]`.
- Deployment scripts derive `NAME` from the target directory name.

Examples:
- `ecs/ecs-service/test-server` -> registry key `test-server` -> `NAME=test-server`
- `ecs/ecs-scheduled-task/test-batch` -> registry key `test-batch` -> `NAME=test-batch`

### Environment Resolution Invariant

Each registry entry should provide environment keys explicitly (`dev`, `qa`, `stg`, `prd`) unless a change is intentionally scoped and documented.

### Scheduled Task Configuration Invariant

Scheduled task schedule/customization is defined in `env/<env>.jsonnet` overrides, not in ad-hoc inline configuration files.

### Lambda SAM Naming Invariant

For Lambda SAM deployments, the following naming conventions apply:

- Stack name: `${Stage}-${ServiceName}` (defined in `samconfig.toml` per environment)
- Lambda function name: `${Stage}-${ServiceName}-${function_name_suffix}` (defined in `template.yaml`)
- API Gateway name: `${Stage}-${ServiceName}-api`
- IAM role name: `${Stage}-${ServiceName}-lambda-role` (when auto-created)

The `Stage` and `ServiceName` parameters in `samconfig.toml` must be consistent across all environments.

### Lambda SAM Template Invariant

`template.yaml` is the single source of truth for Lambda SAM deployments. Edit it directly.

- Function definitions and infrastructure (API Gateway, IAM, WAF, etc.) both belong in `template.yaml`
- Environment-specific overrides belong in `samconfig.toml`

### Lambda SAM Deploy Script

The entry point for Lambda SAM deployments is `scripts/terraform/aws_deploy_sam.sh`.

```bash
./scripts/terraform/aws_deploy_sam.sh -p lambda -e dev deploy
./scripts/terraform/aws_deploy_sam.sh -p lambda -e dev validate
./scripts/terraform/aws_deploy_sam.sh -p lambda -e dev delete
```

Alternatively, use the Makefile directly from `lambda/`:

```bash
make deploy STAGE=dev
make validate STAGE=dev
```

## AI Decision Rules

When an AI agent edits this repository:
1. Use this spec for behavior and naming decisions.
2. Use `README.md` only for user-facing command/examples quality.
3. Do not silently reinterpret conflicts between docs and code.
4. When conflict is detected, report:
   - conflicting files and sections
   - impact/risk
   - minimal patch options
5. Prefer minimal, backward-compatible changes unless explicitly requested otherwise.

## Validation Expectations

For changes affecting behavior:
- Shell scripts: run syntax validation (`bash -n`) and relevant script validation checks
- Jsonnet: render key entry files with representative `-V` inputs
- SAM templates: run `sam validate --lint` after editing `template.yaml`
- Docs updates: ensure links/headings remain consistent

## Change Management

When introducing a new rule:
1. Update this spec first
2. Align implementation
3. Align `README.md` examples and references
4. Record rationale in `docs/IMPROVEMENTS.md` when relevant
