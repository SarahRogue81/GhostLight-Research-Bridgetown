require "asciidoctor"

class AsciidocFrontMatterLoader < Bridgetown::FrontMatter::Loaders::Base
  def self.register!
    Bridgetown::FrontMatter::Loaders.register(self)
  end

  # Tell Bridgetown to intercept .adoc and .asciidoc files before standard parsing
  def self.header?(file)
    File.extname(file) =~ /^\.(adoc|asciidoc)$/i
  end

  def read(file_contents, file_path: "")
    return nil unless self.class.header?(file_path)

    # Use Asciidoctor to parse only the header for performance
    doc = Asciidoctor.load(file_contents, parse_header_only: true)
    
    # Map native AsciiDoc attributes into Bridgetown's data structure
    front_matter = {
      "title"      => doc.doctitle,
      "date"       => doc.attributes["date"],
      "author"     => doc.attributes["author"],
      "categories" => doc.attributes["categories"],
      "layout"     => doc.attributes["layout"] || "post"
    }.compact

    Bridgetown::FrontMatter::Loaders::Result.new(
      content: file_contents,
      front_matter: front_matter,
      line_count: file_contents.lines.size
    )
  end
end

# This fires immediately when Bridgetown autoloads the file.
AsciidocFrontMatterLoader.register!
