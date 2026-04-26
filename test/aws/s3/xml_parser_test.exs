defmodule AWS.S3.XMLParserTest do
  use ExUnit.Case, async: true

  alias AWS.S3.XMLParser

  describe "parse_notification_configuration/1" do
    test "detects EventBridge enabled" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <NotificationConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
        <EventBridgeConfiguration/>
      </NotificationConfiguration>
      """

      assert %{event_bridge_enabled: true, raw_xml: ^xml} =
               XMLParser.parse_notification_configuration(xml)
    end

    test "detects EventBridge disabled" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <NotificationConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      </NotificationConfiguration>
      """

      assert %{event_bridge_enabled: false, raw_xml: ^xml} =
               XMLParser.parse_notification_configuration(xml)
    end

    test "detects EventBridge with other configs present" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <NotificationConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
        <TopicConfiguration>
          <Topic>arn:aws:sns:us-west-1:123:my-topic</Topic>
          <Event>s3:ObjectCreated:*</Event>
        </TopicConfiguration>
        <EventBridgeConfiguration></EventBridgeConfiguration>
      </NotificationConfiguration>
      """

      assert %{event_bridge_enabled: true} =
               XMLParser.parse_notification_configuration(xml)
    end

    test "returns false when only other configs present" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <NotificationConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
        <TopicConfiguration>
          <Topic>arn:aws:sns:us-west-1:123:my-topic</Topic>
          <Event>s3:ObjectCreated:*</Event>
        </TopicConfiguration>
      </NotificationConfiguration>
      """

      assert %{event_bridge_enabled: false} =
               XMLParser.parse_notification_configuration(xml)
    end

    test "handles self-closing EventBridgeConfiguration" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <NotificationConfiguration>
        <EventBridgeConfiguration/>
      </NotificationConfiguration>
      """

      assert %{event_bridge_enabled: true} =
               XMLParser.parse_notification_configuration(xml)
    end
  end
end
