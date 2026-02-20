// Service config entry for ecs-service
// Returns full config: { service (base), plugins, region, auto_scaling, service (layer), task }
// Used by ecspresso.jsonnet (.service.cluster, .plugins, .region, .service.name)
// Used by task-definition.entry.jsonnet (.task) and service-definition.entry.jsonnet (.service)
//
// Usage: jsonnet -V ENV=dev -V SERVICE=test-server \
//               -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 templates/service-config.entry.jsonnet
//
// External variables:
//   ENV:        environment name (dev, qa, stg, prd)
//   SERVICE:    service name (e.g., test-server)
//   ACCOUNT_ID: AWS account ID
//   AWS_REGION: AWS region

local env = std.extVar('ENV');
local service = std.extVar('SERVICE');
local registry = import '../registry.jsonnet';
local globalConfig = import '../config.jsonnet';

// Get base config from registry: { service: {...} }
local baseConfig = registry.services[service][env];
local svc = baseConfig.base;
local prefix = globalConfig.env;
local region = globalConfig.region;
local accountId = globalConfig.accountId;

// Derived values
local container_name = globalConfig.helpers.buildName(prefix, svc.name);
local task_definition_family = globalConfig.helpers.buildName(prefix, '%s-td' % svc.name);

// Build and return full config (ecspresso uses .service/plugins/region, entry files use .task/.service)
baseConfig + {
  plugins: [
    {
      name: 'tfstate',
      config: {
        url: globalConfig.helpers.buildTfstateUrl(accountId),
      },
    },
  ],
  region: region,

  // Auto-scaling configuration (used by deploy.sh)
  auto_scaling: {
    max_capacity: globalConfig.auto_scaling.max_capacity,
    min_capacity: globalConfig.auto_scaling.min_capacity,
    policies: globalConfig.auto_scaling.policies,
  },

  // Service layer (used by service-definition.entry.jsonnet)
  service: {
    cluster: svc.cluster,
    desired_count: globalConfig.service.desired_count,
    healthcheck_grace_period_seconds: globalConfig.service.healthcheck_grace_period_seconds,
    name: globalConfig.helpers.buildName(prefix, '%s-service' % svc.name),
    platform_version: globalConfig.service.platform_version,
    propagate_tags: globalConfig.service.propagate_tags,
    // loadBalancers for ALB integration
    load_balancers: [
      {
        containerName: container_name,
        containerPort: svc.container_port,
        targetGroupArn: svc.target_group_arn,
      },
    ],
    // deploymentConfiguration settings
    // Override per environment in env/*.jsonnet:
    //   base+: { deployment_configuration+: { maximum_percent: 100 } }
    deployment_configuration: {
      maximum_percent: globalConfig.service.deployment_configuration.maximum_percent,
      minimum_healthy_percent: globalConfig.service.deployment_configuration.minimum_healthy_percent,
    },
    // networkConfiguration settings
    // Override per environment in env/*.jsonnet:
    //   base+: { network_configuration+: { awsvpc_configuration+: { security_groups: ['sg-xxxx'] } } }
    network_configuration: {
      awsvpc_configuration: {
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

  // Task layer (used by task-definition.entry.jsonnet)
  task: {
    cpu: globalConfig.task.cpu,
    execution_role_arn: svc.execution_role_arn,
    family: task_definition_family,
    memory: globalConfig.task.memory,
    network_mode: globalConfig.task.network_mode,
    requires_compatibilities: globalConfig.task.requires_compatibilities,
    role_arn: svc.task_role_arn,
    tags: svc.tags,
    runtime_platform: {
      cpu_architecture: globalConfig.task.runtime_platform.cpu_architecture,
      operating_system_family: globalConfig.task.runtime_platform.operating_system_family,
    },
    container_definitions: {
      cpu: globalConfig.task.container_definitions.cpu,
      memory: globalConfig.task.container_definitions.memory,
      memory_reservation: globalConfig.task.container_definitions.memory_reservation,
      name: container_name,
      command: svc.command,
      environment: svc.environment,
      // Override image_tag per environment: base+: { image_tag: 'v1.0.0' }
      image_repository: svc.image_repository,
      image_tag: svc.image_tag,
      image: '%s:%s' % [self.image_repository, self.image_tag],
      log_configuration: {
        log_driver: 'awslogs',
        options: {
          log_group: globalConfig.helpers.buildLogGroup(prefix, svc.name),
          create_group: 'true',
          region: region,
          stream_prefix: 'application',
        },
      },
      port_mappings: {
        container_port: svc.container_port,
        host_port: svc.container_port,
        name: '%s-%s-tcp' % [svc.name, svc.container_port],
        protocol: 'tcp',
      },
      readonly_root_filesystem: svc.readonly_root_filesystem,
      secrets: svc.secrets,
      start_timeout: globalConfig.task.container_definitions.start_timeout,
    },
  },
}
