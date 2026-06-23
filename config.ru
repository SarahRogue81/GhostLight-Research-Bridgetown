# This file is used by Rack-based servers during the Bridgetown boot process.

require "bridgetown-core/rack/boot"
require "rack/session/cookie"
require "securerandom"

Bridgetown::Rack.boot

use Rack::Session::Cookie,
    key: "_ghostlight_research_session",
    secret: ENV.fetch("SESSION_SECRET", SecureRandom.hex(32)),
    path: "/",
    same_site: :lax,
    secure: ENV.fetch("RACK_ENV", "development") == "production"

run RodaApp.freeze.app # see server/roda_app.rb
