// stg environment configuration for test-batch
// Extends base with staging-specific overrides
local base = import 'base.jsonnet';

base {
  // Staging tier defaults - uncomment to customize
  //
  // Change schedule for staging (e.g., every 2 hours instead of daily):
  // base+: { rules+: { schedule_expression: 'cron(0 */2 * * ? *)' } },
  //
  // Override image tag:
  // base+: { task+: { container_definitions+: { image_tag: 'stg-v1.0.0' } } },
  //
  // Add custom command or debugging options:
  // base+: { task+: { container_definitions+: { command: ['--debug', '--log-level=info'] } } },
}
