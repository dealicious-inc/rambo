# Rambo

**TODO: Add description**

## Installation


```shell
# 의존성 설치
mix deps.get

# 의존성 정보 가져오기
mix hex.search 의존성이름
```

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `rambo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rambo, "~> 0.1.0"}
  ]
end
```

Elixir REPL 환경 안에서 프로젝트 코드를 확인하고 함수 테스트가 가능
```shell
iex -S mix
```

Start your Phoenix app with:

    $ mix phx.server


```shell
# $ mix help --search "phx"
mix local.phx          # Updates the Phoenix project generator locally
mix phx                # Prints Phoenix help information
mix phx.digest         # Digests and compresses static files
mix phx.digest.clean   # Removes old versions of static assets.
mix phx.gen.auth       # Generates authentication logic for a resource
mix phx.gen.cert       # Generates a self-signed certificate for HTTPS testing
mix phx.gen.channel    # Generates a Phoenix channel
mix phx.gen.context    # Generates a context with functions around an Ecto schema
mix phx.gen.embedded   # Generates an embedded Ecto schema file
mix phx.gen.html       # Generates controller, views, and context for an HTML resource
mix phx.gen.json       # Generates controller, views, and context for a JSON resource
mix phx.gen.live       # Generates LiveView, templates, and context for a resource
mix phx.gen.notifier   # Generates a notifier that delivers emails by default
mix phx.gen.presence   # Generates a Presence tracker
mix phx.gen.schema     # Generates an Ecto schema and migration file
mix phx.gen.secret     # Generates a secret
mix phx.gen.socket     # Generates a Phoenix socket handler
mix phx.new            # Creates a new Phoenix application
mix phx.new.ecto       # Creates a new Ecto project within an umbrella project
mix phx.new.web        # Creates a new Phoenix web project within an umbrella project
mix phx.routes         # Prints all routes
mix phx.server         # Starts applications and their servers
```


### mix ecto.*
```shell
# 명령어	설명
mix ecto.create	DB를 생성 (MySQL 연결됨)
mix ecto.drop	DB를 삭제
mix ecto.migrate	priv/repo/migrations/ 폴더의 마이그레이션 파일을 실행
mix ecto.rollback	마이그레이션 되돌리기
mix ecto.gen.migration name	새 마이그레이션 파일 생성 (timestamp_name.exs)
mix ecto.reset	drop → create → migrate 를 한 번에 수행
```