# aws-environment-deploy

**Sample repository** for managing code outside Terraform (ECS services, ECS scheduled tasks, scripts) in AWS environments

> **Note**: This is a template/example project. Customize configurations for your production use.

## 📁 Project Structure

```
.
├── ecs/                    # ECS configuration (Jsonnet + ecspresso)
│   ├── config.jsonnet      # Global settings
│   ├── registry.jsonnet    # Service/task registry
│   ├── templates/          # Shared templates
│   ├── ecs-service/        # ECS service definitions
│   └── ecs-scheduled-task/ # Scheduled task definitions
├── scripts/                # Deploy & operation scripts
│   ├── terraform/          # Terraform-related scripts
│   └── lib/                # Common libraries
└── test/                   # Test code
```

## 🚀 Quick Start

### Prerequisites

```bash
# Required tools
aws-cli >= 2.0
ecspresso >= 2.0
jsonnet >= 0.20
jq >= 1.6
```

### Deploy ECS Service

```bash
# Verify
./scripts/terraform/aws_deploy_ecs_service.sh \
  -p ecs/ecs-service/test-server \
  -e dev \
  verify

# Deploy
./scripts/terraform/aws_deploy_ecs_service.sh \
  -p ecs/ecs-service/test-server \
  -e dev \
  deploy
```

## 📝 Creating a New ECS Service

### 1. Copy Service Directory

```bash
cp -r ecs/ecs-service/test-server ecs/ecs-service/your-service
```

### 2. Edit base.jsonnet

```jsonnet
local base = {
  name: 'your-service',
  cluster: config.helpers.buildName(prefix, 'your-cluster'),
  container_port: 8080,
  image_repository: '%s.dkr.ecr.%s.amazonaws.com/%s' % [accountId, region, self.name],
  // ...
};
```

### 3. Customize Environment Settings

```jsonnet
// env/prd.jsonnet
local base = import 'base.jsonnet';

base {
  task+: {
    cpu: '2048',
    memory: '4096',
    container_definitions+: {
      image_tag: 'v1.0.0',  // Explicit version for production
    },
  },
  auto_scaling+: {
    max_capacity: 20,
    min_capacity: 2,
  },
}
```

### 4. Register in registry.jsonnet

```jsonnet
services: {
  'your-service': {
    dev: import './ecs-service/your-service/env/dev.jsonnet',
    prd: import './ecs-service/your-service/env/prd.jsonnet',
  },
}
```

## 📅 Creating a New ECS Scheduled Task

### 1. Copy Task Directory

```bash
cp -r ecs/ecs-scheduled-task/test-batch ecs/ecs-scheduled-task/your-batch
```

### 2. Edit base.jsonnet

```jsonnet
local base = {
  name: 'your-batch',
  cluster: config.helpers.buildName(prefix, 'batch-cluster'),
  image_repository: '%s.dkr.ecr.%s.amazonaws.com/%s' % [accountId, region, self.name],
  command: ['python', 'batch.py'],
  // ...
};
```

### 3. Configure Schedule in ecschedule.jsonnet

```jsonnet
{
  batch_name: base.name,
  cluster: base.cluster,
  rules: [
    {
      name: config.helpers.buildName(prefix, base.name),
      schedule_expression: 'cron(0 2 * * ? *)',  // Daily at 2:00 AM UTC
      task_count: 1,
    },
  ],
}
```

### 4. Deploy Scheduled Task

```bash
# Verify
./scripts/terraform/aws_deploy_ecs_scheduled_task.sh \
  -p ecs/ecs-scheduled-task/your-batch \
  -e dev \
  diff

# Deploy
./scripts/terraform/aws_deploy_ecs_scheduled_task.sh \
  -p ecs/ecs-scheduled-task/your-batch \
  -e dev \
  apply

# Manual trigger
./scripts/terraform/aws_deploy_ecs_scheduled_task.sh \
  -p ecs/ecs-scheduled-task/your-batch \
  -e dev \
  run -n dev-your-batch
```

## ⚙️ Configuration Reference

### Environment Variables

| Variable     | Required | Default | Description                       |
| ------------ | -------- | ------- | --------------------------------- |
| `ENV`        | ✓        | -       | Environment name (dev/qa/stg/prd) |
| `ACCOUNT_ID` | ✓        | -       | AWS Account ID                    |
| `AWS_REGION` | ✓        | -       | AWS Region                        |

### Resource Settings

```jsonnet
// CPU/Memory (Fargate)
task: {
  cpu: '1024',     // 1 vCPU
  memory: '3072',  // 3 GB
}

// Auto Scaling
auto_scaling: {
  min_capacity: 1,
  max_capacity: 10,
  policies: [
    { predefined_metric_type: 'ECSServiceAverageCPUUtilization', target_value: 75.0 },
  ],
}
```

## 🔒 Security

### Secrets Manager Integration

```jsonnet
secrets: [
  {
    name: 'DB_PASSWORD',
    valueFrom: config.helpers.buildSecretsManager(
      region, accountId, 'dev/db/credentials:password'
    ),
  },
]
```

### IAM Roles

- **Task Role**: AWS permissions used by containers
- **Execution Role**: Permissions for ECS agent (ECR pull, CloudWatch Logs, etc.)

## 🛠️ Troubleshooting

### Deployment Fails

```bash
# Verify configuration
ecspresso verify --config ecspresso.jsonnet \
  --ext-str ENV=dev \
  --ext-str ACCOUNT_ID=123456789012 \
  --ext-str AWS_REGION=ap-northeast-1

# Check diff
ecspresso diff --config ecspresso.jsonnet ...
```

### Secrets Manager Errors

```bash
# Check secret exists
aws secretsmanager describe-secret --secret-id dev/db/credentials

# Verify Execution Role permissions
aws iam get-role-policy --role-name dev-test-ecs-task-execution-role
```

## 📚 Related Documentation

- [ecspresso](https://github.com/kayac/ecspresso)
- [Jsonnet](https://jsonnet.org/)
- [AWS ECS](https://docs.aws.amazon.com/ecs/)
