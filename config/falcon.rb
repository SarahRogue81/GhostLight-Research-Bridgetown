#!/usr/bin/env falcon-host
# frozen_string_literal: true

# This file configures Falcon for production.
# It is ignored in development when using `bin/bt start`.
#
# Use `falcon host` to start Falcon in production.
# `bundle exec falcon host config/falcon.rb`

require "falcon/environment/rack"

service "website" do
  include Falcon::Environment::Rack

  rackup_path \
    File.expand_path("config.ru", Pathname.new(root).join(".."))
  port = ENV["PORT"] || ENV["BRIDGETOWN_PORT"] || "4000"
  port = port.to_i

  endpoint do
    Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
  end
end