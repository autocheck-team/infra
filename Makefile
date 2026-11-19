LOCAL := -f compose.yaml -f compose.local.yaml

.PHONY: up up-local down logs ps reset

up:        ## поднять всё на образах из GHCR
	docker compose pull --ignore-pull-failures
	docker compose up -d

up-local:  ## собрать бэкенд из ../backend и поднять
	docker compose $(LOCAL) up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

ps:
	docker compose ps

reset:     ## удалить и данные (БД, файлы)
	docker compose down -v

.PHONY: monitoring-up monitoring-down

monitoring-up: ## включить мониторинг вместе с приложением
	docker compose --profile monitoring up -d

monitoring-down: ## остановить только мониторинг, сохранить приложение и данные
	docker compose --profile monitoring stop alloy grafana prometheus loki monitoring-init
	docker compose --profile monitoring rm -f alloy grafana prometheus loki monitoring-init
