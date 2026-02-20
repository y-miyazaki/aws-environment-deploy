// Ecspresso configuration
// Can be used directly by ecspresso (no need to generate ecspresso.yaml)
// Usage: ecspresso verify --config ecspresso.jsonnet --ext-str ENV=dev \
//                           --ext-str SERVICE=test-server --ext-str ACCOUNT_ID=... --ext-str AWS_REGION=...
//
// This file automatically uses service_name from base.jsonnet
// When creating a new service, only change service_name in base.jsonnet

local env = std.extVar('ENV');
local configs = {
  dev: import 'env/dev.jsonnet',
  qa: import 'env/qa.jsonnet',
  stg: import 'env/stg.jsonnet',
  prd: import 'env/prd.jsonnet',
};
local config = configs[env];

{
  cluster: config.service.cluster,
  plugins: config.plugins,
  region: config.region,
  service: config.service.name,
  service_definition: '../../templates/service-definition.entry.jsonnet',
  task_definition: '../../templates/task-definition.entry.jsonnet',
}
