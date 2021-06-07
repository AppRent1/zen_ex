defmodule ZenEx.HTTPClient do

  @moduledoc false

  @content_type "application/json"

  alias ZenEx.Collection

  def get("https://" <> _ = url) do
    url |> HTTPoison.get(basic_auth_header())
  end
  def get(endpoint) do
    endpoint |> build_url |> get
  end
  def get("https://" <> _ = url, decode_as) do
    url |> get |> _build_entity(decode_as)
  end
  def get(endpoint, decode_as) do
    endpoint |> build_url |> get(decode_as)
  end

  def post(endpoint, %{} = param, decode_as) do
    build_url(endpoint)
    |> HTTPoison.post(Poison.encode!(param), ["Content-Type": @content_type] ++ basic_auth_header())
    |> _build_entity(decode_as)
  end

  def put(endpoint, %{} = param, decode_as) do
    build_url(endpoint)
    |> HTTPoison.put(Poison.encode!(param), ["Content-Type": @content_type] ++ basic_auth_header())
    |> _build_entity(decode_as)
  end

  def delete(endpoint, decode_as), do: delete(endpoint) |> _build_entity(decode_as)
  def delete(endpoint) do
    build_url(endpoint) |> HTTPoison.delete(basic_auth_header())
  end

  def build_url(endpoint) do
    "https://#{get_env(:subdomain)}.zendesk.com#{endpoint}"
  end

  def basic_auth do
    "#{get_env(:user)}/token:#{get_env(:api_token)}"
    |> Base.encode64()
  end

  def basic_auth_header do
    [
      "Authorization": "Basic #{basic_auth()}"
    ]
  end

  def _build_entity({:ok ,%HTTPoison.Response{} = res}, [{key, [module]}]) do
    {entities, page} =
      res.body
      |> Poison.decode!(keys: :atoms, as: %{key => [struct(module)]})
      |> Map.pop(key)

    struct(Collection, Map.merge(page, %{entities: entities, decode_as: [{key, [module]}]}))
  end
  def _build_entity({:ok, %HTTPoison.Response{} = res}, [{key, module}]) do
    res.body |> Poison.decode!(keys: :atoms, as: %{key => struct(module)}) |> Map.get(key)
  end
  def _build_entity({:error, %HTTPoison.Error{reason: error}}, _) do
    {:error, error}
  end

  defp get_env(key) do
   case Process.get(:zendesk_config_module) do
     nil -> Application.get_env(:zen_ex, key)
     config_module -> Application.get_env(:zen_ex, config_module)[key]
   end
 end
end
