// ecschedule configuration for test-batch
// Renders ecschedule JSON config for the specified environment
//
// Usage: This file is rendered to JSON by deploy.sh via jsonnet CLI
//   jsonnet -V ENV=dev -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 ecschedule.jsonnet
//
// Note: ecschedule does not support --ext-str; deploy.sh renders this file first.
// Ecschedule configuration for test-batch (EventBridge rules)
// Usage: ecschedule run --config ecschedule.jsonnet --ext-str ENV=dev \
//                       --ext-str SCHEDULED_TASK=test-batch \
//                       --ext-str ACCOUNT_ID=... --ext-str AWS_REGION=...

local scheduledTaskDef = import '../../templates/scheduled-task-definition.entry.jsonnet';

{
  cluster: scheduledTaskDef.base.cluster,
  plugins: scheduledTaskDef.plugins,
  region: scheduledTaskDef.region,
  rules: scheduledTaskDef.rules,
}
