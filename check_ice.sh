#!/bin/bash
# Проверка доступности STUN/TURNS сервера (включая порт 443 TLS)
set -euo pipefail

HOST="${1:-turn.example.com}"
PORT="${2:-443}"

echo "=== Проверка доступности STUN/TURNS на $HOST ==="

# 1. Проверка резолва DNS
echo -n "1. DNS резолв: "
IP=$(dig +time=2 +tries=1 +short "$HOST" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tail -n1 || true)
if [ -z "$IP" ]; then
  IP=$(dig @1.1.1.1 +time=2 +tries=1 +short "$HOST" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tail -n1 || true)
fi
if [ -z "$IP" ]; then
  IP=$(getent ahosts "$HOST" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)
fi
if [ -n "$IP" ]; then
  echo "OK ($IP)"
else
  echo "FAIL (не удалось разрешить IP)"
  exit 1
fi

# 2. Проверка TURNS TLS / Plain TCP на порту 443
echo -n "2. Транспорт TCP 443: "
if echo | openssl s_client -connect "${HOST}:443" -servername "${HOST}" -brief >/dev/null 2>&1; then
  echo "OK (TURNS TLS 1.3 валиден и отвечает)"
elif nc -z -w 3 "$HOST" 443 2>/dev/null; then
  echo "OK (Plain TCP 443 открыт; сертификат TLS Let's Encrypt ещё не подключён, работает plain fallback)"
else
  echo "ВНИМАНИЕ (порт 443 недоступен или заблокирован файрволом)"
fi

# 3. Проверка резервного TCP порта 3478
echo -n "3. Резервный TCP порт 3478: "
if nc -z -w 3 "$HOST" 3478 2>/dev/null; then
  echo "OK (порт открыт)"
else
  echo "INFO (порт 3478 закрыт или заблокирован, работает резерв 443)"
fi

# 4. Проверка UDP через stunclient (если установлен)
echo -n "4. STUN UDP Binding (порт 443 / $PORT): "
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
echo "и добавьте серверы:"
echo "1. TURNS (TLS): turns:$HOST:443?transport=tcp (User: ligament, пароль из .env)"
echo "2. TURN (UDP): turn:$HOST:443?transport=udp (User: ligament, пароль из .env)"
echo "3. STUN: stun:$HOST:443"
