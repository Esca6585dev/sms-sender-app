import 'package:flutter/widgets.dart';

import 'package:sms_sender_app/l10n/strings_ru.dart';
import 'package:sms_sender_app/l10n/strings_tk.dart';

/// UI languages. Material's own widgets (date pickers, tooltips) have no
/// Turkmen translation, so Turkmen falls back to Russian for those.
enum AppLanguage {
  tk,
  ru,
  en;

  static AppLanguage fromName(String? name) => AppLanguage.values
      .firstWhere((l) => l.name == name, orElse: () => AppLanguage.ru);

  String get nativeName => switch (this) {
        AppLanguage.tk => 'Türkmençe',
        AppLanguage.ru => 'Русский',
        AppLanguage.en => 'English',
      };

  Locale get materialLocale => switch (this) {
        AppLanguage.tk => const Locale('ru'),
        AppLanguage.ru => const Locale('ru'),
        AppLanguage.en => const Locale('en'),
      };
}

/// All user-visible strings. The base class is English; [StringsRu] and
/// [StringsTk] override every getter. Widgets use `S.of(context)`,
/// controllers use `S.current` (set by the app root when the language
/// changes; the whole widget tree is rebuilt at that moment).
class S {
  const S();

  static S current = const StringsRu();

  static S of(BuildContext context) => current;

  static S forLanguage(AppLanguage language) => switch (language) {
        AppLanguage.tk => const StringsTk(),
        AppLanguage.ru => const StringsRu(),
        AppLanguage.en => const S(),
      };

  // ----------------------------------------------------------- general
  String get appName => 'elite SMS';
  String get appSubtitle => 'SMS campaigns for customers';
  String get ok => 'OK';
  String get cancel => 'Cancel';
  String get save => 'Save';
  String get delete => 'Delete';
  String get deleteAll => 'Delete all';
  String get reset => 'Reset';
  String get stop => 'Stop';
  String get stopping => 'Stopping…';
  String get send => 'Send';
  String get sending => 'Sending…';
  String get retry => 'Retry';
  String get refresh => 'Refresh';
  String get more => 'More';
  String get menu => 'Menu';
  String get yes => 'Yes';
  String get understood => 'Got it';
  String get manual => 'Manually';
  String get byDefault => 'Default';
  String get none => '—';
  String get today => 'Today';
  String get yesterday => 'Yesterday';
  List<String> get weekdaysShort =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String minutesSeconds(int minutes, int seconds) =>
      minutes == 0 ? '$seconds s' : '$minutes min $seconds s';
  String numbersCount(int n) => '$n numbers';
  String smsCount(int n) => '$n SMS';

  // -------------------------------------------------------- navigation
  String get tabSend => 'Send';
  String get tabGroups => 'Groups';
  String get tabHistory => 'History';
  String get tabStats => 'Statistics';
  String get drawerAddNumber => 'Add number';
  String get drawerAddNumberHint => 'Manually, from contacts or Excel';
  String get drawerDevices => 'Devices & balance';
  String get drawerDevicesHint => 'SIM, balance, SMS price, other phones';
  String get drawerServerTexts => 'Texts on server';
  String get drawerServerTextsHint => 'Saved message texts';
  String get drawerDesign => 'Design';
  String get drawerTheme => 'Theme';
  String get drawerLanguage => 'Language';
  String get themeAuto => 'Auto';
  String get themeLight => 'Light';
  String get themeDark => 'Dark';
  String get versionLine => 'elite-elektronika · SMS campaigns · v1.0.0';

  // ------------------------------------------------------------ styles
  String get styleSoftGlass => 'Soft glass cards on a tinted background';
  String get styleBoldBrand => 'Navy header, red action button';
  String get styleCleanMono => 'Black & white minimalism, thin lines';
  String get styleDarkNeon => 'Dark background, neon accent';

  // ---------------------------------------------------------- composer
  String get messageText => 'Message text';
  String get messageHint => 'Write a message to the customers…';
  String get enterMessage => 'Enter the message text';
  String get encodingGsm => 'GSM-7';
  String get encodingUnicode => 'Unicode';
  String counterLabel(int length, int capacity, int parts, String encoding) =>
      '$length / $capacity · SMS: $parts · $encoding';
  String tooltipMultipart(int parts) =>
      'Long message: it will be sent as $parts parts';
  String tooltipSingle(int limit, String encoding) =>
      'One SMS, up to $limit characters ($encoding)';
  String partsSuffix(int parts) => ' ($parts parts each)';

