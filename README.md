# aws-environment-deploy

**Sample repository** for managing code outside Terraform (ECS services, ECS scheduled tasks, scripts) in AWS environments

> **Note**: This is a template/example project. Customize configurations for your production use.

<!-- omit in toc -->
## Table of Contents
- [aws-environment-deploy](#aws-environment-deploy)
  - [📁 Project Structure](#-project-structure)
  - [🚀 Quick Start](#-quick-start)
    - [Prerequisites](#prerequisites)
    - [Deploy ECS Service](#deploy-ecs-service)
  - [📝 Creating a New ECS Service](#-creating-a-new-ecs-service)
    - [1. Copy Service Directory](#1-copy-service-directory)
    - [2. Edit base.jsonnet](#2-edit-basejsonnet)
    - [3. Customize Environment Settings](#3-customize-environment-settings)
    - [4. Register in registry.jsonnet](#4-register-in-registryjsonnet)
  - [📅 Creating a New ECS Scheduled Task](#-creating-a-new-ecs-scheduled-task)
    - [1. Copy Task Directory](#1-copy-task-directory)
    - [2. Edit base.jsonnet](#2-edit-basejsonnet-1)
    - [3. Configure Schedule in env<env>.jsonnet](#3-configure-schedule-in-envenvjsonnet)
    - [4. Deploy Scheduled Task](#4-deploy-scheduled-task)
  - [⚙️ Configuration Reference](#️-configuration-reference)
    - [Environment Variables](#environment-variables)
    - [Resource Settings](#resource-settings)
  - [🔒 Security](#-security)
    - [Secrets Manager Integration](#secrets-manager-integration)
    - [IAM Roles](#iam-roles)
  - [🛠️ Troubleshooting](#️-troubleshooting)
    - [Deployment Fails](#deployment-fails)
    - [Secrets Manager Errors](#secrets-manager-errors)
  - [📚 Related Documentation](#-related-documentation)

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
│   ├── go/                 # Go build & validation scripts
│   ├── db/                 # Database (SchemaSpy) scripts
│   ├── nodejs/             # Node.js validation scripts
│   ├── shell-script/       # Shell script validation
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

### Naming Convention (Required)

For both ECS services and scheduled tasks, these three names must be identical:

- Directory name under `ecs/ecs-service/` or `ecs/ecs-scheduled-task/`
- Key name in `ecs/registry.jsonnet`
- `NAME` value passed to Jsonnet/ecspresso (deployment scripts derive this from directory name)

Example: `ecs/ecs-service/test-server` -> registry key `'test-server'` -> `NAME=test-server`

If they do not match, deployment scripts fail to resolve `registry.services[name][env]` or `registry.scheduled_tasks[name][env]`.

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

Note: the service key (`'your-service'`) must match the directory name (`ecs/ecs-service/your-service`).

## 📅 Creating a New ECS Scheduled Task

### 1. Copy Task Directory

```bash
cp -r ecs/ecs-scheduled-task/test-batch ecs/ecs-scheduled-task/your-batch
```

### 2. Edit base.jsonnet

```jsonnet
local base = {
  name: 'your-batch',
  cluster: config.helpers.buildName(prefix, 'recommend-cluster'),
  image_repository: '%s.dkr.ecr.%s.amazonaws.com/%s' % [accountId, region, self.name],
  command: ['python', 'batch.py'],
  // ...
};
```

### 3. Configure Schedule in env/<env>.jsonnet

```jsonnet
// env/dev.jsonnet
local base = import 'base.jsonnet';

base {
  base+: {
    rules+: {
      schedule_expression: 'cron(0 2 * * ? *)',  // Daily at 2:00 AM UTC
    },
  },
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

Note: the scheduled task key (`'your-batch'`) must match the directory name (`ecs/ecs-scheduled-task/your-batch`).

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
  --ext-str NAME=your-service \
  --ext-str ACCOUNT_ID=123456789012 \
  --ext-str AWS_REGION=ap-northeast-1

# Check diff
ecspresso diff --config ecspresso.jsonnet \
  --ext-str ENV=dev \
  --ext-str NAME=your-service \
  --ext-str ACCOUNT_ID=123456789012 \
  --ext-str AWS_REGION=ap-northeast-1
```

### Secrets Manager Errors

```bash
# Check secret exists
aws secretsmanager describe-secret --secret-id dev/db/credentials

# Verify Execution Role permissions
aws iam get-role-policy --role-name dev-test-ecs-task-execution-role
```

## 📚 Related Documentation

- [Specification](docs/SPEC.md) - Normative rules for configuration and implementation decisions
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Monitoring & Observability](docs/MONITORING.md) - CloudWatch, X-Ray, and alerting
- [Performance Optimization](docs/PERFORMANCE.md) - Optimization strategies and best practices
- [Improvements Summary](docs/IMPROVEMENTS.md) - Changes and enhancements made to the project
- [ecspresso](https://github.com/kayac/ecspresso)
- [Jsonnet](https://jsonnet.org/)
- [AWS ECS](https://docs.aws.amazon.com/ecs/)
