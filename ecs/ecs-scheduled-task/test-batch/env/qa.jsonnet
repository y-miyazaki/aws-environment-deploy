// qa environment configuration for test-batch
// Extends base with QA-specific overrides
local base = import 'base.jsonnet';

base {
  // Example environment-specific overrides:
  // task+: { container+: { image_tag: 'qa-latest' } },
}
