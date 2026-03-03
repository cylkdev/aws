defmodule AWS.Config do
  @app :aws

  def region do
    Application.get_env(@app, :region) || "us-west-1"
  end

  def access_key_id do
    Application.get_env(@app, :access_key_id) || "AWS_ACCESS_KEY_ID"
  end

  def secret_access_key do
    Application.get_env(@app, :secret_access_key) || "AWS_SECRET_ACCESS_KEY"
  end

  def sandbox do
    Application.get_env(@app, :sandbox, [])
  end

  def sandbox_enabled? do
    sandbox()[:enabled] || false
  end

  def sandbox_mode do
    sandbox()[:mode] || :local
  end

  def sandbox_scheme do
    sandbox()[:scheme] || "http://"
  end

  def sandbox_host do
    sandbox()[:host] || "localhost"
  end

  def sandbox_port do
    sandbox()[:port] || 4566
  end
end
