// Registry for ECS services and scheduled tasks
// Uses static imports to avoid computed import limitations

{
  services: {
    'test-server': {
      dev: import './ecs-service/test-server/env/dev.jsonnet',
      qa: import './ecs-service/test-server/env/qa.jsonnet',
      stg: import './ecs-service/test-server/env/stg.jsonnet',
      prd: import './ecs-service/test-server/env/prd.jsonnet',
    },
  },

  scheduled_tasks: {
    'test-batch': {
      dev: import './ecs-scheduled-task/test-batch/env/dev.jsonnet',
      qa: import './ecs-scheduled-task/test-batch/env/qa.jsonnet',
      stg: import './ecs-scheduled-task/test-batch/env/stg.jsonnet',
      prd: import './ecs-scheduled-task/test-batch/env/prd.jsonnet',
    },
  },
}
