import 'package:sms_sender_app/l10n/strings.dart';

/// Turkmen (Latin) strings.
class StringsTk extends S {
  const StringsTk();

  @override
  String get appSubtitle => 'Müşderilere SMS ugratma';
  @override
  String get ok => 'Bolýar';
  @override
  String get cancel => 'Ýatyr';
  @override
  String get save => 'Ýatda sakla';
  @override
  String get delete => 'Poz';
  @override
  String get deleteAll => 'Hemmesini poz';
  @override
  String get reset => 'Sbros';
  @override
  String get stop => 'Sakla';
  @override
  String get stopping => 'Saklanýar…';
  @override
  String get send => 'Ugrat';
  @override
  String get sending => 'Ugradylýar…';
  @override
  String get retry => 'Gaýtala';
  @override
  String get refresh => 'Täzele';
  @override
  String get more => 'Başga';
  @override
  String get menu => 'Menýu';
  @override
  String get yes => 'Hawa';
  @override
  String get understood => 'Düşnükli';
  @override
  String get manual => 'Elde';
  @override
  String get byDefault => 'Adaty';
  @override
  String get today => 'Şu gün';
  @override
  String get yesterday => 'Düýn';
  @override
  List<String> get weekdaysShort =>
      const ['Du', 'Si', 'Ça', 'Pe', 'An', 'Şe', 'Ýe'];
  @override
  String minutesSeconds(int minutes, int seconds) =>
      minutes == 0 ? '$seconds sek' : '$minutes min $seconds sek';
  @override
  String numbersCount(int n) => '$n belgi';
  @override
  String smsCount(int n) => '$n SMS';

  @override
  String get tabSend => 'Ugratma';
  @override
  String get tabGroups => 'Toparlar';
  @override
  String get tabHistory => 'Taryh';
  @override
  String get tabStats => 'Statistika';
  @override
  String get drawerAddNumber => 'Belgi goşmak';
  @override
  String get drawerAddNumberHint => 'Elde, kontaktlardan ýa-da Excel-den';
  @override
  String get drawerDevices => 'Enjamlar we balans';
  @override
  String get drawerDevicesHint => 'SIM, balans, SMS bahasy, beýleki telefonlar';
  @override
  String get drawerServerTexts => 'Serwerdäki tekstler';
  @override
  String get drawerServerTextsHint => 'Ýatda saklanan habar tekstleri';
  @override
  String get drawerDesign => 'Dizaýn';
  @override
  String get drawerTheme => 'Tema';
  @override
  String get drawerLanguage => 'Dil';
  @override
  String get themeAuto => 'Awto';
  @override
  String get themeLight => 'Açyk';
  @override
  String get themeDark => 'Garaňky';
  @override
  String get versionLine => 'elite-elektronika · SMS ugratma · v1.0.0';

  @override
  String get styleSoftGlass => 'Ýumşak fon, aýna kartoçkalar';
  @override
  String get styleBoldBrand => 'Goýy gök ýokary, gyzyl düwme';
  @override
  String get styleCleanMono => 'Ak-gara minimalizm, inçe çyzyklar';
  @override
  String get styleDarkNeon => 'Garaňky fon, neon aksent';

  @override
  String get messageText => 'Habaryň teksti';
  @override
  String get messageHint => 'Müşderilere habar ýazyň…';
  @override
  String get enterMessage => 'Habaryň tekstini ýazyň';
  @override
  String tooltipMultipart(int parts) =>
      'Uzyn habar: $parts bölek bolup ugradylar';
  @override
  String tooltipSingle(int limit, String encoding) =>
      'Bir SMS, iň köp $limit simwol ($encoding)';
  @override
  String partsSuffix(int parts) => ' (her biri $parts bölek)';

  @override
  String get statusPending => 'Garaşýar';
  @override
  String get statusInProgress => 'Gidip dur';
  @override
  String get statusPaused => 'Säginen';
  @override
  String get statusPartial => 'Ýalňyşly';
  @override
  String get statusSent => 'Ugradyldy';

