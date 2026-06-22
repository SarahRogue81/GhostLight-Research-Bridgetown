module Shared
  class Navbar < Bridgetown::Component
    attr_reader :metadata, :resource, :strategy

    # @param metadata [HashWithDotAccess::Hash]
    # @param resource [Bridgetown::Resource::Base]
    def initialize(metadata:, resource:)
      @metadata, @resource = metadata, resource

      @strategy = Willamette.navbar(
        self,
        logo: "/willamette/bridgetown-avatar.svg",
        logo_alt: "Website Logo",
        search: true,
        site_title: metadata.title,
        nav_links: [
          Willamette.link(title: t("nav.blog"), url: "/blog"),
          Willamette.link(title: t("nav.about"), url: "/about"),
          Willamette.link(icon: "mastodon", icon_family: "brands", icon_label: "Mastodon", title: nil, url: "https://mastodon.social"),
        ]
      )
    end
  end

  class Sidebar < Bridgetown::Component
    attr_reader :metadata, :resource, :strategy

    # @param metadata [HashWithDotAccess::Hash]
    # @param resource [Bridgetown::Resource::Base]
    def initialize(metadata:, resource:)
      @metadata, @resource = metadata, resource

      explore_links = if resource.is_a?(Bridgetown::Resource::Base) && resource.collection.label == "docs"
                        Willamette.links_for(resource)
                      end

      @strategy = Willamette.sidebar(
        self,
        description: metadata.description,
        explore_links:,
        follow_links: [
          Willamette.link(icon: "rss", title: "Newsfeed", url: "/feed.xml"),
          Willamette.link(icon: "bluesky", icon_family: "brands", title: "@myblue", url: "https://bsky.social"),
        ],
        subscribe: true,
        see_also_links: [
          Willamette.link(icon: "file-lines", title: "Another Project", url: "#/another"),
          Willamette.link(icon: "keyboard", title: "Personal Journal", url: "#/journal"),
        ]
      )
    end
  end
end
