import 'package:sms_sender_app/l10n/strings.dart';

/// Russian strings.
class StringsRu extends S {
  const StringsRu();

  @override
  String get appSubtitle => 'SMS-рассылка клиентам';
  @override
  String get ok => 'ОК';
  @override
  String get cancel => 'Отмена';
  @override
  String get save => 'Сохранить';
  @override
  String get delete => 'Удалить';
  @override
  String get deleteAll => 'Удалить всё';
  @override
  String get reset => 'Сброс';
  @override
  String get stop => 'Стоп';
  @override
  String get stopping => 'Останавливаем…';
  @override
  String get send => 'Отправить';
  @override
  String get sending => 'Отправляется…';
  @override
  String get retry => 'Повторить';
  @override
  String get refresh => 'Обновить';
  @override
  String get more => 'Ещё';
  @override
  String get menu => 'Меню';
  @override
  String get yes => 'Да';
  @override
  String get understood => 'Понятно';
  @override
  String get manual => 'Вручную';
  @override
  String get byDefault => 'По умолчанию';
  @override
  String get today => 'Сегодня';
  @override
  String get yesterday => 'Вчера';
  @override
  List<String> get weekdaysShort =>
      const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  @override
  String minutesSeconds(int minutes, int seconds) =>
      minutes == 0 ? '$seconds сек' : '$minutes мин $seconds сек';
  @override
  String numbersCount(int n) => '$n номеров';
  @override
  String smsCount(int n) => '$n SMS';

  @override
  String get tabSend => 'Рассылка';
  @override
  String get tabGroups => 'Группы';
  @override
  String get tabHistory => 'История';
  @override
  String get tabStats => 'Статистика';
  @override
  String get drawerAddNumber => 'Добавить номер';
  @override
  String get drawerAddNumberHint => 'Вручную, из контактов или Excel';
  @override
  String get drawerDevices => 'Устройства и баланс';
  @override
  String get drawerDevicesHint => 'SIM, баланс, цена SMS, другие телефоны';
  @override
  String get drawerServerTexts => 'Тексты на сервере';
  @override
  String get drawerServerTextsHint => 'Сохранённые тексты сообщений';
  @override
  String get drawerDesign => 'Дизайн';
  @override
  String get drawerTheme => 'Тема оформления';
  @override
  String get drawerLanguage => 'Язык';
  @override
  String get themeAuto => 'Авто';
  @override
  String get themeLight => 'Светлая';
  @override
  String get themeDark => 'Тёмная';
  @override
  String get versionLine => 'elite-elektronika · SMS-рассылка · v1.0.0';

  @override
  String get styleSoftGlass => 'Мягкий фон, стеклянные карточки';
  @override
  String get styleBoldBrand => 'Тёмно-синий верх, красная кнопка';
  @override
  String get styleCleanMono => 'Чёрно-белый минимализм, тонкие линии';
  @override
  String get styleDarkNeon => 'Тёмный фон, неоновый акцент';

  @override
  String get messageText => 'Текст сообщения';
  @override
  String get messageHint => 'Напишите сообщение клиентам…';
  @override
  String get enterMessage => 'Введите текст сообщения';
  @override
  String tooltipMultipart(int parts) =>
      'Длинное сообщение: будет отправлено как $parts части';
  @override
  String tooltipSingle(int limit, String encoding) =>
      'Одно SMS, максимум $limit символов ($encoding)';
  @override
  String partsSuffix(int parts) => ' (каждое из $parts частей)';

  @override
  String get statusPending => 'Ожидает';
  @override
  String get statusInProgress => 'В процессе';
  @override
  String get statusPaused => 'Приостановлено';
  @override
  String get statusPartial => 'С ошибками';
  @override
  String get statusSent => 'Отправлено';