  // ----------------------------------------------------- group status
  String get statusPending => 'Pending';
  String get statusInProgress => 'In progress';
  String get statusPaused => 'Paused';
  String get statusPartial => 'With errors';
  String get statusSent => 'Sent';

  // ------------------------------------------------------------ groups
  String get groupsTitle => 'Send groups';
  String groupDefaultName(String letter) => 'Group $letter';
  String rangeLabel(int from, int to) => 'No. $from–$to';
  String get importExcel => 'Import from Excel';
  String get importing => 'Importing Excel…';
  String get groupsEmptyTitle => 'No groups yet';
  String get groupsEmptyHint =>
      'Import an Excel file with numbers: they will be split into groups of 100 automatically.';
  String get groupsExist => 'Groups already exist';
  String get importAppend => 'Add to existing';
  String get importAppendHint => 'New groups continue the numbering';
  String get importReplace => 'Replace';
  String get importReplaceHint => 'Current groups will be deleted';
  String get fileReadError => 'Could not read the file';
  String importError(Object error) => 'Import error: $error';
  String importNothing(int rows) =>
      'No valid numbers found in the file (rows: $rows)';
  String importResult(int imported, int groups) =>
      'Imported: $imported numbers → groups: $groups';
  String importInvalid(int n) => ' · skipped invalid: $n';
  String importDuplicates(int n) => ' · duplicates: $n';
  String get resetAllStatuses => 'Reset statuses of all groups';
  String get deleteAllGroups => 'Delete all groups';
  String get openList => 'Open list';
  String get rename => 'Rename';
  String get removeFromQueue => 'Remove from queue';
  String get deleteGroup => 'Delete group';
  String get showNumbers => 'Show numbers';
  String get hideNumbers => 'Hide numbers';
  String get continueSending => 'Continue';
  String get retryFailed => 'Retry';
  String inQueue(int position) => 'In queue #$position';
  String get sentLabel => 'Sent';
  String get remainingLabel => 'Remaining';
  String get failedLabel => 'Failed';
  String get runningLabel => 'Running';
  String sentOf(int sent, int total) => 'Sent $sent / $total';
  String more_(int n) => '… $n more';
  String get groupsCount => 'Groups';
  String get numbersLabel => 'Numbers';
  String sendingGroup(String title, int sent, int total) =>
      'Sending: $title · $sent / $total';
  String get queueLabel => 'Queue:';
  String get balanceUnknown => 'Balance unknown';
  String balanceLine(String amount) => 'Balance $amount';
  String get check => 'Check';
  String get waiting => 'Waiting…';
  String get delayLabel => 'Delay:';
  String get delayNone => 'No delay';
  String delaySeconds(String seconds) => '$seconds s';
  String sendAll(int groups) => 'Send all ($groups)';
  String queueAll(int groups) => 'Queue all ($groups)';
  String selected(int n) => 'Selected: $n';
  String get clearSelection => 'Clear selection';
  String get selectAll => 'Select all';
  String get sendSelected => 'Send selected';
  String pausedUntil(String time) => 'SMS limit reached · continue at $time';
  String get continueNow => 'Continue now';
  String get sortLabel => 'Sort';
  String get sortServer => 'As on server';
  String get sortByName => 'By name';
  String get sortByPhone => 'By number';
  String get sortUnsentFirst => 'Unsent first';

