# Rambo

![img.png](img.png)

mysql

## 테이블생성
```angular2html
mix ecto.gen.migration #{테이블명}
ex) mix ecto.gen.migration create_chat_rooms
 -> 생성위치 rambo/priv/repo/migrations
```

## 마이그레이션 실행 명령어
```angular2html
mix ecto.migrate
```

## mix.exs 의존성추가 

## 의존성 다운받기
```
mix deps.get
```

