# Гайд: Dashboards и Notifications (Grafana, Loki, Alertmanager)

Этот гайд помогает настроить источники данных, дашборды и уведомления в вашей сборке мониторинга (Prometheus + Grafana + Loki + Alertmanager).

## 1. Что добавлено
- Loki — хранилище логов (порт 3100)
- Promtail — агент, собирающий логи с хоста/контейнера и отправляющий их в Loki
- Alertmanager — маршрутизатор уведомлений
- Автоподключение Grafana к Prometheus и Loki через provisioning
- Примеры alert-правил для Prometheus (`alert_rules.yml`) и шаблон Alertmanager (`alertmanager.yml`)

---

## 2. Быстрый старт: поднять стек
- Клонируйте/обновите репозиторий и запустите docker-compose

```powershell
# В папке с docker-compose.yml
docker compose up -d
```

Grafana по умолчанию: http://monitoring-stack:3000 (MagicDNS/Tailscale), или http://localhost:3000 если вы находитесь в той же сети stack.

По умолчанию Grafana provisioning создаст источники данных Prometheus и Loki, если Grafana запущена после Prometheus/Loki.

---

## 3. Провизионная настройка Grafana
Файлы provisioning лежат в `./grafana/provisioning` и автоматически подключаются в Grafana:
- `./grafana/provisioning/datasources/datasources.yml` — автоматически добавит Prometheus и Loki
- `./grafana/provisioning/dashboards/dashboards.yml` — точка для автоматизированного импорта JSON-дэшбордов из `./grafana/dashboards/`

Примеры подключения:
- Prometheus URL: `http://localhost:9090` (внутри контейнеров может потребоваться изменить на `http://prometheus:9090`)
- Loki URL: `http://localhost:3100`

⚠️ Примечание: если вы измените способ сетевого доступа (измените `network_mode`), возможно, потребуется поправить URL datasource.

---

## 4. Loki & Promtail — настройка логов
- Promtail конфиг находится в `promtail-config.yml`.
- Он собирает логи из `/var/log/*log` и из Docker: `/var/lib/docker/containers/*/*.log`.

Если вы используете Docker Desktop / Windows, пути к логам будут отличаться. В этом случае:
- Можно использовать `docker_sd_configs` и `journald` (Linux), либо
- настроить Promtail на чтение логов из директории, туда где Docker Desktop хранит контейнерные логи.

Пример запроса в Grafana (Loki datasource):
- Развернутый лог: `{job="docker"} |~ "ERROR|WARN"`

---

## 5. Alerts (Prometheus + Alertmanager)
Prometheus настроен, чтобы отправлять оповещения в Alertmanager (`prometheus.yml` -> `alerting`).

### Пример alert rules
Файл `alert_rules.yml` содержит правила:
- InstanceDown — когда target стал недоступен (up == 0, 2m)
- HighCpuUsage — CPU > 90% на протяжении 5 минут

Изучите файл `alert_rules.yml` и скорректируйте пороги под вашу инфраструктуру.

### Alertmanager
Файл `alertmanager.yml` содержит блок receivers и route. По умолчанию — `email_configs` с placeholders.

Для Slack / Microsoft Teams / Telegram / Webhook — добавьте соответствующие конфигурации в `receivers`.

Пример Slack:
```yaml
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX/YYY/ZZZ'
        channel: '#alerts'
```

После изменения `alertmanager.yml` перезапустите сервис
```powershell
docker compose restart alertmanager
```

---

## 6. Как тестировать уведомления
1. Создайте тестовый алерт в `alert_rules.yml` типа всегда-переключающийся (например alert: TestAlert expr: vector(1))
2. Перезагрузите Prometheus (docker compose restart prometheus)
3. В Alertmanager выполните проверку через веб-интерфейс `http://monitoring-stack:9093` или отправьте тестовую нотификацию

---

