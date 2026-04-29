# Troubleshooting Guide

## Common Issues and Solutions

### Deployment Issues

#### Error: "No changes detected but deployment expected"

**Cause**: Diff detection may filter out actual changes due to log message patterns.

**Solution**:
```bash
# Force deployment by using ecspresso directly
ecspresso deploy --config ecspresso.jsonnet \
  --ext-str ENV=dev \
  --ext-str NAME=your-service \
  --ext-str ACCOUNT_ID=123456789012 \
  --ext-str AWS_REGION=ap-northeast-1
```

#### Error: "Invalid auto-scaling values"

**Cause**: min_capacity exceeds max_capacity or values are not numeric.

**Solution**: Check `env/*.jsonnet` file:
```jsonnet
auto_scaling: {
  min_capacity: 1,  // Must be <= max_capacity
  max_capacity: 10, // Must be >= min_capacity
}
```

#### Error: "ecspresso register failed"

**Cause**: Task definition validation failed or IAM permissions missing.

**Solution**:
1. Verify task definition: `ecspresso verify --config ecspresso.jsonnet ...`
2. Check IAM execution role has `ecs:RegisterTaskDefinition` permission
3. Validate Jsonnet syntax: `jsonnet env/dev.jsonnet`

### Configuration Issues

#### Error: "Failed to render jsonnet config"

**Cause**: Syntax error in Jsonnet files or missing required variables.

**Solution**:
```bash
# Test Jsonnet rendering
jsonnet -V ENV=dev -V ACCOUNT_ID=123456789012 -V AWS_REGION=ap-northeast-1 env/dev.jsonnet

# Check for syntax errors
jsonnetfmt --test env/dev.jsonnet
```

#### Error: "Secrets Manager access denied"

**Cause**: Task execution role lacks `secretsmanager:GetSecretValue` permission.

**Solution**: Add to execution role policy:
```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT:secret:PREFIX*"
}
```

### Network Issues

#### Error: "Task failed to start - cannot pull container image"

**Cause**: Network configuration or ECR permissions issue.

**Solution**:
1. Verify subnets have NAT Gateway or VPC endpoints for ECR
2. Check security group allows outbound HTTPS (443)
3. Verify execution role has ECR pull permissions

#### Error: "Health check failed"

**Cause**: Target group health check misconfigured or service not responding.

**Solution**:
```bash
# Check service events
aws ecs describe-services --cluster CLUSTER --services SERVICE \
  --query 'services[0].events[0:5]'

# Verify target group health check settings
aws elbv2 describe-target-health --target-group-arn ARN
```

### Rollback Procedures

#### Rollback ECS Service

```bash
# Option 1: Deploy previous task definition revision
ecspresso deploy --config ecspresso.jsonnet \
  --ext-str ENV=prd \
  --ext-str NAME=service-name \
  --ext-str ACCOUNT_ID=123456789012 \
  --ext-str AWS_REGION=ap-northeast-1 \
  --revision PREVIOUS_REVISION

# Option 2: Update service to previous task definition
aws ecs update-service \
  --cluster CLUSTER \
  --service SERVICE \
  --task-definition FAMILY:REVISION
```

#### Rollback Scheduled Task

```bash
# Register previous task definition
ecspresso register --config ecspresso.jsonnet ... --revision PREVIOUS_REVISION

# Update EventBridge rules
ecschedule -conf ecschedule.json apply -all
```

### Performance Issues

#### High Memory Usage

**Solution**: Adjust memory reservation in `env/*.jsonnet`:
```jsonnet
task+: {
  container_definitions+: {
    memory_reservation: 2048,  // Increase soft limit
  },
}
```

#### Slow Task Startup

**Cause**: Large container images or slow health checks.

**Solution**:
1. Optimize Docker image size
2. Increase `start_timeout` in config
3. Use ARM64 architecture for better performance/cost

### Monitoring Issues

#### Missing CloudWatch Logs

**Cause**: Log group not created or execution role lacks permissions.

**Solution**:
1. Verify log group exists: `aws logs describe-log-groups --log-group-name-prefix /aws/ecs/`
2. Add to execution role:
```json
{
  "Effect": "Allow",
  "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
  "Resource": "arn:aws:logs:*:*:log-group:/aws/ecs/*"
}
```

## Debug Commands

### Check Service Status
```bash
aws ecs describe-services --cluster CLUSTER --services SERVICE
```

### View Task Logs
```bash
aws logs tail /aws/ecs/task-definition/ENV-SERVICE --follow
```

### List Task Definitions
```bash
aws ecs list-task-definitions --family-prefix ENV-SERVICE
```

### Describe Task
```bash
aws ecs describe-tasks --cluster CLUSTER --tasks TASK_ID
```

### Check Auto Scaling
```bash
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/CLUSTER/SERVICE
```

## Getting Help

1. Check AWS ECS service events for detailed error messages
2. Review CloudWatch Logs for application errors
3. Verify IAM permissions using AWS IAM Policy Simulator
4. Test network connectivity from within the VPC
