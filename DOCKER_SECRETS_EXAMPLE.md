# Пример окружения и Docker Secrets для продакшена

Этот файл показывает, как безопасно передавать чувствительные данные (tokens, passwords) в docker-compose используя Docker Secrets и переменные окружения.

## 1. Создание Docker Secrets

Для продакшена используйте Docker Swarm режим или передавайте secrets через файлы:

```bash
# Пример 1: Docker Swarm mode (для кластеров)
echo "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK" | docker secret create slack_webhook_url -
echo "your-smtp-password" | docker secret create smtp_password -
echo "your-email@example.com" | docker secret create alertmanager_email -

# Пример 2: Локально - используйте .env файл с export
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
export SMTP_PASSWORD="your-smtp-password"
export ALERTMANAGER_EMAIL="your-email@example.com"

# Пример 3: Через .env и docker compose --env-file
# Создайте .secrets.env (НЕ коммитьте в git!)
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
# SMTP_PASSWORD=...
# docker compose --env-file .secrets.env up -d
```

## 2. Alertmanager с Slack и Email

### Slack Configuration

Обновите `alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'slack-team'
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  routes:
    - match:
        severity: critical
      receiver: 'slack-critical'

receivers:
  - name: 'slack-team'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#monitoring'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        send_resolved: true

  - name: 'slack-critical'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#critical-alerts'
        title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        send_resolved: true
    email_configs:
      - to: '${ALERTMANAGER_EMAIL}'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: '${ALERTMANAGER_EMAIL}'
        auth_password: '${SMTP_PASSWORD}'
        require_tls: true
```

## 3. Docker Compose с переменными окружения

Обновите `docker-compose.yml`:

```yaml
services:
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    network_mode: "service:tailscale"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/config.yml
    environment:
      # Передайте переменные из .env или .secrets.env
      - SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
      - ALERTMANAGER_EMAIL=${ALERTMANAGER_EMAIL}
    restart: unless-stopped
```

⚠️ Примечание: для продакшена используйте Docker Swarm secrets или Kubernetes secrets, чтобы переменные не попали в history команд.

## 4. Формат переменных в alertmanager.yml

Alertmanager не поддерживает прямую подстановку `${VARIABLE}` в YAML. Вместо этого:

### Вариант A: Использовать envsubst (рекомендуется)

Создайте скрипт `entrypoint.sh`:

```bash
#!/bin/sh
envsubst < /etc/alertmanager/config.template.yml > /etc/alertmanager/config.yml
exec alertmanager --config.file=/etc/alertmanager/config.yml "$@"
```

Обновите Dockerfile или command в docker-compose:

```yaml
  alertmanager:
    image: prom/alertmanager:latest
    entrypoint: /bin/sh
    command: 
      - -c
      - |
        envsubst < /etc/alertmanager/config.template.yml > /etc/alertmanager/config.yml
        alertmanager --config.file=/etc/alertmanager/config.yml
    volumes:
      - ./alertmanager.config.template.yml:/etc/alertmanager/config.template.yml:ro
    environment:
      - SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
      - ALERTMANAGER_EMAIL=${ALERTMANAGER_EMAIL}
```

### Вариант B: Использовать go-template в Alertmanager

Или напрямую указать secrets как файлы (Docker Swarm):

```yaml
  alertmanager:
    image: prom/alertmanager:latest
    secrets:
      - slack_webhook_url
      - smtp_password
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/config.yml:ro

secrets:
  slack_webhook_url:
    external: true
  smtp_password:
    external: true
```

## 5. Примеры для разных каналов

### Slack
```yaml
slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
    channel: '#alerts'
    title: 'Alert'
    text: '{{ .GroupLabels.alertname }}: {{ .Alerts.Firing | len }} firing'
```

### Telegram (через webhook)
```yaml
webhook_configs:
  - url: 'http://your-telegram-bot:8080/alert'
    send_resolved: true
```

### Microsoft Teams
```yaml
webhook_configs:
  - url: 'https://outlook.webhook.office.com/webhookb2/...'
```

### Email (SMTP)
```yaml
email_configs:
  - to: 'ops@company.com'
    from: 'alertmanager@company.com'
    smarthost: 'smtp.gmail.com:587'
    auth_username: 'alertmanager@gmail.com'
    auth_password: 'app-password'  # Use app-specific password for Gmail
    require_tls: true
```

## 6. Проверка конфигурации

```bash
# Проверить синтаксис alertmanager.yml
docker run --rm -v $(pwd)/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  prom/alertmanager:latest amtool config routes

# Проверить доступность Slack webhook (замените URL)
curl -X POST https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test alert from Alertmanager"}'
```

## 7. Логирование и отладка

Для просмотра логов Alertmanager:
```bash
docker logs alertmanager
```

Для отладки Slack notifications:
- Зайдите в Alertmanager UI: http://monitoring-stack:9093
- Проверьте Alerts tab и посмотрите, активны ли уведомления
- Проверьте Slack channel на наличие сообщений

---

## 8. Лучшие практики

1. **Никогда не коммитьте .env файлы с секретами** — добавьте в `.gitignore`:
   ```
   .env
   .secrets.env
   ```

2. **Используйте разные каналы по severity**:
   - `info`, `warning` → Slack #monitoring
   - `critical` → Slack #critical + Email + PagerDuty

3. **Для продакшена используйте Docker Swarm secrets или Kubernetes secrets** вместо переменных окружения

4. **Регулярно проверяйте webhook URL-ы** — они могут истечь или быть заблокированы

5. **Оставляйте разумные интервалы группировки** — не рассылайте каждый алерт отдельно