  @override
  String get groupsTitle => 'Группы рассылки';
  @override
  String groupDefaultName(String letter) => 'Группа $letter';
  @override
  String rangeLabel(int from, int to) => '№ $from–$to';
  @override
  String get importExcel => 'Импорт из Excel';
  @override
  String get importing => 'Импорт Excel…';
  @override
  String get groupsEmptyTitle => 'Групп пока нет';
  @override
  String get groupsEmptyHint =>
      'Импортируйте Excel-файл с номерами: они будут автоматически разбиты на группы по 100.';
  @override
  String get groupsExist => 'Уже есть группы';
  @override
  String get importAppend => 'Добавить к существующим';
  @override
  String get importAppendHint => 'Новые группы продолжат нумерацию';
  @override
  String get importReplace => 'Заменить';
  @override
  String get importReplaceHint => 'Текущие группы будут удалены';
  @override
  String get fileReadError => 'Не удалось прочитать файл';
  @override
  String importError(Object error) => 'Ошибка импорта: $error';
  @override
  String importNothing(int rows) =>
      'В файле не найдено ни одного корректного номера (строк: $rows)';
  @override
  String importResult(int imported, int groups) =>
      'Импортировано: $imported номеров → групп: $groups';
  @override
  String importInvalid(int n) => ' · пропущено некорректных: $n';
  @override
  String importDuplicates(int n) => ' · дубликатов: $n';
  @override
  String get resetAllStatuses => 'Сбросить статусы всех групп';
  @override
  String get deleteAllGroups => 'Удалить все группы';
  @override
  String get openList => 'Открыть список';
  @override
  String get rename => 'Переименовать';
  @override
  String get removeFromQueue => 'Убрать из очереди';
  @override
  String get deleteGroup => 'Удалить группу';
  @override
  String get showNumbers => 'Показать номера';
  @override
  String get hideNumbers => 'Скрыть номера';
  @override
  String get continueSending => 'Продолжить';
  @override
  String get retryFailed => 'Повторить';
  @override
  String inQueue(int position) => 'В очереди #$position';
  @override
  String get sentLabel => 'Отправлено';
  @override
  String get remainingLabel => 'Осталось';
  @override
  String get failedLabel => 'Ошибок';
  @override
  String get runningLabel => 'Идёт';
  @override
  String sentOf(int sent, int total) => 'Отправлено $sent / $total';
  @override
  String more_(int n) => '… ещё $n';
  @override
  String get groupsCount => 'Групп';
  @override
  String get numbersLabel => 'Номеров';
  @override
  String sendingGroup(String title, int sent, int total) =>
      'Отправка: $title · $sent / $total';
  @override
  String get queueLabel => 'Очередь:';
  @override
  String get balanceUnknown => 'Баланс неизвестен';
  @override
  String balanceLine(String amount) => 'Баланс $amount';
  @override
  String get check => 'Проверить';
  @override
  String get waiting => 'Ждём…';
  @override
  String get delayLabel => 'Задержка:';
  @override
  String get delayNone => 'Без задержки';
  @override
  String delaySeconds(String seconds) => '$seconds сек';
  @override
  String sendAll(int groups) => 'Отправить все ($groups)';
  @override
  String queueAll(int groups) => 'Все в очередь ($groups)';
  @override
  String selected(int n) => 'Выбрано: $n';
  @override
  String get clearSelection => 'Снять выделение';
  @override
  String get selectAll => 'Выбрать все';
  @override
  String get sendSelected => 'Отправить выбранные';
  @override
  String pausedUntil(String time) => 'Лимит SMS · продолжим в $time';
  @override
  String get continueNow => 'Продолжить сейчас';
  @override
  String get sortLabel => 'Сортировка';
  @override
  String get sortServer => 'Как на сервере';
  @override
  String get sortByName => 'По имени';
  @override
  String get sortByPhone => 'По номеру';
  @override
  String get sortUnsentFirst => 'Сначала неотправленные';

