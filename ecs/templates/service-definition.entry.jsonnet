// Service definition entry for ecs-service
// Usage: jsonnet -V ENV=dev -V SERVICE=test-server \
//               -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 templates/service-definition.entry.jsonnet

local env = std.extVar('ENV');
local service = std.extVar('SERVICE');
local registry = import '../registry.jsonnet';
local template = import './service-definition.jsonnet';

template(registry.services[service][env].service)
