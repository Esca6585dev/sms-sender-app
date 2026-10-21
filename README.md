# sms_sender_app

Android app for bulk SMS to Turkmen numbers (`+993` + 8 digits). Contacts and
history live on the backend; group sending runs on the device through
`another_telephony`.

## Features

- Message text without a hard limit; live counter with encoding (GSM-7 /
  Unicode) and the number of SMS parts.
- Excel import that splits numbers into groups of 100 (Группа 1: 1–100,
  Группа 2: 101–200, …), with invalid and duplicate numbers reported.
- Per-group send / continue / reset, global "send all" and "stop", live
  counters (sent / remaining / failed) and progress bars.
- Groups survive app restarts (stored in `SharedPreferences`); groups are named
  A, B, C… and can be renamed; several groups can be selected and queued.
- Four switchable design styles (Soft Glass, Bold Brand, Clean Mono, Dark Neon),
  each with light and dark variants, chosen in the drawer.
- Local send history (when, which numbers, result) and statistics.
- SMS cost (1 part = 0.01 TMT by default) and balance read from the operator's
  SMS reply; SIM choice on dual-SIM phones; a foreground service keeps a long
  send alive in the background (notification with "Stop").
- Devices screen for several phones on one backend; the backend endpoints it
  expects are described in `docs/DEVICES_API.md`.

## Structure

```
lib/core        pure Dart: SMS length/parts analysis, phone normalisation, SmsSender
lib/shared      providers and widgets shared by screens
lib/features/groups
  domain        SmsRecipient, SmsGroup, GroupBatcher
  data          ExcelContactsParser, GroupsRepository, SentNumbersSync
  application   GroupsController (Riverpod Notifier), GroupsState, providers
  presentation  GroupsPage, GroupDetailPage, widgets
lib/main.dart   legacy screens (home, history, add contact)
```

Details and the full requirement list (in Turkmen): [docs/TALAPLAR.md](docs/TALAPLAR.md).

## Commands

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
