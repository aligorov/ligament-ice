#!/bin/bash
# Проверка доступности STUN/TURN сервера
set -euo pipefail

HOST="${1:-2fa.grando.app}"
PORT="${2:-3478}"

echo "=== Проверка доступности STUN/TURN на $HOST:$PORT ==="

# 1. Проверка резолва DNS
echo -n "1. DNS резолв: "
IP=$(dig +short "$HOST" | tail -n1 || true)
if [ -z "$IP" ]; then
  IP=$(getent ahosts "$HOST" 2>/dev/null | awk '{print $1}' | head -n1 || true)
fi
if [ -n "$IP" ]; then
  echo "OK ($IP)"
else
  echo "FAIL (не удалось разрешить IP)"
  exit 1
fi

# 2. Проверка TCP порта 3478
echo -n "2. TCP порт $PORT: "
if nc -z -w 3 "$HOST" "$PORT" 2>/dev/null; then
  echo "OK (порт открыт и отвечает)"
else
  echo "ВНИМАНИЕ (TCP недоступен или заблокирован файрволом)"
fi

# 3. Проверка UDP через stunclient (если установлен)
echo -n "3. STUN UDP Binding: "
if command -v stunclient >/dev/null 2>&1; then
  if stunclient "$HOST" "$PORT" >/dev/null 2>&1; then
    echo "OK (STUN Binding успешен)"
  else
    echo "FAIL (UDP пакет не получил ответ)"
  fi
else
  echo "SKIP (установите 'stunclient' для прямого UDP-теста: brew install stun-client / apt install stun-client)"
fi

echo ""
echo "=== Для проверки в браузере откройте ==="
echo "https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/"
echo "и добавьте сервер:"
echo "STUN: stun:$HOST:$PORT"
echo "TURN: turn:$HOST:$PORT (пользователь ligament, пароль из .env)"
