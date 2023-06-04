defmodule AWS.Adapter.HTTP do
  defmodule Response do
    defstruct [:status, :body, :headers, :request]
  end

  defmodule Request do
    defstruct [
      :body,
      scheme: "",
      host: "",
      port: 80,
      path: "/",
      query: "",
      headers: []
    ]
  end
end
