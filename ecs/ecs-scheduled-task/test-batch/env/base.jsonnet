// Base configuration for this ECS scheduled task
// Shared across all environments; override specific values in env/*.jsonnet as needed
//
// External variables (passed via jsonnet -V):
//   ENV:        environment name (dev, qa, stg, prd)
//   ACCOUNT_ID: AWS account ID
//   AWS_REGION: AWS region (default: ap-northeast-1)
//
// Used by templates/scheduled-task-definition.entry.jsonnet
// To create a new scheduled task: copy this directory and update the local `base` section

local globalConfig = import '../../../config.jsonnet';
local config = globalConfig;
local prefix = config.env;
local accountId = config.accountId;
local region = config.region;

// ─────────────────────────────────────────────────────────────────────────────
// Batch-specific settings — modify these when creating a new batch from this template
// Customize per environment in env/dev.jsonnet, env/qa.jsonnet, etc.
// Examples:
//   base { base+: { schedule_expression: 'cron(0 2 * * ? *)' } }  // Override schedule
//   base { base+: { image_tag: 'v1.0.0' } }                       // Use specific image tag
//   base { base+: { command: ['--verbose', '--timeout=300'] } }    // Task-specific options
// ─────────────────────────────────────────────────────────────────────────────

{
  base: {
    name: 'test-batch',
    // ECS cluster to run this scheduled task on
    // NOTE: Using cluster for testing; for production use the dedicated cluster
    cluster: config.helpers.buildName(prefix, 'recommend-cluster'),

    description: 'Scheduled batch: test-batch',
    schedule_expression: 'cron(0 0 * * ? *)',  // Daily at 00:00 UTC; adjust per environment in env/*.jsonnet
    command: [],
    readonly_root_filesystem: true,

    // IAM roles — using cluster's execution role for testing purposes
    // NOTE: For production, use the dedicated execution role (e.g., backend-ecs-task-execution-role)
    task_role_arn: config.helpers.buildRoleArn(accountId, prefix, 'ecs-batch-role'),
    execution_role_arn: config.helpers.buildRoleArn(accountId, prefix, 'recommend-batch-ecs-task-execution-role'),

    // EventBridge IAM role — reusing batch's role for testing purposes
    // NOTE: For production, create a dedicated role via module.ecs_fargate_scheduled_task
    // NOTE: Use role name only (not full ARN) to match ecschedule's internal normalization
    events_role: config.helpers.buildName(prefix, 'recommend-batch-st-cw-role'),

    // Image settings — default: ECR repository named after this batch
    // Override image_repository when reusing another service image or using an external image:
    //   image_repository: '123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/other-service'
    //   image_repository: 'public.ecr.aws/nginx/nginx'
    image_repository: '%s.dkr.ecr.%s.amazonaws.com/%s' % [accountId, region, self.name],
    image_tag: 'latest',
    // Environment variables injected into the container
    // Override per environment in env/*.jsonnet:
    //   base+: { environment+: [{ name: 'MY_VAR', value: 'value' }] }
    environment: [
      { name: 'ENV', value: prefix },
      { name: 'AWS_REGION', value: region },
      { name: 'TZ', value: 'Asia/Tokyo' },
    ],
    // Secrets from SecretsManager / SSM injected into the container
    // Example:
    //   base+: { secrets+: [{ name: 'DB_PASSWORD', valueFrom: config.helpers.buildSecretsManager(region, accountId, '%s/db/credentials:password' % prefix) }] }
    secrets: [],
    // Tags applied to the ECS task definition
    // Override per environment in env/*.jsonnet:
    //   base+: { tags+: [{ key: 'Project', value: 'my-project' }] }
    tags: config.helpers.buildTags(prefix, self.name),
  },
}
