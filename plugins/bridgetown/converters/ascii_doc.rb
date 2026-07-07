require "asciidoctor"

class Bridgetown::Converters::AsciiDoc < Bridgetown::Converter
  # Set priority so it handles files before the Identity converter catches them
  priority :high

  # Tell Bridgetown to process these source extensions
  def matches(ext, _convertible = nil)
    ext =~ /^\.(adoc|asciidoc)$/i
  end

  # Output everything into static HTML files
  def output_ext(ext)
    ".html"
  end

  # The conversion pipeline handoff
  def convert(content, convertible = nil)
    # Setup modern rendering options matching your workspace style
    options = {
      safe: :safe,
      attributes: {
        "icons" => "font",
        "sectanchors" => true,
        "source-highlighter" => "rouge", # Integrates with Bridgetown's default highlighters
        "imagesdir" => "/images@" # trailing @ makes this a soft default, overridable by an in-document :imagesdir:
      }
    }

    # Render the AsciiDoc content string to safe HTML5
    Asciidoctor.convert(content, options)
  end
end
