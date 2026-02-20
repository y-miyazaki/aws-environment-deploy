// Shared task definition template for ECS services and scheduled tasks
// Returns a function that generates task definition from config
// Usage: local template = import 'templates/task-definition.jsonnet';
//        template(config)

function(config) {
  containerDefinitions: [
    {
      command: config.container_definitions.command,
      cpu: config.container_definitions.cpu,
      dnsSearchDomains: [],
      dnsServers: [],
      disableNetworking: false,
      dockerSecurityOptions: [],
      environment: config.container_definitions.environment,
      environmentFiles: [],
      essential: true,
      extraHosts: [],
      image: config.container_definitions.image,
      interactive: false,
      links: [],
      logConfiguration: {
        logDriver: config.container_definitions.log_configuration.log_driver,
        options: {
          'awslogs-group': config.container_definitions.log_configuration.options.log_group,
          'awslogs-create-group': config.container_definitions.log_configuration.options.create_group,
          'awslogs-region': config.container_definitions.log_configuration.options.region,
          'awslogs-stream-prefix': config.container_definitions.log_configuration.options.stream_prefix,
        },
      },
      memory: config.container_definitions.memory,
      memoryReservation: config.container_definitions.memory_reservation,
      mountPoints: [],
      name: config.container_definitions.name,
      portMappings: if std.objectHas(config.container_definitions, 'port_mappings')
      then [
        {
          containerPort: config.container_definitions.port_mappings.container_port,
          hostPort: config.container_definitions.port_mappings.host_port,
          name: config.container_definitions.port_mappings.name,
          protocol: config.container_definitions.port_mappings.protocol,
        },
      ]
      else [],
      privileged: false,
      pseudoTerminal: false,
      readonlyRootFilesystem: config.container_definitions.readonly_root_filesystem,
      secrets: config.container_definitions.secrets,
      startTimeout: config.container_definitions.start_timeout,
      systemControls: [],
      volumesFrom: [],
    },
  ],
  cpu: config.cpu,
  executionRoleArn: config.execution_role_arn,
  family: config.family,
  memory: config.memory,
  networkMode: config.network_mode,
  requiresCompatibilities: config.requires_compatibilities,
  runtimePlatform: {
    cpuArchitecture: config.runtime_platform.cpu_architecture,
    operatingSystemFamily: config.runtime_platform.operating_system_family,
  },
  tags: config.tags,
  taskRoleArn: config.role_arn,
  volumes: [],
}
