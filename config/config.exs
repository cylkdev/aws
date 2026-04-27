import Config

config :aws,
  access_key_id: [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_ACCESS_KEY_ID"},
    :instance_role,
    :ecs_task_role
  ],
  secret_access_key: [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_SECRET_ACCESS_KEY"},
    :instance_role,
    :ecs_task_role
  ],
  security_token: [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_SESSION_TOKEN"},
    :instance_role,
    :ecs_task_role
  ],
  region: [
    {:awscli, {:system, "AWS_PROFILE"}, 30},
    {:awscli, "default", 30},
    {:system, "AWS_REGION"},
    {:system, "AWS_DEFAULT_REGION"},
    "us-east-1"
  ],
  sandbox: [
    enabled: Mix.env() === :test,
    mode: :local,
    scheme: "http://",
    host: "localhost",
    port: 4566
  ]
