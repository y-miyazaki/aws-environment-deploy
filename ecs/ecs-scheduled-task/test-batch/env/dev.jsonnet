// dev environment configuration for test-batch
// Extends base with development-specific overrides
local base = import 'base.jsonnet';

base {
  // Example environment-specific overrides:
  // task+: { container+: { image_tag: 'dev-latest' } },
  // rules: [base.rules[0] { scheduleExpression: 'cron(0 12 * * ? *)' }],
}
