# Monitoring and Observability

## CloudWatch Logs Configuration

### Log Retention

Add to your Terraform configuration:

```hcl
resource "aws_cloudwatch_log_group" "ecs_task" {
  name              = "/aws/ecs/task-definition/${var.env}-${var.service_name}"
  retention_in_days = 30  # Adjust based on compliance requirements
  kms_key_id        = aws_kms_key.logs.arn

  tags = {
    Environment = var.env
    Service     = var.service_name
  }
}
```

### Log Insights Queries

#### Find Errors
```
fields @timestamp, @message
| filter @message like /ERROR|Exception|Failed/
| sort @timestamp desc
| limit 100
```

#### Monitor Response Times
```
fields @timestamp, duration
| filter @type = "request"
| stats avg(duration), max(duration), min(duration) by bin(5m)
```

## CloudWatch Alarms

### High CPU Usage

```hcl
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.env}-${var.service_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS service CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
}
```

### High Memory Usage

```hcl
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.env}-${var.service_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS service memory utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
}
```

### Task Count Alarm

```hcl
resource "aws_cloudwatch_metric_alarm" "ecs_task_count_low" {
  alarm_name          = "${var.env}-${var.service_name}-task-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "No running tasks detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
}
```

## Container Insights

Enable Container Insights for detailed metrics:

```bash
aws ecs update-cluster-settings \
  --cluster CLUSTER_NAME \
  --settings name=containerInsights,value=enabled
```

### Available Metrics
- CPU and memory utilization at task and service level
- Network metrics (bytes in/out)
- Storage metrics
- Task and service counts

## X-Ray Tracing

### Enable in Task Definition

Add to `base.jsonnet`:

```jsonnet
task+: {
  container_definitions+: {
    environment+: [
      { name: 'AWS_XRAY_DAEMON_ADDRESS', value: 'xray-daemon:2000' },
      { name: 'AWS_XRAY_TRACING_NAME', value: self.name },
    ],
  },
},

// Add X-Ray sidecar container
xray_container: {
  name: 'xray-daemon',
  image: 'public.ecr.aws/xray/aws-xray-daemon:latest',
  cpu: 32,
  memory: 256,
  portMappings: [
    { containerPort: 2000, protocol: 'udp' },
  ],
}
```

### IAM Permissions

Add to task role:

```json
{
  "Effect": "Allow",
  "Action": [
    "xray:PutTraceSegments",
    "xray:PutTelemetryRecords"
  ],
  "Resource": "*"
}
```

## Custom Metrics

### Publish from Application

```python
import boto3

cloudwatch = boto3.client('cloudwatch')

cloudwatch.put_metric_data(
    Namespace='CustomApp',
    MetricData=[
        {
            'MetricName': 'ProcessedItems',
            'Value': 100,
            'Unit': 'Count',
            'Dimensions': [
                {'Name': 'Environment', 'Value': 'production'},
                {'Name': 'Service', 'Value': 'my-service'}
            ]
        }
    ]
)
```

### Required IAM Permission

```json
{
  "Effect": "Allow",
  "Action": ["cloudwatch:PutMetricData"],
  "Resource": "*"
}
```

## Dashboard Example

Create CloudWatch Dashboard:

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", {"stat": "Average"}],
          [".", "MemoryUtilization", {"stat": "Average"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ap-northeast-1",
        "title": "ECS Service Metrics"
      }
    }
  ]
}
```

## Log Aggregation Best Practices

1. **Structured Logging**: Use JSON format for easier parsing
2. **Correlation IDs**: Include request IDs in all log entries
3. **Log Levels**: Use appropriate levels (DEBUG, INFO, WARN, ERROR)
4. **Sensitive Data**: Never log credentials or PII
5. **Performance**: Avoid excessive logging in hot paths

## Alerting Strategy

### Critical Alerts (Immediate Response)
- Service down (no running tasks)
- High error rate (>5%)
- Database connection failures

### Warning Alerts (Monitor)
- High CPU/Memory (>80%)
- Slow response times (>2s p99)
- Auto-scaling events

### Info Alerts (Track)
- Deployments
- Configuration changes
- Scheduled task executions