  @override
  String sendGroupTitle(String title) => 'Отправить $title?';
  @override
  String queueGroupTitle(String title) => 'Добавить $title в очередь?';
  @override
  String willSend(int n) => 'Будет отправлено $n SMS';
  @override
  String get toQueue => 'В очередь';
  @override
  String groupAlreadyQueued(String title) =>
      '$title уже в очереди или отправляется';
  @override
  String groupQueued(String title) => '$title добавлена в очередь';
  @override
  String groupSentReport(String title, int sent, int total) =>
      '$title: отправлено $sent из $total';
  @override
  String get sendAllTitle => 'Отправить все группы?';
  @override
  String get queueAllTitle => 'Поставить все группы в очередь?';
  @override
  String groupsAndSms(int groups, int sms) => 'Групп: $groups, SMS: $sms';
  @override
  String get sendAllConfirm => 'Отправить все';
  @override
  String get nothingToSend => 'Нечего отправлять';
  @override
  String get groupsQueued => 'Группы добавлены в очередь';
  @override
  String doneReport(int sent, int total) => 'Готово: отправлено $sent из $total';
  @override
  String get selectedNothing => 'В выбранных группах нечего отправлять';
  @override
  String sendSelectedTitle(int n) => 'Отправить выбранные ($n)?';
  @override
  String smsLine(int n) => 'SMS: $n';
  @override
  String get alreadyQueued => 'Группы уже в очереди';
  @override
  String removedFromQueue(String title) => '$title убрана из очереди';
  @override
  String renameTitle(String defaultTitle) => 'Название · $defaultTitle';
  @override
  String resetGroupTitle(String title) => 'Сбросить $title?';
  @override
  String get resetGroupBody =>
      'Статусы отправки будут очищены, номера останутся.';
  @override
  String groupResetDone(String title) => '$title сброшена';
  @override
  String get resetAllTitle => 'Сбросить все группы?';
  @override
  String get resetAllBody =>
      'Статусы отправки всех групп будут очищены, номера останутся.';
  @override
  String get resetAllDone => 'Статусы всех групп сброшены';
  @override
  String deleteGroupTitle(String title) => 'Удалить $title?';
  @override
  String deleteGroupBody(int n) => 'Номера группы ($n) будут удалены из списка.';
  @override
  String groupDeleted(String title) => '$title удалена';
  @override
  String get deleteAllGroupsTitle => 'Удалить все группы?';
  @override
  String get deleteAllGroupsBody =>
      'Все группы и номера будут удалены. Это действие нельзя отменить.';
  @override
  String get allGroupsDeleted => 'Все группы удалены';
  @override
  String costLine(String cost) => '\nСтоимость ≈ $cost';
  @override
  String balanceSuffix(String balance) => ' · баланс $balance';
  @override
  String get balanceMayBeShort => '\nБаланса может не хватить!';
  @override
  String get sendStopped => 'Отправка остановлена';
  @override
  String limitError(String details) =>
      'Достигнут лимит отправки SMS или оператор временно запретил отправку.\n\nПопробуйте позже.\n\n$details';
  @override
  String get noSendConfirmation => 'Нет подтверждения отправки (таймаут)';
  @override
  String get notSent => 'Не отправлено';
  @override
  String get groupDeletedTitle => 'Группа';
  @override
  String get groupDeletedBody => 'Группа удалена';
  @override
  String get resetStatuses => 'Сбросить статусы';
  @override
  String continueSendingN(int n) => 'Продолжить отправку ($n)';
  @override
  String sendGroupN(int n) => 'Отправить группу ($n)';

