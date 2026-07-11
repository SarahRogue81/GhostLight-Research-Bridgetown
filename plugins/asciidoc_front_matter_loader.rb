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
      "title"                    => doc.doctitle,
      "description"              => doc.attributes["description"],
      "image"                    => doc.attributes["image"],
      "author"                   => doc.attributes["author"],
      "lang"                     => doc.attributes["lang"],
      "categories"               => doc.attributes["categories"],
      "date"                     => doc.attributes["date"],
      "layout"                   => doc.attributes["layout"] || "post",
      "sitemap_change_frequency" => doc.attributes["sitemap_change_frequency"],
      "sitemap_priority"         => doc.attributes["sitemap_priority"]
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
