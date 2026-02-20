// Base configuration for this ECS scheduled task
// Shared across all environments; override specific values in env/*.jsonnet as needed
//
// External variables (passed via jsonnet -V):
//   ENV:        environment name (dev, qa, stg, prd)
//   ACCOUNT_ID: AWS account ID
//   AWS_REGION: AWS region (default: ap-northeast-1)
local globalConfig = import '../../../config.jsonnet';
local config = globalConfig;
local prefix = config.env;
local accountId = config.accountId;
local region = config.region;

// ─────────────────────────────────────────────────────────────────────────────
// Batch-specific settings — modify these when creating a new batch from this template
// ─────────────────────────────────────────────────────────────────────────────
local batch = {
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
  //   task+: { environment+: [{ name: 'MY_VAR', value: 'value' }] }
  environment: [
    { name: 'ENV', value: prefix },
    { name: 'AWS_REGION', value: region },
    { name: 'TZ', value: 'Asia/Tokyo' },
  ],
  // Secrets from SecretsManager / SSM injected into the container
  // Example:
  //   secrets: [{ name: 'DB_PASSWORD', valueFrom: config.helpers.buildSecretsManager(region, accountId, '%s/db/credentials:password' % prefix) }]
  secrets: [],
  // Tags applied to the ECS task definition
  // Override per environment in env/*.jsonnet:
  //   task+: { tags+: [{ key: 'Project', value: 'my-project' }] }
  tags: config.helpers.buildTags(prefix, self.name),
};

// ─────────────────────────────────────────────────────────────────────────────
// Exported configuration object
// ─────────────────────────────────────────────────────────────────────────────
local container_name = config.helpers.buildName(prefix, batch.name);
local task_definition_family = config.helpers.buildName(prefix, '%s-td' % batch.name);

{
  region: region,
  batch_name: batch.name,

  // ecschedule top-level settings
  cluster: batch.cluster,
  role: batch.events_role,
  plugins: [
    {
      name: 'tfstate',
      config: {
        url: config.helpers.buildTfstateUrl(accountId),
      },
    },
  ],

  // ecschedule rules
  rules: [
    {
      name: config.helpers.buildName(prefix, batch.name),
      description: batch.description,
      scheduleExpression: batch.schedule_expression,
      taskDefinition: task_definition_family,
      containerOverrides: [
        {
          name: container_name,
          command: batch.command,
        },
      ],
      role: batch.events_role,
      group: 'batch:%s' % task_definition_family,
      launch_type: 'FARGATE',
      platform_version: config.service.platform_version,
      propagateTags: 'TASK_DEFINITION',
      network_configuration: {
        aws_vpc_configuration: {
          assign_public_ip: 'DISABLED',
          security_groups: [
            '{{ tfstate `module.security_group_ecs.aws_security_group.this_name_prefix[0].id` }}',
          ],
          subnets: [
            '{{ tfstate `module.vpc.aws_subnet.private[0].id` }}',
            '{{ tfstate `module.vpc.aws_subnet.private[1].id` }}',
            '{{ tfstate `module.vpc.aws_subnet.private[2].id` }}',
          ],
        },
      },
      // dead_letter_config (optional): route failed invocations to an SQS DLQ
      // Uncomment and configure the queue when DLQ monitoring is required:
      // dead_letter_config: {
      //   sqs: '{{ tfstate `module.sqs_scheduled_task_dlq.aws_sqs_queue.this[0].url` }}',
      // },
    },
  ],

  // Task definition settings (for task registration independent of ecschedule)
  task: {
    // Task definition root settings
    cpu: config.task.cpu,
    execution_role_arn: batch.execution_role_arn,
    family: task_definition_family,
    memory: config.task.memory,
    network_mode: config.task.network_mode,
    requires_compatibilities: config.task.requires_compatibilities,
    role_arn: batch.task_role_arn,
    tags: batch.tags,
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
      name: container_name,
      command: batch.command,
      environment: batch.environment,
      // Image: default ECR repo based on batch name; override image_repository in local batch
      // for shared ECR images or external images. Override image_tag per environment via:
      //   task+: { container_definitions+: { image_tag: 'v1.0.0' } }
      image_repository: batch.image_repository,
      image_tag: batch.image_tag,
      image: '%s:%s' % [self.image_repository, self.image_tag],
      log_configuration: {
        log_driver: 'awslogs',
        options: {
          log_group: config.helpers.buildLogGroup(prefix, batch.name),
          create_group: 'true',
          region: region,
          stream_prefix: 'batch',
        },
      },
      readonly_root_filesystem: batch.readonly_root_filesystem,
      secrets: batch.secrets,
      start_timeout: config.task.container_definitions.start_timeout,
    },
  },
}