  @override
  String get groupsTitle => 'Ugratma toparlary';
  @override
  String groupDefaultName(String letter) => 'Topar $letter';
  @override
  String rangeLabel(int from, int to) => '№ $from–$to';
  @override
  String get importExcel => 'Excel-den import';
  @override
  String get importing => 'Excel import edilýär…';
  @override
  String get groupsEmptyTitle => 'Entek topar ýok';
  @override
  String get groupsEmptyHint =>
      'Belgili Excel faýly import ediň: olar awtomatiki 100-den toparlara bölüner.';
  @override
  String get groupsExist => 'Toparlar eýýäm bar';
  @override
  String get importAppend => 'Barlaryna goşmak';
  @override
  String get importAppendHint => 'Täze toparlar nomerlemäni dowam etdirer';
  @override
  String get importReplace => 'Çalyşmak';
  @override
  String get importReplaceHint => 'Häzirki toparlar pozular';
  @override
  String get fileReadError => 'Faýly okap bolmady';
  @override
  String importError(Object error) => 'Import ýalňyşy: $error';
  @override
  String importNothing(int rows) =>
      'Faýlda dogry belgi tapylmady (setir: $rows)';
  @override
  String importResult(int imported, int groups) =>
      'Import edildi: $imported belgi → topar: $groups';
  @override
  String importInvalid(int n) => ' · nädogry geçirildi: $n';
  @override
  String importDuplicates(int n) => ' · gaýtalanýan: $n';
  @override
  String get resetAllStatuses => 'Ähli toparlaryň statusyny sbros et';
  @override
  String get deleteAllGroups => 'Ähli toparlary poz';
  @override
  String get openList => 'Sanawy aç';
  @override
  String get rename => 'Adyny üýtget';
  @override
  String get removeFromQueue => 'Nobatdan aýyr';
  @override
  String get deleteGroup => 'Topary poz';
  @override
  String get showNumbers => 'Belgileri görkez';
  @override
  String get hideNumbers => 'Belgileri gizle';
  @override
  String get continueSending => 'Dowam et';
  @override
  String get retryFailed => 'Gaýtala';
  @override
  String inQueue(int position) => 'Nobatda #$position';
  @override
  String get sentLabel => 'Ugradyldy';
  @override
  String get remainingLabel => 'Galdy';
  @override
  String get failedLabel => 'Ýalňyş';
  @override
  String get runningLabel => 'Gidýär';
  @override
  String sentOf(int sent, int total) => 'Ugradyldy $sent / $total';
  @override
  String more_(int n) => '… ýene $n';
  @override
  String get groupsCount => 'Topar';
  @override
  String get numbersLabel => 'Belgi';
  @override
  String sendingGroup(String title, int sent, int total) =>
      'Ugradylýar: $title · $sent / $total';
  @override
  String get queueLabel => 'Nobat:';
  @override
  String get balanceUnknown => 'Balans belli däl';
  @override
  String balanceLine(String amount) => 'Balans $amount';
  @override
  String get check => 'Barla';
  @override
  String get waiting => 'Garaşýarys…';
  @override
  String get delayLabel => 'Gijikdirme:';
  @override
  String get delayNone => 'Gijikdirmesiz';
  @override
  String delaySeconds(String seconds) => '$seconds sek';
  @override
  String sendAll(int groups) => 'Hemmesini ugrat ($groups)';
  @override
  String queueAll(int groups) => 'Hemmesini nobata ($groups)';
  @override
  String selected(int n) => 'Saýlanan: $n';
  @override
  String get clearSelection => 'Saýlawy aýyr';
  @override
  String get selectAll => 'Hemmesini saýla';
  @override
  String get sendSelected => 'Saýlananlary ugrat';
  @override
  String pausedUntil(String time) => 'SMS limiti · $time-da dowam ederis';
  @override
  String get continueNow => 'Häzir dowam et';
  @override
  String get sortLabel => 'Tertip';
  @override
  String get sortServer => 'Serwerdäki ýaly';
  @override
  String get sortByName => 'Ady boýunça';
  @override
  String get sortByPhone => 'Belgisi boýunça';
  @override
  String get sortUnsentFirst => 'Ilki ugradylmadyklar';

