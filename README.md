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

postgre docker
```shell
docker run --name my-postgres -e POSTGRES_PASSWORD=1234 -p 5432:5432 -d postgres
```


Start your Phoenix app with:

    $ mix phx.server
