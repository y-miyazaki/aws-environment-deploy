// Task definition entry for ecs-service
// Converts snake_case task config → camelCase AWS format via task-definition.jsonnet
// Usage: referenced from ecspresso.jsonnet as task_definition file path
//
// jsonnet -V ENV=dev -V SERVICE=test-server \
//         -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 templates/task-definition.entry.jsonnet

local serviceConfig = import './service-config.entry.jsonnet';
local template = import './task-definition.jsonnet';

template(serviceConfig.task)
