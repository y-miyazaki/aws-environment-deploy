// ecschedule configuration for test-batch (EventBridge rules)
// Renders ecschedule JSON config for the specified environment
//
// Usage: This file is rendered to JSON by deploy.sh via jsonnet CLI
//   jsonnet -V ENV=dev -V NAME=test-batch -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 ecschedule.jsonnet
//
// Note: ecschedule does not support --ext-str; deploy.sh renders this file first.

local scheduledTaskDef = import '../../templates/scheduled-task-config.entry.jsonnet';

{
  cluster: scheduledTaskDef.base.cluster,
  plugins: scheduledTaskDef.plugins,
  region: scheduledTaskDef.region,
  rules: scheduledTaskDef.rules,
}
