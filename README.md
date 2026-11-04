# Ligament ICE (STUN, TURN & TURNS TLS Server)

Выделенный автономный STUN/TURN/TURNS сервер на базе `coturn` и `certbot` для обеспечения гарантированной связности WebRTC (Ligament Chat, видеозвонки и SOS удаленная помощь).

### Главные преимущества:
* **Обход любых блокировок (TURNS на порту 443 TCP с TLS)**: трафик шифруется и неотличим от обычного HTTPS, что снижает вероятность блокировки сетевыми фильтрами до < 2%.
* **Полная автоматизация ACME**: встроенный сервис `certbot` сам выпускает сертификаты Let's Encrypt и продлевает их в фоне каждые 12 часов.
* **Высокая скорость (UDP 443)**: минимальные задержки звука и видео.
* **Обратная совместимость (3478)**: сохранение резервного порта для старых клиентов.

---

## 1. Быстрый старт на сервере

```bash
# 1. Склонируйте или скопируйте репозиторий на сервер
cd /opt/ligament-ice   # или ~/ligament-ice

# 2. Создайте файл окружения и укажите домен, email и пароль
cp .env.example .env
nano .env

# 3. Запустите контейнеры
docker compose up -d
```

Проверить статус работы:
```bash
docker compose logs -f
```
*При первом запуске Certbot автоматически свяжется с Let's Encrypt, выпустит сертификат, после чего Coturn запустится с поддержкой TLS.*

---

## 2. Настройка файрвола (Обязательно!)

На сервере должны быть открыты порты:
* `80/tcp` — для автоматической валидации сертификатов Let's Encrypt (ACME).
* `443/tcp` и `443/udp` — основной зашифрованный TURNS (TLS) и быстрый TURN (UDP).
* `3478/tcp` и `3478/udp` — резервный стандартный порт.
* `49152-49250/udp` — диапазон портов для релея медиапотока WebRTC.

Если у вас включен `ufw` на сервере:
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 49152:49250/udp
sudo ufw reload
```

Если у вас `iptables`:
```bash
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 49152:49250 -j ACCEPT
```

---

## 3. Конфигурация в панели управления Ligament 2FA

Откройте панель администратора Ligament:  
**«Поддержка» (`/admin/support`)** ➔ блок **«STUN/TURN-серверы для WebRTC»**.

Вставьте следующую конфигурацию (замените `remote.grando.app` и пароль на значения из `.env`):

```json
[
  {
    "urls": [
      "turn:remote.grando.app:443?transport=udp",
      "turns:remote.grando.app:443?transport=tcp",
      "stun:remote.grando.app:443",
      "turn:remote.grando.app:3478?transport=udp",
      "turn:remote.grando.app:3478?transport=tcp",
      "stun:remote.grando.app:3478"
    ],
    "username": "ligament",
    "credential": "TurnSecretPass2026!"
  }
]
```

Нажмите **«Сохранить настройки»**. Настройки применятся мгновенно без перезапуска сервера `twofa`.

---

## 4. Проверка работы

Запустите скрипт проверки:
```bash
./check_ice.sh remote.grando.app
```

Или протестируйте в браузере:
1. Откройте [Trickle ICE Test](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/).
2. Добавьте:
   * **TURNS (TLS):** `turns:remote.grando.app:443?transport=tcp` (User: `ligament`, Password: `...`)
   * **TURN (UDP):** `turn:remote.grando.app:443?transport=udp` (User: `ligament`, Password: `...`)
   * **STUN:** `stun:remote.grando.app:443`
3. Нажмите **Gather candidates**. Вы должны увидеть кандидаты с типом `relay` и `srflx`.
