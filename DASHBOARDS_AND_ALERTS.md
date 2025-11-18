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
- Node/Exporter: диаграммы CPU, Memory, Disk I/O (импортируйте сообщественные дашборды Grafana)
- Nginx/Ingress: latency, upstream 50x, status codes
- Loki: Log tail panel + query with `{job="docker"}` to filter by container

Пояснение к использованию Loki в Dashboards:
- В панели Grafana выберите Loki как datasource и укажите метки:
  - Log labels: `{job="docker", container_name="my-container"}`
- Используйте `| json` для извлечения полей из логов

---

## 8. Советы по безопасности и хранению
- В продакшен храните секреты (email creds, slack webhooks) в `docker secrets` или защищайте `.env`
- Используйте persistent volumes (`prometheus_data`, `grafana_data`) — уже настроено в docker-compose
- Для крупных нагрузок используйте объектное хранилище (S3, GCS) и скалирование Loki

---

## 9. Что можно улучшить дальше
- Автовыполнение дашбордов по шаблонам (создать JSON dash & положить в `./grafana/dashboards`)
- Настроить Alertmanager для нескольких каналов и on-call расписаний
- Добавить роли/персонализации Grafana

---

Если нужно — могу автоматически добавить шаблон Dashboard (JSON) для Node Exporter и Nginx.
