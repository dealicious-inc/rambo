# 1. Build Stage
FROM elixir:1.18.4-alpine AS build

# OS-level dependencies
RUN apk add --no-cache build-base git npm

# Set environment
ENV MIX_ENV=dev

# App directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy dependencies
COPY mix.exs mix.lock ./
COPY config config/
RUN mix deps.get

# Copy source code
COPY lib lib/
COPY assets assets/
COPY priv priv/

# Install JS deps and build assets
RUN npm --prefix assets install
RUN npm --prefix assets run deploy

# No `phx.digest` for dev (optional)
RUN mix compile

# 2. Runtime Stage
FROM elixir:1.18.4-alpine AS dev

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app
COPY --from=build /app /app

# Optional: expose port and set default cmd
EXPOSE 4000
CMD ["mix", "phx.server"]