  // ----------------------------------------------------- group actions
  String sendGroupTitle(String title) => 'Send $title?';
  String queueGroupTitle(String title) => 'Add $title to the queue?';
  String willSend(int n) => 'Will send $n SMS';
  String get toQueue => 'To queue';
  String groupAlreadyQueued(String title) => '$title is already queued or sending';
  String groupQueued(String title) => '$title added to the queue';
  String groupSentReport(String title, int sent, int total) =>
      '$title: sent $sent of $total';
  String get sendAllTitle => 'Send all groups?';
  String get queueAllTitle => 'Queue all groups?';
  String groupsAndSms(int groups, int sms) => 'Groups: $groups, SMS: $sms';
  String get sendAllConfirm => 'Send all';
  String get nothingToSend => 'Nothing to send';
  String get groupsQueued => 'Groups added to the queue';
  String doneReport(int sent, int total) => 'Done: sent $sent of $total';
  String get selectedNothing => 'Nothing to send in the selected groups';
  String sendSelectedTitle(int n) => 'Send selected ($n)?';
  String smsLine(int n) => 'SMS: $n';
  String get alreadyQueued => 'Groups are already queued';
  String removedFromQueue(String title) => '$title removed from the queue';
  String renameTitle(String defaultTitle) => 'Name · $defaultTitle';
  String resetGroupTitle(String title) => 'Reset $title?';
  String get resetGroupBody => 'Send statuses will be cleared, numbers stay.';
  String groupResetDone(String title) => '$title reset';
  String get resetAllTitle => 'Reset all groups?';
  String get resetAllBody =>
      'Send statuses of all groups will be cleared, numbers stay.';
  String get resetAllDone => 'Statuses of all groups reset';
  String deleteGroupTitle(String title) => 'Delete $title?';
  String deleteGroupBody(int n) => 'The $n numbers of the group will be removed.';
  String groupDeleted(String title) => '$title deleted';
  String get deleteAllGroupsTitle => 'Delete all groups?';
  String get deleteAllGroupsBody =>
      'All groups and numbers will be deleted. This cannot be undone.';
  String get allGroupsDeleted => 'All groups deleted';
  String costLine(String cost) => '\nCost ≈ $cost';
  String balanceSuffix(String balance) => ' · balance $balance';
  String get balanceMayBeShort => '\nThe balance may not be enough!';
  String get sendStopped => 'Sending stopped';
  String limitError(String details) =>
      'The SMS limit was reached or the operator temporarily blocked sending.\n\nTry again later.\n\n$details';
  String get noSendConfirmation => 'No send confirmation (timeout)';
  String get notSent => 'Not sent';
  String get groupDeletedTitle => 'Group';
  String get groupDeletedBody => 'Group deleted';
  String get resetStatuses => 'Reset statuses';
  String continueSendingN(int n) => 'Continue sending ($n)';
  String sendGroupN(int n) => 'Send group ($n)';

  // ------------------------------------------------------------- send
  String get sendTitle => 'Send';
  String get searchHint => 'Search by number or name';
  String get refreshList => 'Refresh list';
  String get syncFromServer => 'Load from server';
  String get syncing => 'Loading numbers from server…';
  String syncResult(int numbers, int groups) =>
      'Loaded $numbers numbers → $groups groups';
  String get syncError => 'Could not load the numbers from the server';
  String get clearSent => 'Reset sent flags';
  String get deleteAllNumbers => 'Delete all numbers';
  String get totalNumbers => 'Total numbers';
  String remainingN(int n) => 'remaining $n';
  String get sendToAll => 'Send to all';
  String get noNumbersTitle => 'No numbers yet';
  String get noNumbersHint =>
      'Add numbers manually, from contacts or import an Excel file.';
  String get sendToThisNumber => 'Send to this number';
  String get deleteNumber => 'Delete number';
  String get alreadySentToNumber => 'An SMS was already sent to this number';
  String get sendingSms => 'Sending SMS…';
  String sentTo(String phone) => 'Sent: $phone';
  String failedTo(String phone) => 'Could not send: $phone';
  String get deletingNumber => 'Deleting number…';
  String deleted(String phone) => 'Deleted: $phone';
  String get clearSentTitle => 'Reset sent flags?';
  String get clearSentBody => 'All numbers will be marked as not sent';
  String get clearingSent => 'Resetting sent flags…';
  String get clearSentDone => 'Sent flags reset';
  String deleteError(Object e) => 'Delete error: $e';
  String get clearListTitle => 'Delete all numbers?';
  String get clearListBody => 'All numbers will be deleted';
  String get deleting => 'Deleting…';
  String get preparing => 'Preparing…';
  String get deletingContacts => 'Deleting contacts…';
  String get refreshingData => 'Refreshing data…';
  String get done => 'Done';
  String get allNumbers => 'All numbers';
  String get singleNumber => 'Single number';
  String get groupLabel => 'Group';
  String get serverGroupLabel => 'Group (server)';
  String get serviceTitle => 'SMS campaign';
  String get noMatches => 'Nothing found';

  // ---------------------------------------------------------- history
  String get historyTitle => 'Send history';
  String get clearHistory => 'Clear history';
  String get clearHistoryTitle => 'Clear history?';
  String get clearHistoryBody =>
      'All campaign records will be deleted. This cannot be undone.';
  String get clear => 'Clear';
  String get campaignsLabel => 'Campaigns';
  String get errorsLabel => 'Errors';
  String get historyEmptyTitle => 'No campaigns yet';
  String get historyEmptyHint =>
      'Every send will appear here: when, to whom and how many SMS went out.';
  String errorsN(int n) => 'errors: $n';
  String get campaign => 'Campaign';
  String get deleteRecord => 'Delete record';
  String get deleteRecordTitle => 'Delete record?';
  String get deleteRecordBody => 'This campaign will be removed from history.';
  String get recordNotFound => 'Record not found';
  String get started => 'Started';
  String get duration => 'Duration';
  String get partsPerNumber => 'Parts per number';
  String numbersN(int n) => 'Numbers ($n)';
  String get serverTextsTitle => 'Texts on server';
  String get searchMessages => 'Search messages…';
  String get historyEmpty => 'History is empty';
  String get deleteEverything => 'Delete everything?';
  String get cannotUndo => 'This cannot be undone';
  String get historyCleared => 'History cleared';

