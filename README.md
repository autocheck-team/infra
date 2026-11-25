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
make up        # весь стек: инфраструктура, backend из GHCR и frontend
curl localhost:8080/readyz
```

Frontend автоматически собирается из `../frontend`, запускает Vite dev-сервер
с hot reload и доступен на <http://localhost:5173>. Для запуска всего проекта
из локального исходника backend используйте `make up-local`; frontend в обоих
случаях запускается в контейнере.

| Сервис | Адрес |
|---|---|
| Frontend (Vite) | http://localhost:5173 |
| REST API (grpc-gateway) | http://localhost:8080, спецификация: http://localhost:8080/openapi.yaml |
| gRPC API | localhost:9090 (reflection включён: `grpcurl -plaintext localhost:9090 list`) |
| Keycloak | http://localhost:8180, админка: `admin` / `admin` |
| PostgreSQL | `postgres://autocheck:autocheck@localhost:5432/autocheck` |
| SeaweedFS S3 | http://localhost:8333 (ключ `autocheck` / `autocheck-secret`) |
| SeaweedFS master UI | http://localhost:9333 |

Воркер запускает решения в соседних контейнерах, поэтому ему подключён `/var/run/docker.sock`. Запускайте систему только на машине, где это допустимо: доступ к сокету равносилен root на хосте.

## Демо-стенд в Codespaces

Постоянного сервера у проекта нет. Для показа систему можно поднять в GitHub Codespaces: **Code → Codespaces → Create** на этом репозитории, конфигурация лежит в [.devcontainer](.devcontainer/devcontainer.json).

- Открывайте codespace через VS Code или `gh codespace ports forward`, чтобы адреса остались `localhost`: на них настроены issuer Keycloak и presigned-ссылки S3. Через веб-адреса `*.app.github.dev` вход работать не будет.
- Бесплатная квота личного аккаунта: 120 ядро-часов в месяц, это 60 часов на 2 ядрах. У организаций бесплатной квоты нет.
- При простое codespace останавливается, поэтому перед показом его нужно запустить заранее.
- Пароли в `compose.yaml` тестовые. Для реального сервера их нужно заменить.

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

Эта команда также запускает frontend из `../frontend`.

Конкретная версия бэкенда: `BACKEND_TAG=sha-<commit> make up`.

Остальное: `make down`, `make logs`, `make ps`, `make reset` (удаляет данные).

Учётные данные в `compose.yaml` и `deploy/seaweedfs/s3.json` только для локальной разработки.


## Метрики и логи (HPRPR-15)

Профиль `monitoring` выключен по умолчанию. После сборки актуальных api/worker:

```sh
make up-local
make monitoring-up
# либо сразу приложение из ../backend вместе с мониторингом:
docker compose -f compose.yaml -f compose.local.yaml --profile monitoring up -d --build
make monitoring-down # останавливает и удаляет только monitoring-контейнеры
```

| Сервис | Локальный адрес |
| --- | --- |
| Prometheus | http://localhost:9091 |
| Grafana | http://localhost:3000 — admin, пароль `GRAFANA_ADMIN_PASSWORD` из `.env` (локальный дефолт `admin`) |
| Loki API | http://localhost:3100 |

Порты monitoring привязаны к loopback, не конфликтуют с 8080/8180/8333/9090;
их можно изменить через `PROMETHEUS_PORT`, `GRAFANA_PORT`, `LOKI_PORT`.
Пароль Grafana применяется при первой инициализации её volume. Datasource Prometheus
и Loki и dashboard **Autocheck — мониторинг** (`/d/autocheck`) загружаются provisioning.
Панели: очередь и свежесть снимка, вердикты, p50/p95 gRPC и REST по методам,
ошибки, попытки/SE, стадии проверки, активные проверки, уборка sandbox, платежи и 429.
Prometheus опрашивает `api:9100` и `worker:9100` раз в 5 секунд; метрики на хост
не опубликованы. При изменении `METRICS_ADDR` обновите targets в
`deploy/monitoring/prometheus.yaml`.

Alloy читает stdout через Docker API и собирает **только api/worker текущего
Compose-проекта** (`COMPOSE_PROJECT_NAME`, включая `docker compose -p ...`). Контейнеры
песочницы и чужие проекты исключены. JSON-поле `level` становится меткой Loki,
`msg` и `submission_id` остаются в JSON без индексации каждой посылки. Исходные JSON
сохраняются: в Grafana Explore используйте `{service="worker"} | json` или
`{service="worker"} | json | submission_id="UUID"`. Доступ Alloy к Docker socket,
как и у worker, требует доверенного локального окружения; суффикс `:ro` у socket
не ограничивает методы Docker API.

Проверка готовности и данных (пароль передавайте из переменной, не печатайте):

```sh
curl -fsSG localhost:9091/api/v1/query --data-urlencode 'query=up{job=~"api|worker"}'
curl -fsSG localhost:9091/api/v1/query --data-urlencode 'query=autocheck_judge_verdicts_total'
curl -fsS -u "admin:${GRAFANA_ADMIN_PASSWORD:-admin}" localhost:3000/api/dashboards/uid/autocheck
curl -fsSG localhost:3100/loki/api/v1/query_range --data-urlencode 'query={service=~"api|worker"} | json' --data-urlencode 'limit=10'
```

Служебный `monitoring-init` перед запуском Loki назначает владельцем его volume
штатный UID 10001; сам Loki работает без root. Prometheus и Loki хранят данные 7 дней. Данные Prometheus, Grafana, Loki и позиции
Alloy живут в отдельных named volumes. `monitoring-down` сохраняет их и приложение;
`docker compose --profile monitoring down -v` удаляет весь локальный стек с данными.

Для проверки из worktree используйте временный override с абсолютным `build.context`
для migrate/api/worker, собственным Compose project name, другими host-портами и без
публикации PostgreSQL на 5432. Это не требует менять `compose.local.yaml`.
Конфигурация сбора Docker-логов следует
[официальному примеру Alloy](https://grafana.com/docs/alloy/latest/monitor/monitor-docker-containers/).
