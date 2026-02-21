// Ecspresso configuration
// Can be used directly by ecspresso (no need to generate ecspresso.yaml)
// Usage: ecspresso verify --config ecspresso.jsonnet --ext-str ENV=dev \
//                         --ext-str NAME=test-server --ext-str ACCOUNT_ID=... --ext-str AWS_REGION=...
//
// When creating a new service, only change service name in base.jsonnet

local serviceConfig = import '../../templates/service-config.entry.jsonnet';

{
  cluster: serviceConfig.service.cluster,
  plugins: serviceConfig.plugins,
  region: serviceConfig.region,
  service: serviceConfig.service.name,
  service_definition: '../../templates/service-definition.entry.jsonnet',
  task_definition: '../../templates/task-definition.entry.jsonnet',
}
