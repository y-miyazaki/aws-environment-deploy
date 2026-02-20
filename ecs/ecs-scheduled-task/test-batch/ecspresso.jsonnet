// Ecspresso configuration for test-batch (scheduled task — no ECS service)
// Used only for task definition registration via: ecspresso register
//
// Usage: ecspresso register --config ecspresso.jsonnet --ext-str ENV=dev \
//                           --ext-str SCHEDULED_TASK=test-batch --ext-str ACCOUNT_ID=... --ext-str AWS_REGION=...
//
// Unlike ecs-service, this config has no service_definition because scheduled
// tasks are driven by EventBridge rules managed by ecschedule.

local env = std.extVar('ENV');
local configs = {
  dev: import 'env/dev.jsonnet',
  qa: import 'env/qa.jsonnet',
  stg: import 'env/stg.jsonnet',
  prd: import 'env/prd.jsonnet',
};
local config = configs[env];

{
  cluster: config.cluster,
  plugins: config.plugins,
  region: config.region,
  task_definition: '../../templates/scheduled-task-definition.entry.jsonnet',
}
