// ecschedule configuration for test-batch
// Renders ecschedule JSON config for the specified environment
//
// Usage: This file is rendered to JSON by deploy.sh via jsonnet CLI
//   jsonnet -V ENV=dev -V ACCOUNT_ID=<id> -V AWS_REGION=ap-northeast-1 ecschedule.jsonnet
//
// Note: ecschedule does not support --ext-str; deploy.sh renders this file first.
local env = std.extVar('ENV');
local configs = {
  dev: import 'env/dev.jsonnet',
  qa: import 'env/qa.jsonnet',
  stg: import 'env/stg.jsonnet',
  prd: import 'env/prd.jsonnet',
};

local config = configs[env];

{
  batch_name: config.batch_name,
  cluster: config.cluster,
  role: config.role,
  plugins: config.plugins,
  region: config.region,
  rules: config.rules,
}
