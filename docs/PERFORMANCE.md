# Performance Optimization Guide

## Container Image Optimization

### Multi-stage Builds

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o app

# Runtime stage
FROM alpine:3.19
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/app /app
ENTRYPOINT ["/app"]
```

### Image Size Reduction
- Use Alpine or distroless base images
- Remove build dependencies in final image
- Use `.dockerignore` to exclude unnecessary files
- Compress binaries with UPX (if applicable)

## ECS Task Optimization

### Right-sizing Resources

Use CloudWatch Container Insights to analyze actual usage:

```bash
# Get average CPU/Memory over 7 days
aws cloudwatch get-metric-statistics \
  --namespace ECS/ContainerInsights \
  --metric-name CpuUtilized \
  --dimensions Name=ServiceName,Value=SERVICE Name=ClusterName,Value=CLUSTER \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average
```

### Memory Reservation Strategy

```jsonnet
// Conservative: 50% of hard limit
memory_reservation: std.floor(memory * 0.5),

// Aggressive: 80% of hard limit (for predictable workloads)
memory_reservation: std.floor(memory * 0.8),

// Dynamic: Based on environment
memory_reservation: if env == 'prd' then std.floor(memory * 0.7) else std.floor(memory * 0.5),
```

## Auto-scaling Optimization

### Target Tracking Policies

```jsonnet
auto_scaling: {
  min_capacity: 2,
  max_capacity: 20,
  policies: [
    {
      predefined_metric_type: 'ECSServiceAverageCPUUtilization',
      target_value: 70.0,  // Scale at 70% CPU
      scale_in_cooldown: 300,
      scale_out_cooldown: 60,  // Fast scale-out
    },
  ],
}
```

### Step Scaling for Predictable Patterns

```hcl
resource "aws_appautoscaling_policy" "step_scaling" {
  name               = "${var.service_name}-step-scaling"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "PercentChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 10
      scaling_adjustment          = 10
    }

    step_adjustment {
      metric_interval_lower_bound = 10
      scaling_adjustment          = 30
    }
  }
}
```

## Network Performance

### VPC Endpoints

Reduce NAT Gateway costs and improve performance:

```hcl
# ECR API endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# ECR Docker endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# S3 Gateway endpoint (for ECR layers)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
}
```

### Connection Pooling

Configure application connection pools:

```python
# Database connection pool
pool = psycopg2.pool.ThreadedConnectionPool(
    minconn=5,
    maxconn=20,
    host=os.environ['DB_HOST'],
    database=os.environ['DB_NAME']
)

# HTTP client with connection pooling
session = requests.Session()
adapter = HTTPAdapter(
    pool_connections=10,
    pool_maxsize=20,
    max_retries=3
)
session.mount('https://', adapter)
```

## Deployment Performance

### Parallel Deployments

Use GitHub Actions matrix strategy:

```yaml
strategy:
  max-parallel: 5
  matrix:
    service:
      - service-a
      - service-b
      - service-c
```

### Caching

#### Docker Layer Caching

```yaml
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ${{ env.IMAGE_TAG }}
    cache-from: type=registry,ref=${{ env.IMAGE_TAG }}-cache
    cache-to: type=registry,ref=${{ env.IMAGE_TAG }}-cache,mode=max
```

#### Jsonnet Caching

```bash
# Cache rendered configs
CACHE_KEY="${ENV}-${NAME}-$(md5sum env/${ENV}.jsonnet | cut -d' ' -f1)"
if [ -f "/tmp/cache/${CACHE_KEY}.json" ]; then
  echo "Using cached config"
  cp "/tmp/cache/${CACHE_KEY}.json" config.json
else
  jsonnet -V ENV="$ENV" env/${ENV}.jsonnet > config.json
  mkdir -p /tmp/cache
  cp config.json "/tmp/cache/${CACHE_KEY}.json"
fi
```

## Database Performance

### Read Replicas

```jsonnet
environment+: [
  { name: 'DB_READ_HOST', value: 'reader.cluster.region.rds.amazonaws.com' },
  { name: 'DB_WRITE_HOST', value: 'writer.cluster.region.rds.amazonaws.com' },
]
```

### Connection Limits

Calculate based on task count:

```
max_connections = (max_tasks * connections_per_task) + buffer
```

Example:
```
max_tasks = 20
connections_per_task = 10
buffer = 20
max_connections = (20 * 10) + 20 = 220
```

## Monitoring Performance Impact

### Sampling for High-Volume Services

```jsonnet
environment+: [
  { name: 'XRAY_SAMPLING_RATE', value: '0.1' },  // 10% sampling
  { name: 'LOG_LEVEL', value: if env == 'prd' then 'INFO' else 'DEBUG' },
]
```

### Async Logging

Use buffered/async logging to reduce I/O overhead:

```python
import logging
from logging.handlers import QueueHandler, QueueListener
import queue

log_queue = queue.Queue()
queue_handler = QueueHandler(log_queue)
logger = logging.getLogger()
logger.addHandler(queue_handler)

# Start listener in background thread
listener = QueueListener(log_queue, *logger.handlers)
listener.start()
```

## Cost Optimization

### Fargate Spot

```jsonnet
capacity_provider_strategy: [
  { capacity_provider: 'FARGATE_SPOT', weight: 70, base: 0 },
  { capacity_provider: 'FARGATE', weight: 30, base: 2 },
]
```

### ARM64 Architecture

20% cost savings with comparable performance:

```jsonnet
runtime_platform: {
  cpu_architecture: 'ARM64',
  operating_system_family: 'LINUX',
}
```

## Benchmarking

### Load Testing

```bash
# Using Apache Bench
ab -n 10000 -c 100 https://api.example.com/health

# Using wrk
wrk -t12 -c400 -d30s https://api.example.com/health
```

### Task Startup Time

```bash
# Measure time from task creation to running
aws ecs describe-tasks --cluster CLUSTER --tasks TASK_ID \
  --query 'tasks[0].[createdAt,startedAt]'
```
