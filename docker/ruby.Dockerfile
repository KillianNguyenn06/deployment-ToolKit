# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.5

FROM ruby:${RUBY_VERSION}-slim AS builder

ENV BUNDLE_JOBS=2 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_RETRY=3 \
    BUNDLE_WITHOUT=development:test

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gemfile.lock is optional for the initial pilot but should be committed by real applications.
COPY Gemfile Gemfile.lock* ./
RUN bundle install \
    && rm -rf /usr/local/bundle/cache

FROM ruby:${RUBY_VERSION}-slim

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    PORT=9292 \
    RACK_ENV=production

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --chown=app:app . .

USER app:app

EXPOSE 9292

CMD ["sh", "-c", "exec bundle exec puma -b tcp://0.0.0.0:${PORT:-9292} config.ru"]
