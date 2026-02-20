// Generate qa environment configuration
local base = import 'base.jsonnet';

base {
  // Environment defaults - uncomment to customize
  // Increase for production-like testing:
  // task+: { cpu: '2048', memory: '4096' },
  // task+: { container_definitions+: { cpu: 2048, memory: 4096, memory_reservation: 1500 } },
  //
  // Auto-scaling: increase for production-like load testing
  // auto_scaling+: { max_capacity: 10, min_capacity: 2 },
  //
  // Deployment: increase healthy percent for canary deployments
  // service+: { deployment_configuration+: { maximum_percent: 150, minimum_healthy_percent: 50 } },
  //
  // Container override: custom image tag per environment
  // task+: { container_definitions+: { image_tag: 'qa-v1.0.0' } },
}
