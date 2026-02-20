// Global ECS configuration - shared across all services (ecs-service, ecs-scheduled-task etc)
// Canonical location: ecs/config.jsonnet
// This file re-exports from the canonical location for backward compatibility.
// Usage: local config = import 'config.jsonnet';

import '../config.jsonnet'
