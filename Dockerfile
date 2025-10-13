# Build stage
FROM ruby:3.4.7-alpine AS builder

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
WORKDIR $APP_ROOT

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    postgresql-dev \
    tzdata \
    curl-dev \
    yaml-dev

ENV RUBY_YJIT_ENABLE=1

# Install gems
COPY Gemfile Gemfile.lock .ruby-version $APP_ROOT/
RUN bundle config --global frozen 1 \
 && bundle config set without 'test' \
 && bundle install --jobs 2

# Copy application code
COPY . $APP_ROOT

# Precompile bootsnap and assets
RUN bundle exec bootsnap precompile --gemfile app/ lib/
RUN SECRET_KEY_BASE=1 RAILS_ENV=production bundle exec rake assets:precompile

# ========================================================
# Final stage
FROM ruby:3.4.7-alpine

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1
WORKDIR $APP_ROOT

# Install runtime dependencies only
RUN apk add --no-cache \
    nodejs \
    postgresql-libs \
    tzdata \
    curl \
    yaml \
    jemalloc

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code
COPY . $APP_ROOT

# Copy precompiled assets and bootsnap cache from builder
COPY --from=builder $APP_ROOT/public/assets $APP_ROOT/public/assets
COPY --from=builder $APP_ROOT/tmp $APP_ROOT/tmp

CMD ["bin/docker-start"]
