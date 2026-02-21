// Base configuration for this ECS service
// Shared across all environments; override specific values in env/*.jsonnet as needed
//
// External variables (passed via jsonnet -V):
//   ENV:        environment name (dev, qa, stg, prd)
//   NAME:       service name (e.g., test-server)
//   ACCOUNT_ID: AWS account ID
//   AWS_REGION: AWS region (default: ap-northeast-1)
//
// Used by templates/service-definition.entry.jsonnet and templates/task-definition.entry.jsonnet
//
// To create a new service: copy this directory (no edits needed; name comes from NAME)

local globalConfig = import '../../../config.jsonnet';
local config = globalConfig;
local prefix = config.env;
local accountId = config.accountId;
local region = config.region;

// Service name — derived from the NAME external variable (same value used in registry lookup)
local name = std.extVar('NAME');

// ─────────────────────────────────────────────────────────────────────────────
// Service-specific settings — modify these when creating a new service from this template
// Customize per environment in env/dev.jsonnet, env/qa.jsonnet, etc.
// Override examples (use Jsonnet merge operator `+:`):
//   base { base+: { task+: { container_definitions+: { image_tag: 'v1.0.0' } } } }
//   base { base+: { task+: { container_definitions+: { command: ['server', '--port', '8080'] } } } }
//   base { base+: { task+: { container_definitions+: { environment+: [{ name: 'MY_VAR', value: '1' }] } } } }
// ─────────────────────────────────────────────────────────────────────────────

{
  base: {
    name: name,
    // ECS cluster to run this service on
    cluster: config.helpers.buildName(prefix, 'backend-cluster'),
    // Tags applied to the ECS task definition
    // Override: base+: { tags+: [{ key: 'Project', value: 'my-project' }] }
    tags: config.helpers.buildTags(prefix, name),

    // ─── ECS service settings (ecspresso service layer) ──────────────────────
    // Controls ECS service configuration
    // Fields commented out will fall back to globalConfig defaults in entry.jsonnet
    service: {
      container_port: 8080,
      // ALB target group ARN for service registration
      // target_group_arn: '{{ tfstate `module.%s.aws_lb_target_group.this["%s-ecs"].arn` }}' % [config.terraform_modules.alb_target_group, name],
      // Uncomment to override service-level defaults (globalConfig.service):
      // desired_count: 1,
      // healthcheck_grace_period_seconds: 60,
      // platform_version: 'LATEST',
      // propagate_tags: 'SERVICE',
      // deployment_configuration: { maximum_percent: 200, minimum_healthy_percent: 100 },
      // Uncomment to override network_configuration (default: VPC private subnets from tfstate):
      // network_configuration: {
      //   awsvpc_configuration: {
      //     assign_public_ip: 'DISABLED',
      //     security_groups: ['sg-xxxx'],
      //     subnets: ['subnet-xxxx', 'subnet-yyyy'],
      //   },
      // },
    },

    // ─── Task definition settings (ecspresso) ────────────────────────────────
    // Controls ECS task definition
    // Fields commented out will fall back to globalConfig defaults in entry.jsonnet
    task: {
      // IAM roles — using existing backend roles
      role_arn: config.helpers.buildRoleArn(accountId, prefix, 'ecs-batch-role'),
      // NOTE: For production, consider a dedicated execution role per service
      execution_role_arn: config.helpers.buildRoleArn(accountId, prefix, 'backend-ecs-task-execution-role'),
      // Uncomment to override task-level defaults (globalConfig.task):
      // cpu: '1024',
      // memory: '3072',
      // network_mode: 'awsvpc',
      // requires_compatibilities: ['FARGATE'],
      // Uncomment to override runtime platform (default: ARM64 / LINUX):
      // runtime_platform: { cpu_architecture: 'X86_64', operating_system_family: 'LINUX' },
      container_definitions: {
        readonly_root_filesystem: true,
        // Image settings — default: ECR repository named after this service
        // Override when reusing another service image or using an external image
        image_repository: '%s.dkr.ecr.%s.amazonaws.com/%s' % [accountId, region, name],
        image_tag: 'latest',
        // Command to run in the container — default: empty (uses Docker image ENTRYPOINT/CMD)
        command: [],
        // Environment variables; override: task+: { container_definitions+: { environment+: [...] } }
        environment: [
          { name: 'AWS_REGION', value: region },
          { name: 'TZ', value: 'Asia/Tokyo' },
        ],
        // Secrets; override: task+: { container_definitions+: { secrets+: [...] } }
        secrets: [
          {
            name: 'DB_PASSWORD',
            valueFrom: config.helpers.buildSecretsManager(region, accountId, '%s/db/credentials:password::' % prefix),
          },
        ],
        // Uncomment to override container-level defaults (globalConfig.task.container_definitions):
        // cpu: 1024,
        // memory: 3072,
        // memory_reservation: 1024,
        // start_timeout: 60,
      },
    },
  },
}