  @override
  String sendGroupTitle(String title) => '$title ugradylsynmy?';
  @override
  String queueGroupTitle(String title) => '$title nobata goşulsynmy?';
  @override
  String willSend(int n) => '$n SMS ugradylar';
  @override
  String get toQueue => 'Nobata';
  @override
  String groupAlreadyQueued(String title) =>
      '$title eýýäm nobatda ýa-da ugradylýar';
  @override
  String groupQueued(String title) => '$title nobata goşuldy';
  @override
  String groupSentReport(String title, int sent, int total) =>
      '$title: $total-den $sent ugradyldy';
  @override
  String get sendAllTitle => 'Ähli toparlar ugradylsynmy?';
  @override
  String get queueAllTitle => 'Ähli toparlar nobata goýulsynmy?';
  @override
  String groupsAndSms(int groups, int sms) => 'Topar: $groups, SMS: $sms';
  @override
  String get sendAllConfirm => 'Hemmesini ugrat';
  @override
  String get nothingToSend => 'Ugratmaga zat ýok';
  @override
  String get groupsQueued => 'Toparlar nobata goşuldy';
  @override
  String doneReport(int sent, int total) => 'Taýýar: $total-den $sent ugradyldy';
  @override
  String get selectedNothing => 'Saýlanan toparlarda ugratmaga zat ýok';
  @override
  String sendSelectedTitle(int n) => 'Saýlananlar ($n) ugradylsynmy?';
  @override
  String smsLine(int n) => 'SMS: $n';
  @override
  String get alreadyQueued => 'Toparlar eýýäm nobatda';
  @override
  String removedFromQueue(String title) => '$title nobatdan aýryldy';
  @override
  String renameTitle(String defaultTitle) => 'Ady · $defaultTitle';
  @override
  String resetGroupTitle(String title) => '$title sbros edilsinmi?';
  @override
  String get resetGroupBody => 'Ugratma statuslary arassalanar, belgiler galar.';
  @override
  String groupResetDone(String title) => '$title sbros edildi';
  @override
  String get resetAllTitle => 'Ähli toparlar sbros edilsinmi?';
  @override
  String get resetAllBody =>
      'Ähli toparlaryň ugratma statuslary arassalanar, belgiler galar.';
  @override
  String get resetAllDone => 'Ähli toparlaryň statuslary sbros edildi';
  @override
  String deleteGroupTitle(String title) => '$title pozulsynmy?';
  @override
  String deleteGroupBody(int n) => 'Toparyň belgileri ($n) sanawdan pozular.';
  @override
  String groupDeleted(String title) => '$title pozuldy';
  @override
  String get deleteAllGroupsTitle => 'Ähli toparlar pozulsynmy?';
  @override
  String get deleteAllGroupsBody =>
      'Ähli toparlar we belgiler pozular. Yzyna gaýtaryp bolmaýar.';
  @override
  String get allGroupsDeleted => 'Ähli toparlar pozuldy';
  @override
  String costLine(String cost) => '\nBahasy ≈ $cost';
  @override
  String balanceSuffix(String balance) => ' · balans $balance';
  @override
  String get balanceMayBeShort => '\nBalans ýetmän biler!';
  @override
  String get sendStopped => 'Ugratma saklandy';
  @override
  String limitError(String details) =>
      'SMS ugratma limitine ýetildi ýa-da operator wagtlaýyn gadagan etdi.\n\nSoňrak synanyşyň.\n\n$details';
  @override
  String get noSendConfirmation => 'Ugratma tassyklanmady (wagt doldy)';
  @override
  String get notSent => 'Ugradylmady';
  @override
  String get groupDeletedTitle => 'Topar';
  @override
  String get groupDeletedBody => 'Topar pozuldy';
  @override
  String get resetStatuses => 'Statuslary sbros et';
  @override
  String continueSendingN(int n) => 'Ugratmany dowam et ($n)';
  @override
  String sendGroupN(int n) => 'Topary ugrat ($n)';

