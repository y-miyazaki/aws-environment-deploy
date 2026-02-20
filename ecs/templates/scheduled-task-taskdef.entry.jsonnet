// Task definition entry for ecs-scheduled-task (ecspresso register)
// Converts snake_case task config → camelCase AWS format via task-definition.jsonnet
// Usage: referenced from ecspresso.jsonnet as task_definition file path

local scheduledTaskDef = import './scheduled-task-definition.entry.jsonnet';
local taskDefTemplate = import './task-definition.jsonnet';

taskDefTemplate(scheduledTaskDef.task)
