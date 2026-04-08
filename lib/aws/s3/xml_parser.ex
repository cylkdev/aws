defmodule AWS.S3.XMLParser do
  import SweetXml, only: [sigil_x: 2, xpath: 2]

  def parse_copy_object_result(xml) do
    doc = SweetXml.parse(xml)

    %{
      etag: xpath(doc, ~x"//ETag/text()"s),
      last_modified: xpath(doc, ~x"//LastModified/text()"s)
    }
  end

  @doc """
  Parses S3 notification configuration XML and checks for EventBridge status.

  Returns a map with `:event_bridge_enabled` (boolean) and `:raw_xml` (original XML).
  """
  @spec parse_notification_configuration(xml :: binary()) :: map()
  def parse_notification_configuration(xml) do
    doc = SweetXml.parse(xml)
    event_bridge_enabled = xpath(doc, ~x"//EventBridgeConfiguration"o) != nil
    %{event_bridge_enabled: event_bridge_enabled, raw_xml: xml}
  end
end
