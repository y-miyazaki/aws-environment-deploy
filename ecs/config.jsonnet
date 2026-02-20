// Global ECS configuration - shared across all services (ecs-service, ecs-scheduled-task etc)
// Usage: local config = import 'config.jsonnet';
// Environment variables (passed via -V flag):
//   ENV: environment name (dev, qa, stg, prd)
//   ACCOUNT_ID: AWS account ID
//   AWS_REGION: AWS region (default: ap-northeast-1)

{
  // Environment variables extraction (from jsonnet -V flags)
  env: std.extVar('ENV'),
  accountId: std.extVar('ACCOUNT_ID'),
  region: std.extVar('AWS_REGION'),

  // Auto-scaling defaults
  auto_scaling: {
    max_capacity: 10,
    min_capacity: 1,
    policies: [
      {
        predefined_metric_type: 'ECSServiceAverageCPUUtilization',
        scale_in_cooldown: 300,
        scale_out_cooldown: 60,
        target_value: 75.0,
      },
      {
        predefined_metric_type: 'ECSServiceAverageMemoryUtilization',
        scale_in_cooldown: 300,
        scale_out_cooldown: 60,
        target_value: 75.0,
      },
    ],
  },

  // Service defaults (includes deployment settings)
  service: {
    desired_count: 1,
    healthcheck_grace_period_seconds: 60,
    platform_version: 'LATEST',
    propagate_tags: 'SERVICE',
    // deploymentConfiguration settings
    deployment_configuration: {
      maximum_percent: 200,
      minimum_healthy_percent: 100,
    },
  },

  // Task defaults
  task: {
    // Task definition root settings
    cpu: '1024',
    memory: '3072',
    network_mode: 'awsvpc',
    requires_compatibilities: ['FARGATE'],
    // runtimePlatform settings
    runtime_platform: {
      cpu_architecture: 'ARM64',
      operating_system_family: 'LINUX',
    },
    // containerDefinitions settings
    // memory_reservation: soft memory limit; typically 30-40% of container memory
    // Formula: memory * 0.33 (can override in env/*.jsonnet)
    container_definitions: {
      cpu: 1024,
      memory: 3072,
      memory_reservation: 1024,  // ~33% of container memory (3072 * 0.33 ≈ 1024)
      start_timeout: 60,
    },
  },

  // Storage paths
  paths: {
    tfstate_bucket: 'base-terraform-state-%s',
    tfstate_file: 'terraform-application.tfstate',
  },

  // Terraform module references (for tfstate interpolation)
  // Customize per environment in env/*.jsonnet if modules differ
  terraform_modules: {
    alb_target_group: 'alb_backend',
    security_group: 'security_group_ecs',
    vpc: 'vpc',
  },

  // Helper functions
  helpers: {
    // Build ECR image URI with optional tag override
    buildImageUri: function(prefix, region, accountId, repo, tag='latest')
      '%s.dkr.ecr.%s.amazonaws.com/%s-%s:%s' % [accountId, region, prefix, repo, tag],

    // Build CloudWatch Logs group name
    buildLogGroup: function(prefix, service_type)
      '/aws/ecs/task-definition/%s-%s' % [prefix, service_type],

    // Build resource name with prefix
    buildName: function(prefix, suffix) '%s-%s' % [prefix, suffix],

    // Build IAM role ARN
    buildRoleArn: function(accountId, env, role_type)
      'arn:aws:iam::%s:role/%s-%s' % [accountId, env, role_type],

    // Build SecretsManager ARN
    buildSecretsManager: function(region, accountId, name)
      'arn:aws:secretsmanager:%s:%s:secret:%s' % [region, accountId, name],

    // Build S3 tfstate URL
    buildTfstateUrl: function(accountId)
      's3://%s/%s' % [
        $.paths.tfstate_bucket % accountId,
        $.paths.tfstate_file,
      ],

    // Build default ECS task definition tags
    // Returns base tags for all tasks: Env and Service.
    // Extend per service/batch via: tags+: [{ key: 'Project', value: 'my-project' }]
    buildTags: function(env, service_name) [
      { key: 'env', value: env },
      { key: 'service', value: service_name },
    ],
  },
}
