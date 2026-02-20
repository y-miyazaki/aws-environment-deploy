// Generate dev environment configuration
local base = import 'base.jsonnet';

base {
  // Development tier defaults - uncomment to customize
  // Override service settings:
  //   base+: { image_tag: 'dev-v1.0.0' },
  //   base+: { environment+: [{ name: 'LOG_LEVEL', value: 'debug' }] },
  //   base+: { secrets+: [{ name: 'API_KEY', valueFrom: '...' }] },
}
