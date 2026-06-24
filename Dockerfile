# --- Stage 1: Build assets and generate static HTML ---
FROM ruby:4.0-slim AS builder

# Install system dependencies, build tools, and Node.js for asset bundling
RUN apt-get update -qq && apt-get install -y build-essential curl git \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs gnupg libssl-dev libyaml-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Force production environment for the build pipeline
ENV BRIDGETOWN_ENV=production
WORKDIR /app

# Copy dependency manifests first to leverage Docker layer caching
COPY Gemfile Gemfile.lock package.json package-lock.json* yarn.lock* ./
RUN gem install bundler && bundle install --jobs 4 --retry 3

# Install frontend node modules
RUN if [ -f yarn.lock ]; then yarn install; else npm install; fi

# Copy the rest of the application codebase
COPY . .

# Compile frontend assets via esbuild and build the static site into /output
RUN bundle exec bridgetown deploy

# --- Stage 2: Run the production Falcon/Rack server ---
FROM ruby:4.0-slim

RUN apt-get update -qq && apt-get install -y libssl-dev libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

ENV BRIDGETOWN_ENV=production
ENV RACK_ENV=production
WORKDIR /app

# Copy installed gems from builder so we don't re-bundle
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy the full application (source + built output)
COPY --from=builder /app /app

EXPOSE 8080

CMD ["bundle", "exec", "falcon", "host", "config/falcon.rb"]
