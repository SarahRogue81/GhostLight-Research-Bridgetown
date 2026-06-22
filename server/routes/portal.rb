require "asciidoctor"
require "bson"
require "bcrypt"

class Routes::Portal < Bridgetown::Rack::Routes
  route do |r|
    # 1. GLOBAL LOGIN GUARD
    # Verified directly against the global Rack middleware stack
    unless r.env['rack.session'] && r.env['rack.session'][:client_id]
      unless r.path == "/portal/login" || r.path == "/portal/auth"
        r.redirect "/portal/login"
      end
    end

    # 2. THE DASHBOARD LIST
    # GET /portal
    r.is "portal" do
      client_id = r.env['rack.session'][:client_id]
      error_msg = ""
      
      begin
        @articles = GhostLight.db[:articles]
                      .find(client_id: client_id)
                      .sort(published_at: -1)
                      .to_a
      rescue => e
        @articles = []
        error_msg = "<p style='color:#e53e3e;'>Database connection error: #{e.message}</p>"
      end

      articles_html = if @articles.empty?
                        "<p style='color:#718096;'>No research syntheses available for your account at this time.</p>"
                      else
                        @articles.map do |article|
                          date_str = if article[:published_at].respond_to?(:strftime)
                                       article[:published_at].strftime("%B %d, %Y")
                                     else
                                       "Recent Release"
                                     end
                          <<~HTML
                            <article style="background: white; padding: 24px; border: 1px solid #e2e8f0; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);">
                              <h2 style="margin-top: 0; margin-bottom: 8px; font-size: 1.35rem;">
                                <a href="/portal/articles/#{article[:_id]}" style="color: #3182ce; text-decoration: none; font-weight: 600;">#{article[:title]}</a>
                              </h2>
                              <p style="font-size: 0.85em; color: #718096; margin: 0;">Published: #{date_str}</p>
                            </article>
                          HTML
                        end.join("\n")
                      end

      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Client Portal | GhostLight Research</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f7fafc; color: #2d3748; margin: 0; padding: 60px 20px; }
            .container { max-width: 700px; margin: 0 auto; }
            h1 { font-size: 1.75rem; color: #1a202c; border-bottom: 2px solid #e2e8f0; padding-bottom: 12px; margin-bottom: 40px; }
            .logout-btn { float: right; font-size: 0.85rem; color: #e53e3e; text-decoration: none; border: 1px solid #e53e3e; padding: 6px 12px; border-radius: 4px; font-weight: 500; }
            .logout-btn:hover { background: #fff5f5; }
          </style>
        </head>
        <body>
          <div class="container">
            <a href="/portal/logout" class="logout-btn">Logout</a>
            <h1>GhostLight Research Portal</h1>
            #{error_msg}
            <div class="articles-list">
              #{articles_html}
            </div>
          </div>
        </body>
        </html>
      HTML
    end

    # 3. THE ASCIIDOC COMPILER ROUTE
    # GET /portal/articles/:id
    r.on "portal/articles", String do |article_id|
      r.get do
        begin
          object_id = BSON::ObjectId.from_string(article_id)
          
          article = GhostLight.db[:articles].find(
            _id: object_id,
            client_id: r.env['rack.session'][:client_id]
          ).first

          if article && article[:asciidoc_content]
            response['Content-Type'] = 'text/html; charset=utf-8'
            
            html_output = Asciidoctor.convert(
              article[:asciidoc_content], 
              header_footer: true, 
              safe: :safe
            )
            r.halt html_output
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
      error_message = r.params["error"] == "failed" ? "<p style='color:#e53e3e; font-weight:500; margin-bottom:20px; text-align:center;'>Invalid Client ID or Passphrase.</p>" : ""
      
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Login | GhostLight Research Portal</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f7fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .login-card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.05), 0 1px 3px rgba(0,0,0,0.1); width: 100%; max-width: 360px; }
            h1 { font-size: 1.4rem; margin-top: 0; margin-bottom: 28px; color: #1a202c; text-align: center; font-weight: 700; letter-spacing: -0.02em; }
            label { display: block; margin-bottom: 8px; font-weight: 500; color: #4a5568; font-size: 0.85rem; }
            input { width: 100%; padding: 12px; margin-bottom: 24px; border: 1px solid #cbd5e0; border-radius: 4px; box-sizing: border-box; font-size: 1rem; }
            input:focus { outline: none; border-color: #3182ce; box-shadow: 0 0 0 3px rgba(66,153,225,0.25); }
            button { width: 100%; padding: 12px; background: #3182ce; color: white; border: none; border-radius: 4px; font-size: 1rem; font-weight: 600; cursor: pointer; transition: background 0.15s; }
            button:hover { background: #2b6cb0; }
          </style>
        </head>
        <body>
          <div class="login-card">
            <h1>GHOSTLIGHT RESEARCH</h1>
            #{error_message}
            <form action="/portal/auth" method="POST">
              <label for="client_id">CLIENT ID</label>
              <input type="text" id="client_id" name="client_id" required autofocus />
              
              <label for="password">PASSPHRASE</label>
              <input type="password" id="password" name="password" required />
              
              <button type="submit">Access Portal</button>
            </form>
          </div>
        </body>
        </html>
      HTML
    end

    # 5. SECURE AUTHENTICATION PROCESSING
    # POST /portal/auth
    r.post "portal/auth" do
      client = GhostLight.db[:clients].find(client_id: r.params["client_id"]).first

      if client && client[:password_digest]
        bcrypt_password = BCrypt::Password.new(client[:password_digest])
        
        if bcrypt_password == r.params["password"]
          # Standard Rack automatically captures this mutation and sends cookie response headers!
          r.env['rack.session'][:client_id] = client[:client_id]
          r.redirect "/portal"
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
