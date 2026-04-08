defmodule AWS.MixProject do
  use Mix.Project

  def project do
    [
      app: :aws,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {AWS.Application, []}
    ]
  end

  defp aliases do
    [
      compile: compile_alias()
    ]
  end

  defp compile_alias do
    "compile" <> warnings_as_errors(Mix.env())
  end

  defp warnings_as_errors(true), do: " --warnings-as-errors"
  defp warnings_as_errors(_), do: ""

  defp docs do
    [
      main: "AWS",
      extras: ["README.md"],
      groups_for_modules: [
        "Core": [
          AWS,
          AWS.Error
        ],
        "S3": [
          AWS.S3
        ],
        "EventBridge": [
          AWS.EventBridge
        ],
        "CloudWatch": [
          AWS.CloudWatch
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40.1", only: :dev},
      {:ex_aws, "~> 2.6"},
      {:ex_aws_s3, "~> 2.5"},
      {:configparser_ex, "~> 5.0"},
      {:sweet_xml, "~> 0.7.5"},
      {:timex, "~> 3.7"},
      {:finch, "~> 0.21.0"},
      {:req, "~> 0.5.17"},
      {:error_message, "~> 0.3.3"},
      {:recase, "~> 0.9.1"},
      {:ex_aws_cloudwatch, "~> 2.0"},
      {:ex_aws_eventbridge, "~> 0.1.1"},
      {:sandbox_registry, ">= 0.0.0", only: [:dev, :test], optional: true}
    ]
  end
end