## 7. Примеры Dashboard'ов
- **Node Exporter** (включен автоматически): диаграммы CPU %, Memory %, Disk I/O, Network Throughput
  - Найдите в Grafana → Dashboards → "Node Exporter - System Metrics"
  - JSON находится в `./grafana/dashboards/node-exporter-system.json`
  - Поддерживает выбор инстанса через переменную `$instance`
  - Метрики: node_cpu_seconds_total, node_memory_MemAvailable_bytes, node_disk_io_time_seconds_total, node_network_transmit_bytes_total
- Nginx/Ingress: latency, upstream 50x, status codes (создайте вручную или импортируйте из Grafana Labs)
- Loki: Log tail panel + query with `{job="docker"}` to filter by container
- Для добавления своих дашбордов: экспортируйте JSON из Grafana и положите в `./grafana/dashboards/`

---

## 8. Docker Secrets и безопасность Alertmanager

Для отправки уведомлений в Slack/Email необходимо передать чувствительные данные (webhook URL, SMTP пароль) безопасно.

### Настройка переменных окружения

1. Откройте `.env.example` и скопируйте в `.env`:
   ```bash
   cp .env.example .env
   ```

2. Отредактируйте `.env` с реальными значениями:
   ```
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
   ALERTMANAGER_EMAIL=your-monitoring@company.com
   SMTP_PASSWORD=your-app-specific-password
   SMTP_SERVER=smtp.example.com
   SMTP_PORT=587
   ```

3. **ВАЖНО**: Добавьте `.env` в `.gitignore` (не коммитьте с реальными секретами):
   ```
   echo ".env" >> .gitignore
   ```

### Запуск с переменными

```powershell
# С файлом .env (docker compose автоматически прочитает .env)
docker compose up -d

# Или с внешним файлом секретов
docker compose --env-file .secrets.env up -d
```

### Поддерживаемые каналы уведомлений

Alertmanager конфиг находится в `alertmanager.config.template.yml`. Примеры разных receivers:

**Slack:**
```yaml
slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK'
    channel: '#alerts'
    title: 'Alert: {{ .GroupLabels.alertname }}'
```

**Email (Gmail/Outlook):**
```yaml
email_configs:
  - to: 'ops@company.com'
    from: 'alertmanager@company.com'
    smarthost: 'smtp.gmail.com:587'
    auth_username: 'alertmanager@gmail.com'
    auth_password: 'app-specific-password'
    require_tls: true
```

**Telegram (через webhook):**
```yaml
webhook_configs:
  - url: 'http://your-telegram-bot:8080/alert'
    send_resolved: true
```

**Microsoft Teams:**
```yaml
webhook_configs:
  - url: 'https://outlook.webhook.office.com/webhookb2/...'
```

Полная документация: см. `DOCKER_SECRETS_EXAMPLE.md`.

---

## 9. Тестирование уведомлений
1. Добавьте временный test-alert в `alert_rules.yml`:
   ```yaml
   - alert: TestAlert
     expr: vector(1)
     for: 0m
     labels:
       severity: critical
   ```

2. Перезагрузите Prometheus:
   ```powershell
   docker compose restart prometheus
   ```

3. Зайдите в Alertmanager UI: http://monitoring-stack:9093
   - Должны появиться "TestAlert" в статусе "FIRING"
   - Проверьте Slack channel или email — должно прийти уведомление

4. Удалите test-alert из конфига и перезагрузитесь

### Отладка

Просмотр логов alertmanager:
```powershell
docker logs alertmanager
```

Проверка webhook URL (для Slack):
```powershell
curl -X POST "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK" `
  -H "Content-Type: application/json" `
  -d '{"text":"Test alert from Alertmanager"}'
```

---

## 10. Что можно улучшить дальше
- Добавить PagerDuty integration для on-call инженеров
- Настроить template для красивого форматирования уведомлений
- Использовать Docker Swarm secrets для продакшена (вместо .env)
- Добавить мониторинг самого Alertmanager (уведомления о недоставленных алертах)
