// Generate stg environment configuration
local base = import 'base.jsonnet';

base {
  // Staging tier defaults - uncomment to customize
  // Override service settings:
  //   base+: { image_tag: 'stg-v1.0.0' },
  //   base+: { environment+: [{ name: 'LOG_LEVEL', value: 'info' }] },
}
