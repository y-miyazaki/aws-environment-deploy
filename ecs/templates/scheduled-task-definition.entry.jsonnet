// Scheduled task definition entry for ecs-scheduled-task
// Returns full config: { batch, plugins, region, rules, task }
// Used by ecschedule.jsonnet (.rules) and ecspresso.jsonnet (.task)
//
// Usage: jsonnet -V ENV=dev -V SCHEDULED_TASK=test-batch \
//               -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 templates/scheduled-task-definition.entry.jsonnet
//
// External variables:
//   ENV:            environment name (dev, qa, stg, prd)
//   SCHEDULED_TASK: scheduled task name (e.g., test-batch)
//   ACCOUNT_ID:     AWS account ID
//   AWS_REGION:     AWS region

local env = std.extVar('ENV');
local scheduled_task = std.extVar('SCHEDULED_TASK');
local registry = import '../registry.jsonnet';
local globalConfig = import '../config.jsonnet';

// Get base config from registry: { batch: {...} }
local baseConfig = registry.scheduled_tasks[scheduled_task][env];
local batch = baseConfig.base;
local prefix = globalConfig.env;
local region = globalConfig.region;
local accountId = globalConfig.accountId;

// Derived values
local container_name = globalConfig.helpers.buildName(prefix, batch.name);
local task_definition_family = globalConfig.helpers.buildName(prefix, '%s-td' % batch.name);

// Build and return full config (ecschedule uses .rules, ecspresso uses .task)
baseConfig {
  plugins: [
    {
      name: 'tfstate',
      config: {
        url: globalConfig.helpers.buildTfstateUrl(accountId),
      },
    },
  ],
  region: region,
  rules: [
    {
      name: globalConfig.helpers.buildName(prefix, batch.name),
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
      platform_version: globalConfig.service.platform_version,
      propagateTags: 'TASK_DEFINITION',
      network_configuration: {
        aws_vpc_configuration: {
          assign_public_ip: 'DISABLED',
          security_groups: [
            '{{ tfstate `module.%s.aws_security_group.this_name_prefix[0].id` }}' % globalConfig.terraform_modules.security_group,
          ],
          subnets: [
            '{{ tfstate `module.%s.aws_subnet.private[0].id` }}' % globalConfig.terraform_modules.vpc,
            '{{ tfstate `module.%s.aws_subnet.private[1].id` }}' % globalConfig.terraform_modules.vpc,
            '{{ tfstate `module.%s.aws_subnet.private[2].id` }}' % globalConfig.terraform_modules.vpc,
          ],
        },
      },
    },
  ],
  task: {
    cpu: globalConfig.task.cpu,
    execution_role_arn: batch.execution_role_arn,
    family: task_definition_family,
    memory: globalConfig.task.memory,
    network_mode: globalConfig.task.network_mode,
    requires_compatibilities: globalConfig.task.requires_compatibilities,
    role_arn: batch.task_role_arn,
    tags: batch.tags,
    runtime_platform: {
      cpu_architecture: globalConfig.task.runtime_platform.cpu_architecture,
      operating_system_family: globalConfig.task.runtime_platform.operating_system_family,
    },
    container_definitions: {
      cpu: globalConfig.task.container_definitions.cpu,
      memory: globalConfig.task.container_definitions.memory,
      memory_reservation: globalConfig.task.container_definitions.memory_reservation,
      name: container_name,
      command: batch.command,
      environment: batch.environment,
      image_repository: batch.image_repository,
      image_tag: batch.image_tag,
      image: '%s:%s' % [self.image_repository, self.image_tag],
      log_configuration: {
        log_driver: 'awslogs',
        options: {
          log_group: globalConfig.helpers.buildLogGroup(prefix, batch.name),
          create_group: 'true',
          region: region,
          stream_prefix: 'batch',
        },
      },
      readonly_root_filesystem: batch.readonly_root_filesystem,
      secrets: batch.secrets,
      start_timeout: globalConfig.task.container_definitions.start_timeout,
    },
  },
}
