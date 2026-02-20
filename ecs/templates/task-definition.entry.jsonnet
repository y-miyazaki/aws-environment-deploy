// Task definition entry for ecs-service
// Usage: jsonnet -V ENV=dev -V SERVICE=test-server \
//               -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 templates/task-definition.entry.jsonnet

local env = std.extVar('ENV');
local service = std.extVar('SERVICE');
local registry = import '../registry.jsonnet';
local template = import './task-definition.jsonnet';

local config = registry.services[service][env];

template(config.task { region: config.region })
