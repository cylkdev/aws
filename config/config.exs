import Config

config :ex_utils, ExUtils.Strings,
  to_existing_atom: false,
  strict: false

# The credential and region source chains live in `AWS.Config`'s module
# attributes; restating them here only risks the two drifting apart.
config :aws, sandbox: [enabled: false]
