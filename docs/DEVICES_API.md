# Devices API — backend şertnamasy (teklip)

Programma birnäçe telefonda işläp, bir backend-e (`https://atom.com.tm/elitepanel/sms`)
birigip bilýär. Bir telefondan beýleki telefonlaryň ýagdaýyny (balans, şu gün näçe
SMS ugratdy, haçan soňky gezek işledi) görmek üçin backend-de iki endpoint gerek.
Programma olary **best-effort** çagyrýar: endpoint ýok bolsa (404) "Устройства"
ekranynda "сервер пока не поддерживает" diýip görkezýär we başga hiç zady bozmaýar.

Ähli soraglar bar bolan `Integration-Key` header-i bilen gidýär.

## 1. Heartbeat — telefon öz ýagdaýyny iberýär

`POST /devices/heartbeat/`

Programma şulary iberýär: programma açylanda, her rassylka gutaranda we balans
barlananda.

```json
{
  "device_id": "dev-m2k9x1a",
  "name": "samsung SM-A165F",
  "number": "+99365123456",
  "balance": 12.30,
  "sent_today": 450,
  "last_seen": "2026-10-21T11:40:00.000"
}
```

| meýdan | görnüşi | düşündiriş |
|---|---|---|
| `device_id` | string | programmanyň özi döredýän hemişelik ID (SharedPreferences-de saklanýar) |
| `name` | string | telefonyň modeli |
| `number` | string | esasy SIM-iň belgisi (bilinmese boş) |
| `balance` | number, hökmany däl | soňky bilinýän balans, manat |
| `sent_today` | integer | şu gün ugradylan SMS sany |
| `last_seen` | ISO 8601 | iberilen wagty |

Jogap: `200 {"ok": true}` (mazmuny ulanylmaýar). Backend `device_id` boýunça
upsert etmeli.

## 2. Sanaw — ähli telefonlar

`GET /devices/`

```json
[
  {
    "device_id": "dev-m2k9x1a",
    "name": "samsung SM-A165F",
    "number": "+99365123456",
    "balance": 12.30,
    "sent_today": 450,
    "last_seen": "2026-10-21T11:40:00.000"
  }
]
```

`results` açary bilen sahypalanan jogap hem kabul edilýär (`{"results": [...]}`).
Programma öz `device_id`-sini sanawdan aýyrýar we galanlaryny "Другие устройства"
bölüminde görkezýär.

## Programma tarapy

- `lib/features/devices/devices_controller.dart` — `DevicesController`:
  `refreshLocal()` (telefon ady + SIM-ler), `refreshRemote()` (`GET /devices/`),
  `heartbeat()` (`POST /devices/heartbeat/`).
- `lib/features/devices/devices_page.dart` — "Устройства" ekrany (menýudan).
- Balans: `lib/features/balance/balance_controller.dart` — 0800-e SMS iberip,
  gelýän jogapdan balansy okaýar; 1 SMS bölegi = 0,01 TMT (sazlanýar).
