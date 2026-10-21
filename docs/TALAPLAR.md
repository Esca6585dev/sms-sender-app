# SMS Sender — toparlaýyn ugratma (tehniki talap we arhitektura)

Bu resminama rus dilindäki asyl talabyň türkmençe gysgaldylan we takyklaşdyrylan
görnüşi hem-de taslamada durmuşa geçirilen çözgüdiň beýanydyr.

## 1. Takyklaşdyrylan talap (prompt)

Sen Senior Flutter Developer. `sms_sender_app` taslamasyny aşakdaky talaplara görä
gaýtadan gur. Kod arassa (Clean Architecture), UI bilen biznes-logika aýry,
state management — Riverpod, ähli logika testler bilen örtülen bolmaly.

1. **Tekst çägi.** Habar meýdançasyndaky 160 simwol çägini aýyr. Simwollary we
   SMS bölekleriniň sanyny hakyky wagtda hasapla (GSM-7: 160/153, Unicode: 70/67).
   Uzyn habar köp bölekli (multipart) SMS hökmünde ugradylsyn.
2. **Excel → toparlar.** Excel-den import edilen belgileri awtomatiki 100-den
   toparlara böl: Topar 1 (1–100), Topar 2 (101–200) we ş.m. Nädogry we
   gaýtalanýan belgiler aýrylsyn, netije ulanyja görkezilsin.
3. **Toparlar UI.** Toparlaryň sanawy (`ListView.builder`), her toparda: ady,
   aralyk, status, progress, belgileriň deslapky görnüşi, "Ugrat" we "Sbros"
   düwmeleri, doly sanawa geçmek. Umumy panel: jemi sanlar, "Hemmesini ugrat",
   "Stop", gijikdirme saýlawy.
4. **Status we sanaçlar.** Her topar üçin ugradylan / galan / ýalňyş sanlary
   hakyky wagtda täzelensin. Statuslar: Garaşýar, Gidip dur, Säginen,
   Ýalňyşly, Ugradyldy. Progress-bar her toparda we umumy panelde.
5. **Sbros.** Bir toparyň ýa-da ähli toparlaryň statusyny sbros etmek, topary
   pozmak, ähli toparlary pozmak (tassyklama bilen).
6. **Masştab.** Excel parsing aýratyn izolýatda (`compute`), toparlar
   `SharedPreferences`-de saklanýar (programma ýapylsa-da galýar), ugratma
   logikasy UI-den aýry we test edilýär.

## 2. Arhitektura

```
lib/
├── main.dart                         # ProviderScope + HomePage/History/AddContact (öňki ekranlar)
├── core/
│   ├── sms/sms_message_info.dart     # GSM-7 / UCS-2 analiz, SMS bölek sany
│   ├── sms/sms_sender.dart           # SmsSender interfeýsi + TelephonySmsSender
│   └── utils/phone_normalizer.dart   # +993XXXXXXXX normalizasiýa
├── shared/
│   ├── providers/app_providers.dart  # apiServiceProvider, messageControllerProvider
│   └── widgets/message_composer.dart # çäksiz tekst meýdançasy + sanaç
└── features/groups/
    ├── domain/                       # SmsRecipient, SmsGroup, GroupCounters, GroupBatcher
    ├── data/                         # ExcelContactsParser, GroupsRepository, SentNumbersSync
    ├── application/                  # GroupsState, GroupsController (Riverpod Notifier), providers
    └── presentation/                 # GroupsPage, GroupDetailPage, GroupActions, widgets/
```

Akym: `Excel bytes → ExcelContactsParser (izolýat) → GroupBatcher (100-den) →
GroupsController.state → GroupsRepository (JSON, SharedPreferences)`.

Ugratma: `GroupsController._send → SmsSender.send (her belgi üçin) → recipient
status (sending → sent/failed) → sanaçlar täzelenýär → debounce bilen saklanýar`.
Ugradylan belgi backend-e hem `markNumberAsSent` bilen bellenýär (best-effort).

## 3. Esasy klaslar

| Klas | Wezipe |
|---|---|
| `SmsMessageInfo.analyze(text)` | encoding, uzynlyk, `parts`, `capacity`, `isMultipart` |
| `PhoneNormalizer.normalize(raw)` | `+993 65..`, `865..`, `0099365..`, `65..` → `+99365123456`, nädogry → `null` |
| `ExcelContactsParser.parseBytes(bytes)` | C/D sütünler, ýogsa awtomatik gözleg; senäni telefon diýip almaýar |
| `GroupBatcher(batchSize: 100).split(list)` | `SmsGroup` sanawy, nomerlemäni dowam etdirip bilýär |
| `GroupsController` | `importFromBytes`, `sendGroup`, `sendAllPending`, `stop`, `resetGroup`, `resetAll`, `removeGroup`, `clearAll` |
| `GroupsState` | `groups`, `activeGroupId`, `isSending`, `totals`, `pendingGroupsCount`, `errorMessage` |

## 4. Ulanyş

1. Baş ekranda **Группы** düwmesi → "Группы рассылки" ekrany.
2. Ýokarky **Импорт из Excel** → `.xlsx` saýla → toparlar awtomatiki döreýär.
3. Habar tekstini ýaz (baş ekran bilen umumy), topardaky **Отправить** ýa-da
   **Отправить все** bas, tassykla.