  @override
  String get sendTitle => 'Рассылка';
  @override
  String get searchHint => 'Поиск номера или имени';
  @override
  String get refreshList => 'Обновить список';
  @override
  String get syncFromServer => 'Загрузить с сервера';
  @override
  String get syncing => 'Загружаем номера с сервера…';
  @override
  String syncResult(int numbers, int groups) =>
      'Загружено $numbers номеров → групп: $groups';
  @override
  String get syncError => 'Не удалось загрузить номера с сервера';
  @override
  String get clearSent => 'Сбросить отправленные';
  @override
  String get deleteAllNumbers => 'Удалить все номера';
  @override
  String get totalNumbers => 'Всего номеров';
  @override
  String remainingN(int n) => 'осталось $n';
  @override
  String get sendToAll => 'Отправить всем';
  @override
  String get noNumbersTitle => 'Номеров пока нет';
  @override
  String get noNumbersHint =>
      'Добавьте номера вручную, из контактов или импортируйте Excel.';
  @override
  String get sendToThisNumber => 'Отправить этому номеру';
  @override
  String get deleteNumber => 'Удалить номер';
  @override
  String get alreadySentToNumber => 'На этот номер SMS уже была отправлена';
  @override
  String get sendingSms => 'Отправка SMS…';
  @override
  String sentTo(String phone) => 'Отправлено: $phone';
  @override
  String failedTo(String phone) => 'Не удалось отправить: $phone';
  @override
  String get deletingNumber => 'Удаление номера…';
  @override
  String deleted(String phone) => 'Удалён: $phone';
  @override
  String get clearSentTitle => 'Сбросить отправленные?';
  @override
  String get clearSentBody => 'Все номера будут отмечены как неотправленные';
  @override
  String get clearingSent => 'Сбрасываем отметки…';
  @override
  String get clearSentDone => 'Список отправленных номеров очищен';
  @override
  String deleteError(Object e) => 'Ошибка удаления: $e';
  @override
  String get clearListTitle => 'Удалить все номера?';
  @override
  String get clearListBody => 'Все номера будут удалены';
  @override
  String get deleting => 'Удаление…';
  @override
  String get preparing => 'Подготовка…';
  @override
  String get deletingContacts => 'Удаляем контакты…';
  @override
  String get refreshingData => 'Обновляем данные…';
  @override
  String get done => 'Готово';
  @override
  String get allNumbers => 'Все номера';
  @override
  String get singleNumber => 'Один номер';
  @override
  String get groupLabel => 'Группа';
  @override
  String get serverGroupLabel => 'Группа (сервер)';
  @override
  String get serviceTitle => 'Рассылка SMS';
  @override
  String get noMatches => 'Ничего не найдено';

  @override
  String get historyTitle => 'История рассылок';
  @override
  String get clearHistory => 'Очистить историю';
  @override
  String get clearHistoryTitle => 'Очистить историю?';
  @override
  String get clearHistoryBody =>
      'Все записи о рассылках будут удалены. Это действие нельзя отменить.';
  @override
  String get clear => 'Очистить';
  @override
  String get campaignsLabel => 'Рассылок';
  @override
  String get errorsLabel => 'Ошибок';
  @override
  String get historyEmptyTitle => 'Рассылок пока не было';
  @override
  String get historyEmptyHint =>
      'Здесь появится каждая отправка: когда, кому и сколько SMS ушло.';
  @override
  String errorsN(int n) => 'ошибок: $n';
  @override
  String get campaign => 'Рассылка';
  @override
  String get deleteRecord => 'Удалить запись';
  @override
  String get deleteRecordTitle => 'Удалить запись?';
  @override
  String get deleteRecordBody => 'Запись об этой рассылке будет удалена из истории.';
  @override
  String get recordNotFound => 'Запись не найдена';
  @override
  String get started => 'Начало';
  @override
  String get duration => 'Длительность';
  @override
  String get partsPerNumber => 'Частей на номер';
  @override
  String numbersN(int n) => 'Номера ($n)';
  @override
  String get serverTextsTitle => 'Тексты на сервере';
  @override
  String get searchMessages => 'Поиск сообщений…';
  @override
  String get historyEmpty => 'История пуста';
  @override
  String get deleteEverything => 'Удалить всё?';
  @override
  String get cannotUndo => 'Это действие нельзя отменить';
  @override
  String get historyCleared => 'История очищена';

  @override
  String get statsTitle => 'Статистика';
  @override
  String get todayLabel => 'Сегодня';
  @override
  String campaignsN(int n) => 'рассылок: $n';
  @override
  String get last7days => 'Последние 7 дней';
  @override
  String get totalSent => 'Всего отправлено';
  @override
  String successRate(int percent) => 'успешно $percent%';
  @override
  String get numbersInGroups => 'Номеров в группах';
  @override
  String groupsN(int n) => 'групп: $n';
  @override
  String get bySource => 'По источникам';
  @override
  String get noSentYet => 'Пока нет отправленных SMS';
  @override
  String get latestCampaigns => 'Последние рассылки';

