// Generate qa environment configuration
local base = import 'base.jsonnet';

base {
  // QA tier defaults - uncomment to customize
  //
  // Override image tag:
  // base+: { task+: { container_definitions+: { image_tag: 'qa-v1.0.0' } } },
  //
  // Add environment variable:
  // base+: { task+: { container_definitions+: { environment+: [{ name: 'LOG_LEVEL', value: 'info' }] } } },
}
