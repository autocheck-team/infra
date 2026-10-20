# infra

[![CI](https://github.com/autocheck-team/infra/actions/workflows/ci.yml/badge.svg)](https://github.com/autocheck-team/infra/actions/workflows/ci.yml)

Локальное окружение и деплой системы автоматической проверки решений, плюс общая
документация по архитектуре.

- **Архитектура:** [docs/architecture.md](docs/architecture.md)
- **Репозитории:** [backend](https://github.com/autocheck-team/backend) · [frontend](https://github.com/autocheck-team/frontend)
- **Задачи:** [GitHub Project](https://github.com/orgs/autocheck-team/projects)

## Запуск всей системы

Нужен только Docker.

```sh
make up        # postgres, seaweedfs, миграции, api, worker на образах из GHCR
curl localhost:8080/readyz
```

| Сервис | Адрес |
|---|---|
| REST API (grpc-gateway) | http://localhost:8080, спецификация: http://localhost:8080/openapi.yaml |
| gRPC API | localhost:9090 (reflection включён: `grpcurl -plaintext localhost:9090 list`) |
| Keycloak | http://localhost:8180, админка: `admin` / `admin` |
| PostgreSQL | `postgres://autocheck:autocheck@localhost:5432/autocheck` |
| SeaweedFS S3 | http://localhost:8333 (ключ `autocheck` / `autocheck-secret`) |
| SeaweedFS master UI | http://localhost:9333 |

## Авторизация (Keycloak)

Realm `autocheck` импортируется из [deploy/keycloak/autocheck-realm.json](deploy/keycloak/autocheck-realm.json)
при первом старте. Если поменяли файл realm, пересоздайте данные Keycloak:
`docker compose rm -sf keycloak && docker volume rm infra_keycloakdata && make up`.

| Клиент | Для чего |
|---|---|
| `autocheck-web` | Фронтенд. Публичный, Authorization Code + PKCE (S256), redirect `http://localhost:5173/*` |
| `autocheck-api` | Бэкенд. Только audience: в access-токенах `aud` содержит `autocheck-api` |
| `autocheck-cli` | Только для разработки: токен по логину и паролю через curl |

Роли: `student` (у всех новых пользователей), `author`, `admin`. Регистрация открыта.

Тестовые пользователи (пароль совпадает с ролью):

| Логин | Пароль | Роли |
|---|---|---|
| student@autocheck.local | student | student |
| author@autocheck.local | author | student, author |
| admin@autocheck.local | admin | student, author, admin |

Токен для curl:

```sh
TOKEN=$(curl -s -d grant_type=password -d client_id=autocheck-cli \
  -d username=author@autocheck.local -d password=author \
  http://localhost:8180/realms/autocheck/protocol/openid-connect/token | jq -r .access_token)
curl -H "Authorization: Bearer $TOKEN" localhost:8080/v1/me
```

Фронтенду: OIDC-конфиг `http://localhost:8180/realms/autocheck/.well-known/openid-configuration`,
client_id `autocheck-web`, для запросов к API передавать access-токен в `Authorization: Bearer`.

## Бэкенд из локального клона

Репозитории лежат рядом, `../backend`:

```sh
make up-local
```

Конкретная версия бэкенда: `BACKEND_TAG=sha-<commit> make up`.

Остальное: `make down`, `make logs`, `make ps`, `make reset` (удаляет данные).

Учётные данные в `compose.yaml` и `deploy/seaweedfs/s3.json` только для локальной разработки.
