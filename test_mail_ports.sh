#!/bin/bash

MAIL_SERVER="mail.qolimpact.click"
PORTS=(25 587 993)

echo "Testing connectivity to $MAIL_SERVER..."

for PORT in "${PORTS[@]}"; do
  echo -n "Port $PORT: "
  timeout 5 bash -c "</dev/tcp/$MAIL_SERVER/$PORT" 2>/dev/null && echo "OPEN" || echo "CLOSED"
done 