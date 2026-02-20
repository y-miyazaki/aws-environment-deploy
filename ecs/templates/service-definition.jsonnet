// Shared service definition template for ECS services
// Returns a function that generates service definition from config
// Usage: local template = import 'templates/service-definition.jsonnet';
//        template(config)

function(config) {
  availabilityZoneRebalancing: 'DISABLED',
  capacityProviderStrategy: [
    {
      base: 0,
      capacityProvider: 'FARGATE',
      weight: 50,
    },
    {
      base: 0,
      capacityProvider: 'FARGATE_SPOT',
      weight: 50,
    },
  ],
  deploymentConfiguration: {
    bakeTimeInMinutes: 0,
    deploymentCircuitBreaker: {
      enable: true,
      rollback: true,
    },
    maximumPercent: config.deployment_configuration.maximum_percent,
    minimumHealthyPercent: config.deployment_configuration.minimum_healthy_percent,
  },
  desiredCount: config.desired_count,
  enableExecuteCommand: true,
  healthCheckGracePeriodSeconds: config.healthcheck_grace_period_seconds,
  loadBalancers: if std.objectHas(config, 'load_balancers') && std.length(config.load_balancers) > 0
  then config.load_balancers
  else [],
  networkConfiguration: {
    awsvpcConfiguration: {
      assignPublicIp: config.network_configuration.awsvpc_configuration.assign_public_ip,
      securityGroups: config.network_configuration.awsvpc_configuration.security_groups,
      subnets: config.network_configuration.awsvpc_configuration.subnets,
    },
  },
  platformVersion: config.platform_version,
  propagateTags: config.propagate_tags,
  schedulingStrategy: 'REPLICA',
}
