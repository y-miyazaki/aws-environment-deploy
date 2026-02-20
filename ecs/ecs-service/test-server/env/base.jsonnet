// Base configuration for this ECS service
// Shared across all environments; override specific values in env/*.jsonnet as needed
//
// External variables (passed via jsonnet -V):
//   ENV: environment name (dev, qa, stg, prd)
//   ACCOUNT_ID: AWS account ID
//   AWS_REGION: AWS region (default: ap-northeast-1)
//
// Used by templates/service-definition.entry.jsonnet and templates/task-definition.entry.jsonnet
//
// To create a new service: copy this directory and update the local `base` section

local globalConfig = import '../../../config.jsonnet';
local config = globalConfig;
local prefix = config.env;
local accountId = config.accountId;
local region = config.region;

// ─────────────────────────────────────────────────────────────────────────────
// Service-specific settings — modify these when creating a new service from this template
// Customize per environment in env/dev.jsonnet, env/qa.jsonnet, etc.
// Examples:
//   base { base+: { image_tag: 'v1.0.0' } }                           // Use specific image tag
//   base { base+: { command: ['server', '--port', '8080'] } }          // Override command
//   base { base+: { environment+: [{ name: 'MY_VAR', value: '1' }] } } // Add env var
// ─────────────────────────────────────────────────────────────────────────────

{
  base: {
    name: 'test-server',
    // ECS cluster to run this service on
    cluster: config.helpers.buildName(prefix, 'test-cluster'),
    container_port: 8080,
    readonly_root_filesystem: true,
    // Image settings — default: ECR repository named after this service
    // Override image_repository when reusing another service image or using an external image:
    //   image_repository: '123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/other-service'
    //   image_repository: 'public.ecr.aws/nginx/nginx'
    image_repository: '%s.dkr.ecr.%s.amazonaws.com/%s' % [accountId, region, self.name],
    image_tag: 'latest',
    // Command to run in the container — default: empty (uses Docker image ENTRYPOINT/CMD)
    // Override when the container needs an explicit startup command:
    //   base+: { command: ['server', '--port', '8080'] }
    command: [],
    // Tags applied to the ECS task definition
    // Override per environment in env/*.jsonnet:
    //   base+: { tags+: [{ key: 'Project', value: 'my-project' }] }
    tags: config.helpers.buildTags(prefix, self.name),
    // ALB target group ARN for service registration
    target_group_arn: '{{ tfstate `module.%s.aws_lb_target_group.this["%s-ecs"].arn` }}' % [config.terraform_modules.alb_target_group, self.name],
    // IAM roles — using existing backend roles
    task_role_arn: config.helpers.buildRoleArn(accountId, prefix, 'ecs-batch-role'),
    // NOTE: For production, consider a dedicated execution role per service
    execution_role_arn: config.helpers.buildRoleArn(accountId, prefix, 'test-ecs-task-execution-role'),
    // Environment variables injected into the container
    // Override per environment in env/*.jsonnet:
    //   base+: { environment+: [{ name: 'MY_VAR', value: 'value' }] }
    environment: [
      { name: 'AWS_REGION', value: region },
      { name: 'TZ', value: 'Asia/Tokyo' },
    ],
    // Secrets from SecretsManager / SSM injected into the container
    // Example:
    //   base+: { secrets+: [{ name: 'API_KEY', valueFrom: config.helpers.buildSecretsManager(region, accountId, '%s/api/key::' % prefix) }] }
    secrets: [
      {
        name: 'DB_PASSWORD',
        valueFrom: config.helpers.buildSecretsManager(region, accountId, '%s/db/credentials:password::' % prefix),
      },
    ],
  },
}
