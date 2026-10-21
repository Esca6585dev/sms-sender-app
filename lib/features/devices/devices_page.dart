import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/devices/devices_controller.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';

/// This phone (SIM choice, balance, SMS price) and the other phones that
/// report to the same backend.
class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final devices = ref.read(devicesProvider.notifier);
      devices.refreshLocal();
      devices.refreshRemote();
    });
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final balance = ref.watch(balanceProvider);
    final stats = ref.watch(campaignLogProvider).stats();
    final scheme = Theme.of(context).colorScheme;
    final t = AppStyleTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Устройства'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(devicesProvider.notifier).refreshLocal();
              ref.read(devicesProvider.notifier).refreshRemote();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          _Section('Это устройство'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.smartphone, color: t.accent),
                  title: Text(
                    devices.deviceName.isEmpty ? 'Android' : devices.deviceName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'ID ${devices.deviceId.isEmpty ? '—' : devices.deviceId} · '
                    'сегодня отправлено: ${stats.sentToday}',
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SIM для отправки',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                _SimTile(
                  title: 'Системная по умолчанию',
                  subtitle: 'Как выбрано в настройках телефона',
                  selected: balance.selectedSim == -1,
                  onTap: () => ref.read(balanceProvider.notifier).selectSim(-1),
                ),
                for (final sim in devices.sims)
                  _SimTile(
                    title: sim.label,
                    subtitle: 'Слот ${sim.slot + 1}'
                        '${sim.isDefaultSms ? ' · SMS по умолчанию' : ''}',
                    selected: balance.selectedSim == sim.subscriptionId,
                    onTap: () => ref
                        .read(balanceProvider.notifier)
                        .selectSim(sim.subscriptionId),
                  ),
                if (devices.sims.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      'SIM-карты не прочитаны: нужно разрешение «Телефон».',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section('Баланс'),
          _BalanceCard(balance: balance),
          const SizedBox(height: 14),
          _Section('Стоимость и запрос баланса'),
          _PricingCard(settings: balance.settings),
          const SizedBox(height: 14),
          _Section('Другие устройства'),
          _OthersCard(state: devices),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SimTile extends StatelessWidget {
  const _SimTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      selected: selected,
      onTap: onTap,
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.balance});

  final BalanceState balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppStyleTokens.of(context);
    final value = balance.balance;
    final affordable = balance.affordableSms;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value == null ? '—' : formatManat(value),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: value != null && value <= 0 ? t.danger : t.accent,
                  ),
                ),
                const SizedBox(width: 10),
                if (affordable != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '≈ $affordable SMS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              balance.updatedAt == null
                  ? 'Баланс ещё не проверялся'
                  : 'Обновлено ${DateFormatting.dateTime(balance.updatedAt!)}'
                      ' · после отправок уменьшается автоматически',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (balance.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  balance.error!,
                  style: TextStyle(fontSize: 12, color: t.danger),
                ),
              ),
            if (balance.lastReply != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Ответ оператора: ${balance.lastReply}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: balance.isChecking
                        ? null
                        : () => ref.read(balanceProvider.notifier).checkViaSms(),
                    icon: balance.isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sms_outlined, size: 18),
                    label: Text(
                      balance.isChecking
                          ? 'Ждём ответ…'
                          : 'Проверить (SMS на ${balance.settings.requestNumber})',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _enterManually(context, ref),
                  child: const Text('Вручную'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterManually(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: balance.balance?.toStringAsFixed(2) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Баланс, TMT'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Например 12.50'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(controller.text.trim().replaceAll(',', '.')),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value != null) {
      await ref.read(balanceProvider.notifier).setManual(value);
    }
  }
}

class _PricingCard extends ConsumerStatefulWidget {
  const _PricingCard({required this.settings});

  final BalanceSettings settings;

  @override
  ConsumerState<_PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends ConsumerState<_PricingCard> {
  late final TextEditingController _price;
  late final TextEditingController _number;
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: widget.settings.pricePerPart.toStringAsFixed(2),
    );
    _number = TextEditingController(text: widget.settings.requestNumber);
    _text = TextEditingController(text: widget.settings.requestText);
  }

  @override
  void dispose() {
    _price.dispose();
    _number.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Цена одной части SMS, TMT',
                helperText: '1 теңңе = 0.01 TMT; длинное SMS = несколько частей',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _number,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Номер запроса баланса',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _text,
                    decoration: const InputDecoration(labelText: 'Текст запроса'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _save,
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(balanceProvider.notifier);
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (price != null && price > 0) await notifier.setPrice(price);
    await notifier.setRequest(
      number: _number.text.trim(),
      text: _text.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сохранено')),
    );
  }
}

class _OthersCard extends ConsumerWidget {
  const _OthersCard({required this.state});

  final DevicesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppStyleTokens.of(context);

    Widget body;
    if (state.isLoading) {
      body = const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (state.remoteSupported == false) {
      body = Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Сервер пока не поддерживает список устройств. Нужны эндпоинты '
          'GET /devices/ и POST /devices/heartbeat/ (описание в docs/DEVICES_API.md). '
          'После этого здесь появятся другие телефоны с их балансом и статистикой.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    } else if (state.error != null) {
      body = Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Text(state.error!, style: TextStyle(color: t.danger)),
            ),
            TextButton(
              onPressed: () => ref.read(devicesProvider.notifier).refreshRemote(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    } else if (state.others.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Других устройств пока нет',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      body = Column(
        children: [
          for (final d in state.others)
            ListTile(
              leading: Icon(Icons.phone_android, color: t.accent),
              title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${d.number.isEmpty ? 'номер неизвестен' : d.number} · '
                'сегодня: ${d.sentToday} SMS'
                '${d.lastSeen != null ? ' · ${DateFormatting.dateTime(d.lastSeen!)}' : ''}',
              ),
              trailing: Text(
                d.balance == null ? '—' : formatManat(d.balance!),
                style: TextStyle(fontWeight: FontWeight.w800, color: t.accent),
              ),
            ),
        ],
      );
    }

    return Card(child: body);
  }
}
