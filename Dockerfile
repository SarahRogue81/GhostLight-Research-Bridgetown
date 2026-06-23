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

# --- Stage 2: Serve the production-ready site ---
FROM nginx:alpine
# Copy the compiled static folder from the builder stage straight to Nginx
COPY --from=builder /app/output /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
