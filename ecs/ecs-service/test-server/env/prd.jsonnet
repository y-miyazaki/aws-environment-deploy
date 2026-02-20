// Generate prd environment configuration
local base = import 'base.jsonnet';

base {
  // Production tier defaults - uncomment to customize
  // Override service settings:
  //   base+: { image_tag: 'prd-v1.0.0' },
  //   base+: { environment+: [{ name: 'LOG_LEVEL', value: 'warn' }] },
}
