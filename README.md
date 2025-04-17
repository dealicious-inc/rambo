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


```
[유저 A] ─ send msg ─▶ Phoenix
           ↓
     Gnat.pub("chat.to_filter")
           ↓
     [Filter+Logic 컨슈머]
           ├─ 저장
           ├─ 필터링
           └─ Gnat.pub("chat.to_broadcast")
                        ↓
     [Phoenix Gnat.sub] → Endpoint.broadcast!(room:lobby, "new:msg", payload)
```