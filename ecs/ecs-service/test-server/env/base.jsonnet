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
// ─────────────────────────────────────────────────────────────────────────────
local base = {
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
  //   command: ['server', '--port', '8080']
  command: [],
  // Tags applied to the ECS task definition
  // Override per environment in env/*.jsonnet:
  //   task+: { tags+: [{ key: 'Project', value: 'my-project' }] }
  tags: config.helpers.buildTags(prefix, self.name),

  // ALB target group ARN for service registration
  target_group_arn: '{{ tfstate `module.%s.aws_lb_target_group.this["%s-ecs"].arn` }}' % [config.terraform_modules.alb_target_group, self.name],

  // IAM roles — using existing backend roles
  task_role_arn: config.helpers.buildRoleArn(accountId, prefix, 'ecs-batch-role'),
  // NOTE: For production, consider a dedicated execution role per service
  execution_role_arn: config.helpers.buildRoleArn(accountId, prefix, 'test-ecs-task-execution-role'),
  // Environment variables injected into the container
  // Override per environment in env/*.jsonnet:
  //   task+: { environment+: [{ name: 'MY_VAR', value: 'value' }] }
  environment: [
    {
      name: 'AWS_REGION',
      value: region,
    },
    {
      name: 'TZ',
      value: 'Asia/Tokyo',
    },
  ],
  // Secrets from SecretsManager / SSM injected into the container
  // Example:
  //   secrets: [{ name: 'DB_PASSWORD', valueFrom: config.helpers.buildSecretsManager(region, accountId, '%s/db/credentials:password' % prefix) }]
  secrets: [
    {
      name: 'DB_PASSWORD',
      valueFrom: config.helpers.buildSecretsManager(region, accountId, '%s/db/credentials:password::' % prefix),
    },
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Customization for different environments (override in env/dev.jsonnet, etc.)
// ─────────────────────────────────────────────────────────────────────────────
// Examples:
//   task+: { cpu: '2048', memory: '4096' }  // Increase resources for production
//   task+: { container_definitions+: { cpu: 2048, memory: 4096, memory_reservation: 1500 } }
//   auto_scaling+: { max_capacity: 20, min_capacity: 2 }  // Scale for production
//   service+: { deployment_configuration+: { maximum_percent: 150 } }
//
// ─────────────────────────────────────────────────────────────────────────────
// Exported configuration object
// ─────────────────────────────────────────────────────────────────────────────
{
  // Common
  plugins: [
    {
      name: 'tfstate',
      config: {
        url: config.helpers.buildTfstateUrl(accountId),
      },
    },
  ],
  region: region,
  service_name: base.name,

  // Auto scaling configuration (used by deploy.sh)
  auto_scaling: {
    max_capacity: config.auto_scaling.max_capacity,
    min_capacity: config.auto_scaling.min_capacity,
    policies: config.auto_scaling.policies,
  },

  // Service layer (used by service-definition.jsonnet + ecspresso)
  service: {
    cluster: base.cluster,
    desired_count: config.service.desired_count,
    healthcheck_grace_period_seconds: config.service.healthcheck_grace_period_seconds,
    name: config.helpers.buildName(prefix, '%s-service' % base.name),
    platform_version: config.service.platform_version,
    propagate_tags: config.service.propagate_tags,
    // loadBalancers for ALB integration — registers container with ALB target group
    load_balancers: [
      {
        containerName: config.helpers.buildName(prefix, base.name),
        containerPort: base.container_port,
        targetGroupArn: base.target_group_arn,
      },
    ],
    // deploymentConfiguration settings
    // Override per environment in env/*.jsonnet:
    //   service+: { deployment_configuration+: { maximum_percent: 100 } }
    deployment_configuration: {
      maximum_percent: config.service.deployment_configuration.maximum_percent,
      minimum_healthy_percent: config.service.deployment_configuration.minimum_healthy_percent,
    },
    // networkConfiguration settings
    // Override per environment in env/*.jsonnet:
    //   service+: { network_configuration+: { awsvpc_configuration+: { security_groups: ['sg-xxxx'] } } }
    network_configuration: {
      awsvpc_configuration: {
        assign_public_ip: 'DISABLED',
        security_groups: ['{{ tfstate `module.%s.aws_security_group.this_name_prefix[0].id` }}' % config.terraform_modules.security_group],
        subnets: [
          '{{ tfstate `module.%s.aws_subnet.private[0].id` }}' % config.terraform_modules.vpc,
          '{{ tfstate `module.%s.aws_subnet.private[1].id` }}' % config.terraform_modules.vpc,
          '{{ tfstate `module.%s.aws_subnet.private[2].id` }}' % config.terraform_modules.vpc,
        ],
      },
    },
  },

  // Task layer (used by task-definition.jsonnet + ecspresso)
  task: {
    // Task definition root settings
    cpu: config.task.cpu,
    execution_role_arn: base.execution_role_arn,
    family: config.helpers.buildName(prefix, '%s-td' % base.name),
    memory: config.task.memory,
    network_mode: config.task.network_mode,
    requires_compatibilities: config.task.requires_compatibilities,
    role_arn: base.task_role_arn,
    tags: base.tags,
    // runtimePlatform settings
    runtime_platform: {
      cpu_architecture: config.task.runtime_platform.cpu_architecture,
      operating_system_family: config.task.runtime_platform.operating_system_family,
    },
    // containerDefinitions settings
    // Override per environment in env/*.jsonnet:
    //   task+: { container_definitions+: { image_tag: 'v1.0.0' } }
    container_definitions: {
      cpu: config.task.container_definitions.cpu,
      memory: config.task.container_definitions.memory,
      memory_reservation: config.task.container_definitions.memory_reservation,
      name: config.helpers.buildName(prefix, base.name),
      command: base.command,
      environment: base.environment,
      // Image: default ECR repo based on service name; override image_repository in local base
      // for shared ECR images or external images. Override image_tag per environment via:
      //   task+: { container_definitions+: { image_tag: 'v1.0.0' } }
      image_repository: base.image_repository,
      image_tag: base.image_tag,
      image: '%s:%s' % [self.image_repository, self.image_tag],
      log_configuration: {
        log_driver: 'awslogs',
        options: {
          log_group: config.helpers.buildLogGroup(prefix, base.name),
          create_group: 'true',
          region: region,
          stream_prefix: 'application',
        },
      },
      port_mappings: {
        container_port: base.container_port,
        host_port: base.container_port,
        name: '%s-%s-tcp' % [base.name, base.container_port],
        protocol: 'tcp',
      },
      readonly_root_filesystem: base.readonly_root_filesystem,
      secrets: base.secrets,
      start_timeout: config.task.container_definitions.start_timeout,
    },
  },
}
