// Task definition template wrapper for ecs-service
// Delegates to shared template under ecs/templates

local template = import '../../templates/task-definition.jsonnet';

function(config) template(config)
