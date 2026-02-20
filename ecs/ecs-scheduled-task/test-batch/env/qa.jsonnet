// qa environment configuration for test-batch
// Extends base with QA-specific overrides
local base = import 'base.jsonnet';

base {
  // Environment defaults - uncomment to customize
  // Increase resources for CPU/Memory-bound batch jobs:
  // task+: { cpu: '2048', memory: '4096' },
  // task+: { container_definitions+: { cpu: 2048, memory: 4096, memory_reservation: 1500 } },
  //
  // Change schedule for QA (e.g., every 2 hours instead of daily):
  // batch+: { schedule_expression: 'cron(0 */2 * * ? *)' },
  //
  // Add custom command or debugging options:
  // batch+: { command: ['--debug', '--log-level=info'] },
  //
  // Container override: custom image tag per environment
  // task+: { container_definitions+: { image_tag: 'qa-v1.0.0' } },
}
