// Service definition entry for ecs-service
// Converts snake_case service config → camelCase AWS format via service-definition.jsonnet
// Usage: referenced from ecspresso.jsonnet as service_definition file path
//
// jsonnet -V ENV=dev -V SERVICE=test-server \
//         -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 templates/service-definition.entry.jsonnet

local serviceConfig = import './service-config.entry.jsonnet';
local template = import './service-definition.jsonnet';

template(serviceConfig.service)
