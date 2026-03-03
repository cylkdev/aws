import Config

config :ex_aws,
  json_codec: Jason,
  http_client: AWS.HTTP,
  access_key_id: [
    {:awscli, System.get_env("AWS_PROFILE", "default"), 30},
    {:system, "AWS_ACCESS_KEY_ID"},
    {:awscli, System.get_env("AWS_PROFILE", "default"), 30}
  ],
  secret_access_key: [
    {:awscli, System.get_env("AWS_PROFILE", "default"), 30},
    {:system, "AWS_SECRET_ACCESS_KEY"},
    {:awscli, System.get_env("AWS_PROFILE", "default"), 30}
  ]
