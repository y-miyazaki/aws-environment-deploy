// Generate stg environment configuration
local base = import 'base.jsonnet';

base {
  // auto_scaling+: {
  //   max_capacity: 10,
  //   min_capacity: 1,
  // },
  // task+: { container_definitions+: { image_tag: 'latest' } },
}