  @override
  String get sendTitle => 'Ugratma';
  @override
  String get searchHint => 'Belgi ýa-da at gözle';
  @override
  String get refreshList => 'Sanawy täzele';
  @override
  String get syncFromServer => 'Serwerden ýükle';
  @override
  String get syncing => 'Belgiler serwerden ýüklenýär…';
  @override
  String syncResult(int numbers, int groups) =>
      '$numbers belgi ýüklendi → topar: $groups';
  @override
  String get syncError => 'Belgileri serwerden ýükläp bolmady';
  @override
  String get clearSent => 'Ugradylanlary sbros et';
  @override
  String get deleteAllNumbers => 'Ähli belgileri poz';
  @override
  String get totalNumbers => 'Jemi belgi';
  @override
  String remainingN(int n) => 'galdy $n';
  @override
  String get sendToAll => 'Hemmesine ugrat';
  @override
  String get noNumbersTitle => 'Entek belgi ýok';
  @override
  String get noNumbersHint =>
      'Belgileri elde, kontaktlardan goşuň ýa-da Excel import ediň.';
  @override
  String get sendToThisNumber => 'Şu belgä ugrat';
  @override
  String get deleteNumber => 'Belgini poz';
  @override
  String get alreadySentToNumber => 'Bu belgä SMS eýýäm ugradylan';
  @override
  String get sendingSms => 'SMS ugradylýar…';
  @override
  String sentTo(String phone) => 'Ugradyldy: $phone';
  @override
  String failedTo(String phone) => 'Ugradyp bolmady: $phone';
  @override
  String get deletingNumber => 'Belgi pozulýar…';
  @override
  String deleted(String phone) => 'Pozuldy: $phone';
  @override
  String get clearSentTitle => 'Ugradylanlar sbros edilsinmi?';
  @override
  String get clearSentBody => 'Ähli belgiler ugradylmadyk diýlip bellener';
  @override
  String get clearingSent => 'Bellikler sbros edilýär…';
  @override
  String get clearSentDone => 'Ugradylanlaryň sanawy arassalandy';
  @override
  String deleteError(Object e) => 'Pozmak ýalňyşy: $e';
  @override
  String get clearListTitle => 'Ähli belgiler pozulsynmy?';
  @override
  String get clearListBody => 'Ähli belgiler pozular';
  @override
  String get deleting => 'Pozulýar…';
  @override
  String get preparing => 'Taýýarlanýar…';
  @override
  String get deletingContacts => 'Kontaktlar pozulýar…';
  @override
  String get refreshingData => 'Maglumat täzelenýär…';
  @override
  String get done => 'Taýýar';
  @override
  String get allNumbers => 'Ähli belgiler';
  @override
  String get singleNumber => 'Bir belgi';
  @override
  String get groupLabel => 'Topar';
  @override
  String get serverGroupLabel => 'Topar (serwer)';
  @override
  String get serviceTitle => 'SMS ugratma';
  @override
  String get noMatches => 'Hiç zat tapylmady';

  @override
  String get historyTitle => 'Ugratma taryhy';
  @override
  String get clearHistory => 'Taryhy arassala';
  @override
  String get clearHistoryTitle => 'Taryh arassalansynmy?';
  @override
  String get clearHistoryBody =>
      'Ähli ugratma ýazgylary pozular. Yzyna gaýtaryp bolmaýar.';
  @override
  String get clear => 'Arassala';
  @override
  String get campaignsLabel => 'Ugratma';
  @override
  String get errorsLabel => 'Ýalňyş';
  @override
  String get historyEmptyTitle => 'Entek ugratma bolmady';
  @override
  String get historyEmptyHint =>
      'Her ugratma şu ýerde görüner: haçan, kime we näçe SMS gitdi.';
  @override
  String errorsN(int n) => 'ýalňyş: $n';
  @override
  String get campaign => 'Ugratma';
  @override
  String get deleteRecord => 'Ýazgyny poz';
  @override
  String get deleteRecordTitle => 'Ýazgy pozulsynmy?';
  @override
  String get deleteRecordBody => 'Bu ugratmanyň ýazgysy taryhdan pozular.';
  @override
  String get recordNotFound => 'Ýazgy tapylmady';
  @override
  String get started => 'Başlandy';
  @override
  String get duration => 'Dowamlylygy';
  @override
  String get partsPerNumber => 'Bir belgä bölek';
  @override
  String numbersN(int n) => 'Belgiler ($n)';
  @override
  String get serverTextsTitle => 'Serwerdäki tekstler';
  @override
  String get searchMessages => 'Habar gözle…';
  @override
  String get historyEmpty => 'Taryh boş';
  @override
  String get deleteEverything => 'Hemmesi pozulsynmy?';
  @override
  String get cannotUndo => 'Yzyna gaýtaryp bolmaýar';
  @override
  String get historyCleared => 'Taryh arassalandy';

  @override
  String get statsTitle => 'Statistika';
  @override
  String get todayLabel => 'Şu gün';
  @override
  String campaignsN(int n) => 'ugratma: $n';
  @override
  String get last7days => 'Soňky 7 gün';
  @override
  String get totalSent => 'Jemi ugradyldy';
  @override
  String successRate(int percent) => 'üstünlikli $percent%';
  @override
  String get numbersInGroups => 'Toparlardaky belgiler';
  @override
  String groupsN(int n) => 'topar: $n';
  @override
  String get bySource => 'Çeşmeler boýunça';
  @override
  String get noSentYet => 'Entek ugradylan SMS ýok';
  @override
  String get latestCampaigns => 'Soňky ugratmalar';

