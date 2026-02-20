// Task definition entry for ecs-scheduled-task
// Usage: jsonnet -V ENV=dev -V SCHEDULED_TASK=test-batch \
//               -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 templates/scheduled-task-definition.entry.jsonnet

local env = std.extVar('ENV');
local scheduled_task = std.extVar('SCHEDULED_TASK');
local registry = import '../registry.jsonnet';
local template = import './task-definition.jsonnet';

local config = registry.scheduled_tasks[scheduled_task][env];

template(config.task { region: config.region })