  // ------------------------------------------------------------ stats
  String get statsTitle => 'Statistics';
  String get todayLabel => 'Today';
  String campaignsN(int n) => 'campaigns: $n';
  String get last7days => 'Last 7 days';
  String get totalSent => 'Total sent';
  String successRate(int percent) => 'success $percent%';
  String get numbersInGroups => 'Numbers in groups';
  String groupsN(int n) => 'groups: $n';
  String get bySource => 'By source';
  String get noSentYet => 'No SMS sent yet';
  String get latestCampaigns => 'Latest campaigns';

  // ---------------------------------------------------------- devices
  String get devicesTitle => 'Devices';
  String get thisDevice => 'This device';
  String deviceLine(String id, int sentToday) =>
      'ID $id · sent today: $sentToday';
  String get simForSending => 'SIM for sending';
  String get simSystemDefault => 'System default';
  String get simSystemDefaultHint => 'As chosen in the phone settings';
  String simSlot(int slot) => 'Slot $slot';
  String get simDefaultSms => 'default SMS';
  String get simNotRead => 'SIM cards not read: the "Phone" permission is needed.';
  String get balance => 'Balance';
  String approxSms(int n) => '≈ $n SMS';
  String get balanceNotChecked => 'Balance not checked yet';
  String balanceUpdated(String when) =>
      'Updated $when · decreases automatically after sends';
  String operatorReply(String text) => 'Operator reply: $text';
  String checkViaSms(String number) => 'Check (SMS to $number)';
  String get waitingReply => 'Waiting for reply…';
  String get balanceTmt => 'Balance, TMT';
  String get forExample => 'For example 12.50';
  String get pricingTitle => 'Cost and balance request';
  String get pricePerPart => 'Price of one SMS part, TMT';
  String get priceHelper => '1 tenge = 0.01 TMT; a long SMS = several parts';
  String get requestNumber => 'Balance request number';
  String get requestText => 'Request text';
  String get saved => 'Saved';
  String get otherDevices => 'Other devices';
  String get otherDevicesUnsupported =>
      'The server does not support the device list yet. It needs GET /devices/ and POST /devices/heartbeat/ (see docs/DEVICES_API.md). After that other phones with their balance and statistics will appear here.';
  String get noOtherDevices => 'No other devices yet';
  String get numberUnknown => 'number unknown';
  String todaySms(int n) => 'today: $n SMS';
  String get noServerConnection => 'No connection to the server';
  String serverStatus(int status) => 'Server responded $status';
  String get requestNotSent => 'Request not sent';
  String get noOperatorReply => 'No reply from the operator';

  // ------------------------------------------------------ add contact
  String get addNumberTitle => 'Add number';
  String get clientName => 'Customer name';
  String get enterNumber => 'Enter number';
  String get switchMode => 'Switch mode';
  String get modeManual => 'Mode: manual entry';
  String get modeContacts => 'Mode: from contacts';
  String get importContacts => 'Import contacts';
  String get pickFromContacts => 'Pick from contacts';
  String get excelButton => '+ Excel';
  String get noName => 'No name';
  String get invalidNumber => 'Invalid number format';
  String get numberExists => 'This number is already added';
  String maxNumbers(int max, int now) => 'Maximum $max numbers. Now: $now';
  String get addingNumber => 'Adding number…';
  String get numberAdded => 'Number added';
  String get excelEmpty => 'The Excel file is empty';
  String get excelNoValid => 'No valid numbers found in the file';
  String limitReached(int max) => 'Limit of $max reached';
  String importedN(int n) => 'Imported: $n';
  String importedSkipped(int n, int skipped) => 'Imported: $n · skipped: $skipped';
  String get pickContacts => 'Pick contacts';
  String get searchContact => 'Search contact…';
  String selectedOf(int selected, int total) => 'Selected: $selected / $total';
  String get unselectAll => 'Unselect all';
  String get nothingSelected => 'Nothing selected';
  String get contactsAdded => 'Contacts added';
  String get add => 'Add';
}
