defmodule AWS.MixProject do
  use Mix.Project

  @mix_env Mix.env()
  @version "0.1.0"

  def project do
    [
      app: :aws,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        plt_ignore_apps: [],
        plt_local_path: "dialyzer",
        plt_core_path: "dialyzer",
        list_unused_filters: true,
        ignore_warnings: ".dialyzer-ignore.exs",
        flags: [:unmatched_returns, :no_improper_lists]
      ]
    ]
  end

  def cli do
    [
      doctor: :test,
      coverage: :test,
      dialyzer: :test,
      coveralls: :test,
      "coveralls.lcov": :test,
      "coveralls.json": :test,
      "coveralls.html": :test,
      "coveralls.detail": :test,
      "coveralls.post": :test
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
    if @mix_env === :test do
      "compile --warnings-as-errors"
    else
      "compile"
    end
  end

  defp docs do
    [
      main: "AWS",
      extras: ["README.md"],
      groups_for_modules: [
        Core: [
          AWS,
          AWS.Error
        ],
        S3: [
          AWS.S3
        ],
        EventBridge: [
          AWS.EventBridge
        ],
        Logs: [
          AWS.Logs
        ],
        SSM: [
          AWS.SSM
        ],
        IAM: [
          AWS.IAM
        ],
        "Identity Center": [
          AWS.IdentityCenter
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:blitz_credo_checks, "~> 0.1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13", only: :test, runtime: false},
      # ---
      {:sandbox_registry, ">= 0.0.0", optional: true},
      # ---
      {:sweet_xml, "~> 0.7.5"},
      {:finch, "~> 0.19"},
      {:req, "~> 0.5"},
      {:cowboy, "~> 2.10", only: :test},
      {:error_message, "~> 0.3.3"},
      {:recase, "~> 0.9.1"},
      {:ex_utils, git: "https://github.com/cylkdev/ex_utils.git", branch: "main"}
    ]
  end
end