4. Progress we sanaçlar hakyky wagtda täzelenýär, **Стоп** bilen säkdirip bolýar.
5. **Сброс** — topar statusyny arassalaýar; ⋮ menýu — "Сбросить все" / "Удалить все".

## 4a. Täze dizaýn, istoriýa we statistika (2026-10-21)

- **Shell** (`lib/app/app_shell.dart`): burger menýu (`AppDrawer`) + aşaky
  `NavigationBar` bilen 4 bölüm: Рассылка, Группы, История, Статистика.
  Her sahypanyň öz AppBar-y bar, `ShellMenuButton` çep tarapda menýuny açýar.
- **Tema** (`lib/app/theme.dart`, `theme_mode_controller.dart`): Material 3,
  light/dark/awto; saýlaw `SharedPreferences`-de saklanýar, menýudan üýtgedilýär.
- **Рассылка** (`lib/features/send/send_page.dart`): habar meýdançasy, iki stat
  kartoçkasy (jemi / ugradylan), gözleg, belgiler sanawy, "Отправить всем" FAB,
  goşmaça hereketler ⋮ menýuda. Öňki `AddContactPage` → `lib/features/contacts/`,
  öňki serwer istoriýasy → `ServerMessagesPage` (menýuda "Тексты на сервере").
- **История** (`lib/features/history/`): her ugratma (topar / hemmesi / bir belgi)
  ýerli ýazylýar: wagty, dowamlylygy, tekst, belgiler we her biriniň netijesi.
  `CampaignLogController` + `SharedPrefsCampaignRepository` (indeks + her
  kampaniýa aýratyn açar). Günler boýunça toparlanan sanaw, jikme-jik sahypa.
- **Статистика** (`lib/features/stats/stats_page.dart`): şu gün / 7 gün / jemi /
  ýalňyş / kampaniýa sany / toparlardaky belgiler, 7 günlük diagramma, çeşmeler
  boýunça bölünişik, soňky ugratmalar. Hasaplama `CampaignStats.from()` (arassa Dart).

## 4b. Dizaýn saýlawy, nobat, balans, arka plan (2026-10-21, 2-nji tapgyr)

- **4 dizaýn stili** (`lib/app/theme.dart`, `theme_palettes.dart`): Soft Glass,
  Bold Brand, Clean Mono, Dark Neon — her biri light/dark. Menýuda "Дизайн" we
  "Тема оформления" saýlawy, `ThemeSettingsController` ýatda saklaýar. Şriftler
  `assets/fonts` (Manrope, Montserrat, Inter, Onest, Exo 2 — kirillisa bar).
  Aşaky nawigasiýa stile görä çekilýär (`app_bottom_bar.dart`).
- **Toparlar:** adlar harp bilen (Группа A, B … Z, AA), ⋮ → "Переименовать".
  Kartoçkada "Показать номера (100)" — belgiler göni açylýar. Uzyn basmak →
  saýlama režimi, ýokarda "Отправить выбранные". **Nobat:** ugratma gidip
  durka goşulan toparlar nobata düşýär (`GroupsState.queue`), panelde çipler,
  "Убрать из очереди", "Стоп" nobaty hem arassalaýar. "Повторить (N)" diňe
  ugradylmadyklara gidýär.
- **Baha we balans** (`lib/features/balance/balance_controller.dart`): 1 SMS
  bölegi = 0,01 TMT (sazlanýar); her toparda "≈ 1,00 TMT", tassyklamada jemi
  çykdajy we balans; balans 0800-e SMS iberip gelýän jogapdan okalýar
  (`parseBalance`), elde girizip hem bolýar; her ugradylan SMS-den soň azalýar.
  Köp SIM: "Устройства" ekranynda saýlanýar (`subscriptionId`).
- **Arka plan:** `SendingService.kt` foreground service + bildiriş ("Стоп"
  düwmesi bilen), ekran öçmeýär; `MainActivity.kt` MethodChannel
  (`elite_sms/device`): SIM sanawy, serwis, keep-screen-on.
- **Устройства** (`lib/features/devices/`): şu telefon, SIM, balans, baha;
  beýleki telefonlar backend `GET /devices/` + `POST /devices/heartbeat/`
  arkaly — şertnama `docs/DEVICES_API.md`-de (backend tarapynda ýazylmaly).

## 5. Testler

```
flutter test
```

- `test/core/sms_message_info_test.dart` — bölek sany, GSM/Unicode çäkleri
- `test/core/phone_normalizer_test.dart` — belgi formatlary
- `test/features/groups/group_batcher_test.dart` — 1000 → 10×100, galyndy
- `test/features/groups/excel_contacts_parser_test.dart` — hakyky xlsx bilen
- `test/features/groups/groups_controller_test.dart` — import, ugratma, stop, ýalňyş, sbros
- `test/features/history/campaign_stats_test.dart` — statistika hasaplamalary, JSON
- `test/features/history/campaign_log_controller_test.dart` — istoriýa ýazgysy, topar ugratmasynyň ýazylmagy
- `test/widget_test.dart` — GroupsPage widget testleri
