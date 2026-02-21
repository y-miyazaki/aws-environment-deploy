// Service config entry for ecs-service
// Returns full config: { base, plugins, region, auto_scaling, service (layer), task }
// Used by ecspresso.jsonnet (.service.cluster, .plugins, .region, .service.name)
// Used by task-definition.entry.jsonnet (.task) and service-definition.entry.jsonnet (.service)
//
// Usage: jsonnet -V ENV=dev -V NAME=test-server \
//               -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 templates/service-config.entry.jsonnet
//
// External variables:
//   ENV:        environment name (dev, qa, stg, prd)
//   NAME:       service name (e.g., test-server)
//   ACCOUNT_ID: AWS account ID
//   AWS_REGION: AWS region

local env = std.extVar('ENV');
local name = std.extVar('NAME');
local registry = import '../registry.jsonnet';
local globalConfig = import '../config.jsonnet';

local baseConfig = registry.services[name][env];
local svc = baseConfig.base;
local prefix = globalConfig.env;
local region = globalConfig.region;
local accountId = globalConfig.accountId;

local container_name = globalConfig.helpers.buildName(prefix, svc.name);
local task_definition_family = globalConfig.helpers.buildName(prefix, '%s-td' % svc.name);

// Merge globalConfig defaults with base overrides (base takes priority).
// Nested objects requiring partial override are merged explicitly.
local svc_service = std.get(svc, 'service', {});
local service_merged = {
  network_configuration: globalConfig.network_configuration.service,
} + globalConfig.service + svc_service + {
  deployment_configuration: globalConfig.service.deployment_configuration + std.get(svc_service, 'deployment_configuration', {}),
};

local task = globalConfig.task + svc.task + {
  container_definitions: globalConfig.task.container_definitions + svc.task.container_definitions,
  runtime_platform: globalConfig.task.runtime_platform + std.get(svc.task, 'runtime_platform', {}),
};

// Build and return full config (ecspresso uses .service/plugins/region, entry files use .task/.service)
baseConfig {
  plugins: [{ name: 'tfstate', config: { url: globalConfig.helpers.buildTfstateUrl(accountId) } }],
  region: region,
  auto_scaling: globalConfig.auto_scaling,
  // Service layer (used by service-definition.entry.jsonnet)
  service: {
    cluster: svc.cluster,
    name: globalConfig.helpers.buildName(prefix, '%s-service' % svc.name),
    load_balancers: if std.objectHas(service_merged, 'target_group_arn') then
      if std.objectHas(service_merged, 'container_port') then [{
        containerName: container_name,
        containerPort: service_merged.container_port,
        targetGroupArn: service_merged.target_group_arn,
      }] else error 'service.container_port must be set when service.target_group_arn is specified'
    else [],
    desired_count: service_merged.desired_count,
    healthcheck_grace_period_seconds: service_merged.healthcheck_grace_period_seconds,
    platform_version: service_merged.platform_version,
    propagate_tags: service_merged.propagate_tags,
    deployment_configuration: service_merged.deployment_configuration,
    network_configuration: service_merged.network_configuration,
  },
  // Task layer (used by task-definition.entry.jsonnet)
  task: task {
    family: task_definition_family,
    tags: svc.tags,
    container_definitions: task.container_definitions {
      name: container_name,
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
        container_port: service_merged.container_port,
        host_port: service_merged.container_port,
        name: '%s-%s-tcp' % [svc.name, service_merged.container_port],
        protocol: 'tcp',
      },
    },
  },
}
