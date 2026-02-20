// Ecspresso configuration for test-batch (scheduled task — no ECS service)
// Used only for task definition registration via: ecspresso register
//
// Usage: ecspresso register --config ecspresso.jsonnet --ext-str ENV=dev \
//                           --ext-str SCHEDULED_TASK=test-batch \
//                           --ext-str ACCOUNT_ID=... --ext-str AWS_REGION=...
//
// Unlike ecs-service, this config has no service_definition because scheduled
// tasks are driven by EventBridge rules managed by ecschedule.

local scheduledTaskDef = import '../../templates/scheduled-task-definition.entry.jsonnet';

{
  cluster: scheduledTaskDef.base.cluster,
  plugins: scheduledTaskDef.plugins,
  region: scheduledTaskDef.region,
  task_definition: '../../templates/scheduled-task-taskdef.entry.jsonnet',
}