  @override
  String get devicesTitle => 'Enjamlar';
  @override
  String get thisDevice => 'Şu enjam';
  @override
  String deviceLine(String id, int sentToday) =>
      'ID $id · şu gün ugradyldy: $sentToday';
  @override
  String get simForSending => 'Ugratma üçin SIM';
  @override
  String get simSystemDefault => 'Ulgamyň adatysy';
  @override
  String get simSystemDefaultHint => 'Telefon sazlamalarynda saýlanyşy ýaly';
  @override
  String simSlot(int slot) => 'Slot $slot';
  @override
  String get simDefaultSms => 'adaty SMS';
  @override
  String get simNotRead => 'SIM kartlar okalmady: «Telefon» rugsady gerek.';
  @override
  String get balance => 'Balans';
  @override
  String approxSms(int n) => '≈ $n SMS';
  @override
  String get balanceNotChecked => 'Balans entek barlanmady';
  @override
  String balanceUpdated(String when) =>
      'Täzelendi $when · ugratmalardan soň awtomatiki azalýar';
  @override
  String operatorReply(String text) => 'Operatoryň jogaby: $text';
  @override
  String checkViaSms(String number) => 'Barla ($number-e SMS)';
  @override
  String get waitingReply => 'Jogaba garaşýarys…';
  @override
  String get balanceTmt => 'Balans, TMT';
  @override
  String get forExample => 'Meselem 12.50';
  @override
  String get pricingTitle => 'Baha we balans soragy';
  @override
  String get pricePerPart => 'Bir SMS böleginiň bahasy, TMT';
  @override
  String get priceHelper => '1 teňňe = 0.01 TMT; uzyn SMS = birnäçe bölek';
  @override
  String get requestNumber => 'Balans sorag belgisi';
  @override
  String get requestText => 'Sorag teksti';
  @override
  String get saved => 'Ýatda saklandy';
  @override
  String get otherDevices => 'Beýleki enjamlar';
  @override
  String get otherDevicesUnsupported =>
      'Serwer entek enjamlar sanawyny goldamaýar. GET /devices/ we POST /devices/heartbeat/ endpointleri gerek (docs/DEVICES_API.md). Şondan soň bu ýerde beýleki telefonlar balansy we statistikasy bilen görüner.';
  @override
  String get noOtherDevices => 'Entek başga enjam ýok';
  @override
  String get numberUnknown => 'belgi belli däl';
  @override
  String todaySms(int n) => 'şu gün: $n SMS';
  @override
  String get noServerConnection => 'Serwer bilen baglanyşyk ýok';
  @override
  String serverStatus(int status) => 'Serwer $status jogap berdi';
  @override
  String get requestNotSent => 'Sorag ugradylmady';
  @override
  String get noOperatorReply => 'Operatordan jogap gelmedi';

  @override
  String get addNumberTitle => 'Belgi goşmak';
  @override
  String get clientName => 'Müşderiniň ady';
  @override
  String get enterNumber => 'Belgini giriziň';
  @override
  String get switchMode => 'Režimi çalyş';
  @override
  String get modeManual => 'Režim: elde goşmak';
  @override
  String get modeContacts => 'Režim: kontaktlardan';
  @override
  String get importContacts => 'Kontaktlary import etmek';
  @override
  String get pickFromContacts => 'Kontaktlardan saýla';
  @override
  String get noName => 'Atsyz';
  @override
  String get invalidNumber => 'Belginiň formaty nädogry';
  @override
  String get numberExists => 'Bu belgi eýýäm goşulan';
  @override
  String maxNumbers(int max, int now) => 'Iň köp $max belgi. Häzir: $now';
  @override
  String get addingNumber => 'Belgi goşulýar…';
  @override
  String get numberAdded => 'Belgi goşuldy';
  @override
  String get excelEmpty => 'Excel faýly boş';
  @override
  String get excelNoValid => 'Faýlda dogry belgi tapylmady';
  @override
  String limitReached(int max) => '$max limitine ýetildi';
  @override
  String importedN(int n) => 'Import edildi: $n';
  @override
  String importedSkipped(int n, int skipped) =>
      'Import edildi: $n · geçirildi: $skipped';
  @override
  String get pickContacts => 'Kontaktlary saýla';
  @override
  String get searchContact => 'Kontakt gözle…';
  @override
  String selectedOf(int selected, int total) => 'Saýlanan: $selected / $total';
  @override
  String get unselectAll => 'Hemmesini aýyr';
  @override
  String get nothingSelected => 'Hiç zat saýlanmady';
  @override
  String get contactsAdded => 'Kontaktlar goşuldy';
  @override
  String get add => 'Goş';
}