  @override
  String get devicesTitle => 'Устройства';
  @override
  String get thisDevice => 'Это устройство';
  @override
  String deviceLine(String id, int sentToday) =>
      'ID $id · сегодня отправлено: $sentToday';
  @override
  String get simForSending => 'SIM для отправки';
  @override
  String get simSystemDefault => 'Системная по умолчанию';
  @override
  String get simSystemDefaultHint => 'Как выбрано в настройках телефона';
  @override
  String simSlot(int slot) => 'Слот $slot';
  @override
  String get simDefaultSms => 'SMS по умолчанию';
  @override
  String get simNotRead => 'SIM-карты не прочитаны: нужно разрешение «Телефон».';
  @override
  String get balance => 'Баланс';
  @override
  String approxSms(int n) => '≈ $n SMS';
  @override
  String get balanceNotChecked => 'Баланс ещё не проверялся';
  @override
  String balanceUpdated(String when) =>
      'Обновлено $when · после отправок уменьшается автоматически';
  @override
  String operatorReply(String text) => 'Ответ оператора: $text';
  @override
  String checkViaSms(String number) => 'Проверить (SMS на $number)';
  @override
  String get waitingReply => 'Ждём ответ…';
  @override
  String get balanceTmt => 'Баланс, TMT';
  @override
  String get forExample => 'Например 12.50';
  @override
  String get pricingTitle => 'Стоимость и запрос баланса';
  @override
  String get pricePerPart => 'Цена одной части SMS, TMT';
  @override
  String get priceHelper => '1 теңңе = 0.01 TMT; длинное SMS = несколько частей';
  @override
  String get requestNumber => 'Номер запроса баланса';
  @override
  String get requestText => 'Текст запроса';
  @override
  String get saved => 'Сохранено';
  @override
  String get otherDevices => 'Другие устройства';
  @override
  String get otherDevicesUnsupported =>
      'Сервер пока не поддерживает список устройств. Нужны эндпоинты GET /devices/ и POST /devices/heartbeat/ (описание в docs/DEVICES_API.md). После этого здесь появятся другие телефоны с их балансом и статистикой.';
  @override
  String get noOtherDevices => 'Других устройств пока нет';
  @override
  String get numberUnknown => 'номер неизвестен';
  @override
  String todaySms(int n) => 'сегодня: $n SMS';
  @override
  String get noServerConnection => 'Нет связи с сервером';
  @override
  String serverStatus(int status) => 'Сервер ответил $status';
  @override
  String get requestNotSent => 'Запрос не отправлен';
  @override
  String get noOperatorReply => 'Ответ от оператора не получен';

  @override
  String get addNumberTitle => 'Добавить номер';
  @override
  String get clientName => 'Имя клиента';
  @override
  String get enterNumber => 'Введите номер';
  @override
  String get switchMode => 'Сменить режим';
  @override
  String get modeManual => 'Режим: ручное добавление';
  @override
  String get modeContacts => 'Режим: из контактов';
  @override
  String get importContacts => 'Импорт контактов';
  @override
  String get pickFromContacts => 'Выбрать из контактов';
  @override
  String get noName => 'Без имени';
  @override
  String get invalidNumber => 'Неверный формат номера';
  @override
  String get numberExists => 'Этот номер уже добавлен';
  @override
  String maxNumbers(int max, int now) => 'Максимум $max номеров. Сейчас: $now';
  @override
  String get addingNumber => 'Добавление номера…';
  @override
  String get numberAdded => 'Номер добавлен';
  @override
  String get excelEmpty => 'Excel файл пустой';
  @override
  String get excelNoValid => 'В файле не найдено корректных номеров';
  @override
  String limitReached(int max) => 'Достигнут лимит $max';
  @override
  String importedN(int n) => 'Импортировано: $n';
  @override
  String importedSkipped(int n, int skipped) =>
      'Импортировано: $n · пропущено: $skipped';
  @override
  String get pickContacts => 'Выбери контакты';
  @override
  String get searchContact => 'Поиск контакта…';
  @override
  String selectedOf(int selected, int total) => 'Выбрано: $selected / $total';
  @override
  String get unselectAll => 'Снять все';
  @override
  String get nothingSelected => 'Ничего не выбрано';
  @override
  String get contactsAdded => 'Контакты добавлены';
  @override
  String get add => 'Добавить';
}
