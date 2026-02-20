// prd environment configuration for test-batch
// Extends base with production-specific overrides
local base = import 'base.jsonnet';

base {
  // Example environment-specific overrides:
  // task+: { container+: { image_tag: 'v1.0.0' } },
  // rules: [base.rules[0] { scheduleExpression: 'cron(0 21 * * ? *)' }],
}
