require "asciidoctor"
require "bson"
require "bcrypt"
require "json"

class Routes::Portal < Bridgetown::Rack::Routes
  def portal_manifest_data
    @portal_manifest_data ||= begin
      manifest_file = File.join(Dir.pwd, ".bridgetown-cache", "frontend-bundling", "manifest.json")
      JSON.parse(File.read(manifest_file)) if File.exist?(manifest_file)
    rescue StandardError
      {}
    end
  end

  def portal_asset_path(asset_key)
    if (manifest = portal_manifest_data)[asset_key]
      return "/_bridgetown/static/#{manifest[asset_key]}"
    end

    fallback = case asset_key
               when "styles/index.css"
                 Dir.glob("output/_bridgetown/static/index.*.css").first
               when "javascript/index.js"
                 Dir.glob("output/_bridgetown/static/index.*.js").first
               end

    return "/#{fallback.sub(%r{^output/}, "")}" if fallback
    "/_bridgetown/static/#{File.basename(asset_key)}"
  end

  def portal_client_id_predicate(client_id)
    return { client_id: client_id } if client_id.nil? || !client_id.is_a?(String)

    if client_id.match?(/\A[0-9a-f]{24}\z/i)
      { "$or" => [{ client_id: client_id }, { client_id: BSON::ObjectId.from_string(client_id) }] }
    else
      { client_id: client_id }
    end
  end

  def portal_layout(title:, main_content:, error_message: "", logged_in: false)
    css_path = portal_asset_path("styles/index.css")
    js_path = portal_asset_path("javascript/index.js")

    logout_button = if logged_in
                      '<a href="/portal/logout" class="wa-button wa-outlined wa-size-s">Logout</a>'
                    else
                      ''
                    end

    <<~HTML
      <!DOCTYPE html>
      <html lang="en" class="wa-palette-default">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{title}</title>
        <link rel="stylesheet" href="#{css_path}">
        <script src="#{js_path}" defer></script>
        <style>
          body.page { min-height: 100vh; margin: 0; background: var(--wa-color-surface, #f7fafc); color: var(--wa-color-text-normal, #1f2937); }
          .portal-header { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 1rem; padding: 1.25rem 1.5rem; max-width: 1200px; margin: 0 auto; background: var(--wa-color-surface-default, #ffffff); border-bottom: 1px solid var(--wa-color-surface-border, rgba(15,23,42,0.08)); }
          .portal-header h1 { margin: 0; font-size: clamp(1.5rem, 2vw, 2.25rem); color: var(--wa-color-text-normal, #1f2937); }
          .portal-nav { display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: center; }
          .portal-nav a { color: var(--wa-color-text-link, #0369a1); }
          .portal-main { max-width: 1000px; margin: 0 auto; padding: 0 1.5rem 2rem; }
          .portal-content { background: var(--wa-color-surface-default, #ffffff); border: 1px solid var(--wa-color-surface-border, rgba(15,23,42,0.08)); border-radius: 1rem; box-shadow: var(--wa-shadow-small, 0 1px 2px rgba(0,0,0,.08)); padding: 1.5rem; }
          .portal-alert { border-left: 4px solid var(--wa-color-danger-border-normal, #e53e3e); background: var(--wa-color-danger-fill-quiet, rgba(239,68,68,0.1)); color: var(--wa-color-danger-on-normal, #991b1b); padding: 1rem; border-radius: 0.75rem; margin-bottom: 1rem; }
          .portal-card { display: grid; gap: 1rem; margin-bottom: 1rem; }
          .portal-card a { color: inherit; }
          .portal-grid { display: grid; gap: 0.75rem; }
          .portal-grid article { background: var(--wa-color-surface-raised, #f8fafc); color: var(--wa-color-text-normal, #1f2937); border: 1px solid var(--wa-color-surface-border, rgba(15,23,42,0.08)); border-radius: 1rem; padding: 1.25rem; }
          .portal-grid h2 { margin-top: 0; }
          @media (max-width: 960px) { .portal-main { padding: 0 1rem 1.5rem; } }
        </style>
      </head>
      <body class="default">
        <header class="portal-header">
          <div>
            <h1>GhostLight Research Portal</h1>
            <p class="wa-text-s-muted">Secure client access to your content.</p>
          </div>
          <div class="portal-nav">
            <a class="wa-link" href="/">Home</a>
            <a class="wa-link" href="/blog">Blog</a>
            <a class="wa-link" href="/about">About</a>
            <a class="wa-link" href="https://mastodon.social" target="_blank" rel="noreferrer noopener">Mastodon</a>
            #{logout_button}
          </div>
        </header>

        <main class="portal-main" style="padding-top: 2rem;">
          #{error_message}
          #{main_content}
        </main>
      </body>
      </html>
    HTML
  end

  route do |r|
    # 1. GLOBAL LOGIN GUARD FOR PORTAL PATHS ONLY
    if r.path.start_with?("/portal")
      unless r.env['rack.session'] && r.env['rack.session'][:client_id]
        unless r.path == "/portal/login" || r.path == "/portal/auth"
          r.redirect "/portal/login"
        end
      end
    end

    # 2. THE DASHBOARD LIST
    # GET /portal
    r.is "portal" do
      client_id = r.env['rack.session'][:client_id]
      error_msg = ""
      
      begin
        @articles = GhostLight.db[:articles]
                      .find(portal_client_id_predicate(client_id))
                      .sort(modified: -1)
                      .to_a
      rescue => e
        @articles = []
        error_msg = "<p style='color:#e53e3e;'>Database connection error: #{e.message}</p>"
      end

      articles_html = if @articles.empty?
                        "<p class=\"wa-text-s-muted\">No research documents available for your account at this time.</p>"
                      else
                        article_cards = @articles.map do |article|
                          date_str = if article[:modified].respond_to?(:strftime)
                                       article[:modified].strftime("%B %d, %Y")
                                     else
                                       "Recent Release"
                                     end
                          <<~HTML
                            <h2><a href="/portal/articles/#{article[:_id]}">#{article[:title]}</a></h2>
                            <p class="wa-text-s-muted">Published: #{date_str}</p>
                          HTML
                        end.join

                        "<div class=\"portal-grid\">#{article_cards}</div>"
                      end

      portal_layout(
        title: "Client Portal | GhostLight Research",
        main_content: "<h2>Your Research Documents</h2>\n#{articles_html}",
        error_message: error_msg,
        logged_in: true
      )
    end

    # 3. THE ASCIIDOC COMPILER ROUTE
    # GET /portal/articles/:id
    r.on "portal/articles", String do |article_id|
      r.get do
        begin
          object_id = BSON::ObjectId.from_string(article_id)
          
          article = GhostLight.db[:articles].find(
            _id: object_id,
            "$or" => [
              { client_id: r.env['rack.session'][:client_id] },
              { client_id: (BSON::ObjectId.from_string(r.env['rack.session'][:client_id]) if r.env['rack.session'][:client_id].is_a?(String) && r.env['rack.session'][:client_id].match?(/\A[0-9a-f]{24}\z/i)) }
            ].compact
          ).first

          if article && article[:asciidoc_content]
            # Safely extract and format the modified date
            modified = article[:modified]
            published_date = nil
            published_datetime = nil

            if modified && (modified.respond_to?(:strftime) || modified.is_a?(Time))
              local_modified = modified.respond_to?(:getlocal) ? modified.getlocal : modified
              published_date = local_modified.strftime("%Y-%m-%d")
              published_datetime = local_modified.strftime("%Y-%m-%d %H:%M:%S %z")
            end

            article_html = Asciidoctor.convert(
              article[:asciidoc_content],
              header_footer: true,
              safe: :safe,
              standalone: true,
              attributes: published_date ? { "revdate" => published_date, "docdatetime" => published_datetime } : {}
            )

            if article_html.match?(%r{<\s*html\b}i)
              full_html = article_html
            else
              full_html = <<~HTML
                <!DOCTYPE html>
                <html lang="en">
                <head>
                  <meta charset="utf-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>#{article[:title] || "Research Article"}</title>
                </head>
                <body>
                  <article>
                    #{article_html}
                  </article>
                </body>
                </html>
              HTML
            end

            r.halt [200, { "Content-Type" => "text/html; charset=utf-8" }, [full_html]]
          else
            r.redirect "/portal?error=not_found"
          end
        rescue => e
          r.redirect "/portal?error=compilation_failed"
        end
      end
    end

    # 4. SECURE LOGIN UI
    # GET /portal/login
    r.is "portal/login" do
      error_message = if r.params["error"] == "failed"
                        "<div class=\"portal-alert\">Invalid Client ID or Passphrase.</div>"
                      else
                        ""
                      end

      portal_layout(
        title: "Login | GhostLight Research Portal",
        main_content: <<~HTML,
          <h2>Portal Login</h2>
          <p class="wa-text-s-muted">Enter your client ID and passphrase to access your secure research content.</p>
          #{error_message}
          <form action="/portal/auth" method="POST" class="wa-stack">
            <label class="wa-field"><span>CLIENT ID</span><input type="text" name="client_id" required autofocus></label>
            <label class="wa-field"><span>PASSPHRASE</span><input type="password" name="password" required></label>
            <button type="submit" class="wa-brand wa-size-m">Access Portal</button>
          </form>
        HTML
        error_message: error_message,
        logged_in: false
      )
    end

    # 5. SECURE AUTHENTICATION PROCESSING
    # POST /portal/auth
    r.post "portal/auth" do
      client = GhostLight.db[:clients].find(client_id: r.params["client_id"]).first
      session = r.env['rack.session']

      if client && client[:password_digest]
        bcrypt_password = BCrypt::Password.new(client[:password_digest])
        
        if bcrypt_password == r.params["password"]
          if client[:archived]
            r.redirect "/portal/logout"
            r.halt
          end

          if session
            session[:client_id] = client[:client_id]
            r.redirect "/portal"
            r.halt
          end

          r.redirect "/portal/login?error=session"
          r.halt
        end
      end

      r.redirect "/portal/login?error=failed"
    end

    # 6. LOGOUT ACTION
    # GET /portal/logout
    r.is "portal/logout" do
      r.env['rack.session'].clear if r.env['rack.session']
      r.redirect "/portal/login"
    end
  end
end
