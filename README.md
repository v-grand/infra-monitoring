# Система Мониторинга на базе Prometheus, Grafana и Tailscale

Этот проект представляет собой готовый к развертыванию стек мониторинга, состоящий из Prometheus и Grafana, полностью интегрированный в защищенную сеть [Tailscale](https://tailscale.com/).

## Архитектура

Ключевая особенность этой системы — использование Tailscale в качестве основной сети. Все компоненты (Prometheus, Grafana) подключаются к вашему Tailnet и общаются друг с другом, используя зашифрованные соединения и стабильные MagicDNS имена. Это избавляет от необходимости открывать порты на хост-машине и усложнять конфигурацию сети.

- **`tailscale`**: Служебный контейнер, который подключает весь стек к сети Tailscale.
- **`prometheus`**: Сервис сбора и хранения метрик.
- **`grafana`**: Сервис для визуализации метрик.
 - **`loki`**: Хранилище логов (Loki) для поиска и агрегации логов.
 - **`promtail`**: Агент, который собирает логи из host/containers и пушит их в Loki.
 - **`alertmanager`**: Маршрутизатор для уведомлений (email, Slack, webhook и т.д.).

Подробные технические требования к проекту можно найти в файле [TECHNICAL_REQUIREMENTS.md](TECHNICAL_REQUIREMENTS.md).

## Быстрый старт

### 1. Предварительные требования

- Установленный [Docker](https://docs.docker.com/get-docker/) и [Docker Compose](https://docs.docker.com/compose/install/).
- Аккаунт в [Tailscale](https://login.tailscale.com/login).

### 2. Конфигурация

1.  **Создайте файл `.env`**:
    Скопируйте файл `.env.example` в новый файл с именем `.env`.
    ```bash
    cp .env.example .env
    ```

2.  **Получите ключ авторизации Tailscale**:
    - Перейдите в раздел **Settings -> Auth keys** в вашей [админ-панели Tailscale](https://login.tailscale.com/admin/settings/keys).
    - Нажмите **Generate auth key...**.
    - **Рекомендации**:
        - Сделайте ключ `Ephemeral` (временным), чтобы он автоматически удалялся после выхода контейнера.
        - Добавьте тег, например `tag:monitoring`, для применения политик доступа.
    - Скопируйте сгенерированный ключ (`tskey-auth-...`).

3.  **Добавьте ключ в `.env`**:
    Откройте файл `.env` и вставьте ваш ключ:
    ```
    TS_AUTHKEY=tskey-auth-xxxxxxxxxxxxxxxxxxxx
    ```

4.  **Настройте цели для Prometheus**:
    - Откройте файл `prometheus.yml`.
    - Замените плейсхолдер `your-nginx-gateway-host` на реальное MagicDNS имя или IP-адрес хоста в сети Tailscale, с которого вы хотите собирать метрики.

### 3. Запуск

Выполните команду в корневой директории проекта:

```bash
docker compose up -d
```

### 4. Доступ к сервисам

После успешного запуска в вашей сети Tailscale появится новое устройство с именем `monitoring-stack`. Вы сможете получить доступ к сервисам по следующим адресам с любого устройства в вашем Tailnet:

- **Prometheus**: `http://monitoring-stack:9090`
- **Grafana**: `http://monitoring-stack:3000`
 - **Loki**: `http://monitoring-stack:3100`
 - **Alertmanager**: `http://monitoring-stack:9093`

### 5. Остановка

Для остановки стека выполните команду:

```bash
docker compose down
```

## Дополнительные руководства

- `DASHBOARDS_AND_ALERTS.md` — шаги по подключению источников Grafana (Prometheus, Loki), настройке дашбордов и уведомлений через Alertmanager.
