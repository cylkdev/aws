defmodule AWS.S3.XMLParser do
  import SweetXml, only: [sigil_x: 2, xpath: 2]

  def parse_copy_object_result(xml) do
    doc = SweetXml.parse(xml)

    %{
      etag: xpath(doc, ~x"//ETag/text()"s),
      last_modified: xpath(doc, ~x"//LastModified/text()"s)
    }
  end
end
