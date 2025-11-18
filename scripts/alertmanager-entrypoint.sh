#!/bin/bash
# Скрипт для подстановки переменных окружения в alertmanager.yml
# Используется в docker-compose для замены плейсхолдеров

set -e

# Проверить, что переменные установлены
if [ -z "$SLACK_WEBHOOK_URL" ]; then
  echo "WARNING: SLACK_WEBHOOK_URL не установлен. Используется плейсхолдер."
  SLACK_WEBHOOK_URL="SLACK_WEBHOOK_URL_PLACEHOLDER"
fi

if [ -z "$ALERTMANAGER_EMAIL" ]; then
  echo "WARNING: ALERTMANAGER_EMAIL не установлен. Используется плейсхолдер."
  ALERTMANAGER_EMAIL="EMAIL_PLACEHOLDER"
fi

if [ -z "$SMTP_PASSWORD" ]; then
  echo "WARNING: SMTP_PASSWORD не установлен. Используется плейсхолдер."
  SMTP_PASSWORD="SMTP_PASSWORD_PLACEHOLDER"
fi

if [ -z "$SMTP_SERVER" ]; then
  SMTP_SERVER="smtp.example.com"
fi

if [ -z "$SMTP_PORT" ]; then
  SMTP_PORT="587"
fi

# Выполнить подстановку переменных
cat /etc/alertmanager/config.template.yml | \
  sed "s|SLACK_WEBHOOK_URL_PLACEHOLDER|$SLACK_WEBHOOK_URL|g" | \
  sed "s|EMAIL_PLACEHOLDER|$ALERTMANAGER_EMAIL|g" | \
  sed "s|SMTP_PASSWORD_PLACEHOLDER|$SMTP_PASSWORD|g" | \
  sed "s|SMTP_SERVER_PLACEHOLDER|$SMTP_SERVER|g" | \
  sed "s|SMTP_PORT_PLACEHOLDER|$SMTP_PORT|g" > /etc/alertmanager/config.yml

# Вывести обработанный конфиг в логи для отладки (без пароля)
echo "Alertmanager configuration loaded (secrets masked):"
cat /etc/alertmanager/config.yml | sed "s/$SMTP_PASSWORD/***REDACTED***/g"

# Запустить alertmanager
exec alertmanager --config.file=/etc/alertmanager/config.yml "$@"
