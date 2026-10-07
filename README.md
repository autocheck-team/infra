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
| API | http://localhost:8080 |
| PostgreSQL | `postgres://autocheck:autocheck@localhost:5432/autocheck` |
| SeaweedFS S3 | http://localhost:8333 (ключ `autocheck` / `autocheck-secret`) |
| SeaweedFS master UI | http://localhost:9333 |

Бэкенд из локального клона (репозитории лежат рядом: `../backend`):

```sh
make up-local
```

Конкретная версия бэкенда: `BACKEND_TAG=sha-<commit> make up`.

Остальное: `make down`, `make logs`, `make ps`, `make reset` (удаляет данные).

Учётные данные в `compose.yaml` и `deploy/seaweedfs/s3.json` только для локальной разработки.
