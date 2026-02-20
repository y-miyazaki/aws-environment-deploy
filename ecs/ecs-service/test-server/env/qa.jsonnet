// Generate qa environment configuration
local base = import 'base.jsonnet';

base {
  // QA tier defaults - uncomment to customize
  // Override service settings:
  //   base+: { image_tag: 'qa-v1.0.0' },
  //   base+: { environment+: [{ name: 'LOG_LEVEL', value: 'info' }] },
}
