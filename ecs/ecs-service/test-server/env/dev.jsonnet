// Generate dev environment configuration
local base = import 'base.jsonnet';

base {
  // Development tier defaults - uncomment to customize
  //
  // Override image tag:
  // base+: { task+: { container_definitions+: { image_tag: 'dev-v1.0.0' } } },
  //
  // Add environment variable:
  // base+: { task+: { container_definitions+: { environment+: [{ name: 'LOG_LEVEL', value: 'debug' }] } } },
  //
  // Add secret:
  // base+: { task+: { container_definitions+: { secrets+: [{ name: 'API_KEY', valueFrom: '...' }] } } },
}
