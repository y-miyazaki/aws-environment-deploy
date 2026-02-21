// prd environment configuration for test-batch
// Extends base with production-specific overrides
local base = import 'base.jsonnet';

base {
  // Production tier defaults - uncomment to customize
  //
  // Change schedule for production:
  // base+: { rules+: { schedule_expression: 'cron(0 17 * * ? *)' } },
  //
  // Override image tag:
  // base+: { task+: { container_definitions+: { image_tag: 'prd-v1.0.0' } } },
  //
  // Add production-specific command options:
  // base+: { task+: { container_definitions+: { command: ['--log-level=warn'] } } },
}
