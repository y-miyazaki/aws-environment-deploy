// Base configuration for this ECS scheduled task
// Shared across all environments; override specific values in env/*.jsonnet as needed
//
// External variables (passed via jsonnet -V):
//   ENV:        environment name (dev, qa, stg, prd)
//   NAME:       scheduled task name (e.g., test-batch)
//   ACCOUNT_ID: AWS account ID
//   AWS_REGION: AWS region (default: ap-northeast-1)
//
// Used by templates/scheduled-task-config.entry.jsonnet
// To create a new scheduled task: copy this directory (no edits needed; name comes from NAME)

local globalConfig = import '../../../config.jsonnet';
local config = globalConfig;
local prefix = config.env;
local accountId = config.accountId;
local region = config.region;

// Batch name — derived from the NAME external variable (same value used in registry lookup)
local name = std.extVar('NAME');

// ─────────────────────────────────────────────────────────────────────────────
// Batch-specific settings — modify these when creating a new batch from this template
// Customize per environment in env/dev.jsonnet, env/qa.jsonnet, etc.
// Override examples (use Jsonnet merge operator `+:`):
//   base { base+: { rules+: { schedule_expression: 'cron(0 2 * * ? *)' } } }
//   base { base+: { task+: { container_definitions+: { image_tag: 'v1.0.0' } } } }
//   base { base+: { task+: { container_definitions+: { command: ['--verbose'] } } } }
// ─────────────────────────────────────────────────────────────────────────────

{
  base: {
    name: name,
    // ECS cluster to run this scheduled task on
    // NOTE: Using cluster for testing; for production use the dedicated cluster
    cluster: config.helpers.buildName(prefix, 'recommend-cluster'),
    // Tags applied to the ECS task definition
    // Override: base+: { tags+: [{ key: 'Project', value: 'my-project' }] }
    tags: config.helpers.buildTags(prefix, name),

    // ─── EventBridge / ecschedule settings ───────────────────────────────────
    // Controls EventBridge rule configuration managed by ecschedule
    // Fields commented out will fall back to globalConfig defaults in entry.jsonnet
    rules: {
      description: 'Scheduled batch: ' + name,
      // Daily at 00:00 UTC; adjust per environment in env/*.jsonnet
      schedule_expression: 'cron(0 0 * * ? *)',
      // EventBridge IAM role — reusing batch's role for testing purposes
      // NOTE: For production, create a dedicated role via module.ecs_fargate_scheduled_task
      // NOTE: Use role name only (not full ARN) to match ecschedule's internal normalization
      events_role: config.helpers.buildName(prefix, 'recommend-batch-st-cw-role'),
      container_overrides: {
        // Override: rules+: { container_overrides+: { command: ['--flag'] } }
        command: [],
      },
      // Uncomment to override network_configuration (default: VPC private subnets from tfstate):
      // network_configuration: {
      //   aws_vpc_configuration: {
      //     assign_public_ip: 'DISABLED',
      //     security_groups: ['sg-xxxx'],
      //     subnets: ['subnet-xxxx', 'subnet-yyyy'],
      //   },
      // },
      // Uncomment to override platform_version (default: globalConfig.service.platform_version):
      // platform_version: 'LATEST',
    },

    // ─── Task definition settings (ecspresso) ────────────────────────────────
    // Controls ECS task definition
    // Fields commented out will fall back to globalConfig defaults in entry.jsonnet
    task: {
      // IAM roles — using cluster's execution role for testing purposes
      // NOTE: For production, use the dedicated execution role
      role_arn: config.helpers.buildRoleArn(accountId, prefix, 'ecs-batch-role'),
      execution_role_arn: config.helpers.buildRoleArn(accountId, prefix, 'recommend-batch-ecs-task-execution-role'),
      // Uncomment to override task-level defaults (globalConfig.task):
      // cpu: '1024',
      // memory: '3072',
      // network_mode: 'awsvpc',
      // requires_compatibilities: ['FARGATE'],
      // Uncomment to override runtime platform (default: ARM64 / LINUX):
      // runtime_platform: { cpu_architecture: 'X86_64', operating_system_family: 'LINUX' },
      container_definitions: {
        readonly_root_filesystem: true,
        // Image settings — default: ECR repository named after this batch
        // Override when reusing another service image or using an external image
        image_repository: '%s.dkr.ecr.%s.amazonaws.com/%s' % [accountId, region, name],
        image_tag: 'latest',
        command: [],
        // Environment variables; override: task+: { container_definitions+: { environment+: [...] } }
        environment: [
          { name: 'ENV', value: prefix },
          { name: 'AWS_REGION', value: region },
          { name: 'TZ', value: 'Asia/Tokyo' },
        ],
        // Secrets; override: task+: { container_definitions+: { secrets+: [...] } }
        secrets: [],
        // Uncomment to override container-level defaults (globalConfig.task.container_definitions):
        // cpu: 1024,
        // memory: 3072,
        // memory_reservation: 1024,
        // start_timeout: 60,
      },
    },
  },
}
