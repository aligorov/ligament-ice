# Ligament ICE (STUN & TURN Server)

Выделенный автономный STUN/TURN сервер на базе `coturn` для обеспечения гарантированной связности WebRTC (Ligament Link и SOS удаленная помощь).

Позволяет устанавливать P2P-соединения и автоматически релеить зашифрованный медиа-трафик даже при наличии строгого Symmetric NAT (мобильный интернет, сотовые вышки, строгие корпоративные межсетевые экраны).

---

## 1. Быстрый старт на сервере

```bash
# 1. Склонируйте или скопируйте репозиторий на сервер
cd /opt/ligament-ice   # или ~/ligament-ice

# 2. Создайте файл окружения и укажите пароль
cp .env.example .env
nano .env

# 3. Запустите контейнер
docker compose up -d
```

Проверить статус работы:
```bash
docker compose logs -f
```

---

## 2. Настройка файрвола (Обязательно!)

STUN и TURN используют порт `3478` (UDP/TCP) и диапазон портов для релея медиа (`49152-49250/udp`).

Если у вас включен `ufw` на сервере:
```bash
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 49152:49250/udp
sudo ufw reload
```

Если у вас `iptables`:
```bash
sudo iptables -A INPUT -p udp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 49152:49250 -j ACCEPT
```

*(Если сервер в облаке VK Cloud / Yandex Cloud / Selectel / Hetzner — откройте эти порты в правилах Security Groups).*

---

## 3. Нужен ли Nginx Proxy Manager (NPM)?

**НЕТ, NPM не нужен и не должен проксировать STUN/TURN:**
- NPM работает только с веб-трафиком HTTP/HTTPS (L7) на портах 80 и 443.
- STUN/TURN — это бинарный протокол (L4) на порту 3478.
- Запросы на порт 443 (веб-интерфейс Ligament) по-прежнему идут в NPM.
- Запросы на порт 3478 (WebRTC STUN/TURN) идут напрямую в coturn в обход NPM.

---

## 4. Конфигурация в панели управления Ligament 2FA

Откройте панель администратора Ligament:  
**«Поддержка» (`/admin/support`)** ➔ блок **«STUN/TURN-серверы для WebRTC»**.

Вставьте следующую конфигурацию (замените пароль на значение из `.env`):

```json
[
  {
    "urls": [
      "turn:2fa.grando.app:3478?transport=udp",
      "turn:2fa.grando.app:3478?transport=tcp",
      "stun:2fa.grando.app:3478"
    ],
    "username": "ligament",
    "credential": "TurnSecretPass2026!"
  }
]
```

Нажмите **«Сохранить настройки»**. Настройки применятся мгновенно без перезапуска сервера `twofa`.

---

## 5. Проверка работы

Запустите скрипт проверки:
```bash
./check_ice.sh 2fa.grando.app 3478
```

Или протестируйте в браузере:
1. Откройте [Trickle ICE Test](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/).
2. Удалите стандартный STUN Google.
3. Добавьте:
   - STUN URI: `stun:2fa.grando.app:3478`
   - TURN URI: `turn:2fa.grando.app:3478?transport=udp`, User: `ligament`, Password: `TurnSecretPass2026!`
4. Нажмите **«Gather candidates»**.
5. Вы должны увидеть кандидаты типов:
   - `srflx` (STUN определил внешний IP)
   - `relay` (TURN успешно выделил сокет релея)
