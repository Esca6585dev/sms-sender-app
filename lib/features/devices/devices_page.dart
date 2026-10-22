import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/devices/devices_controller.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/l10n/strings.dart';

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
    final s = S.of(context);
    final devices = ref.watch(devicesProvider);
    final balance = ref.watch(balanceProvider);
    final stats = ref.watch(campaignLogProvider).stats();
    final scheme = Theme.of(context).colorScheme;
    final t = AppStyleTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.devicesTitle),
        actions: [
          IconButton(
            tooltip: s.refresh,
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
          _Section(s.thisDevice),
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
                    s.deviceLine(
                      devices.deviceId.isEmpty ? s.none : devices.deviceId,
                      stats.sentToday,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.simForSending,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                _SimTile(
                  title: s.simSystemDefault,
                  subtitle: s.simSystemDefaultHint,
                  selected: balance.selectedSim == -1,
                  onTap: () => ref.read(balanceProvider.notifier).selectSim(-1),
                ),
                for (final sim in devices.sims)
                  _SimTile(
                    title: sim.label,
                    subtitle: '${s.simSlot(sim.slot + 1)}'
                        '${sim.isDefaultSms ? ' · ${s.simDefaultSms}' : ''}',
                    selected: balance.selectedSim == sim.subscriptionId,
                    onTap: () => ref
                        .read(balanceProvider.notifier)
                        .selectSim(sim.subscriptionId),
                  ),
                if (devices.sims.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      s.simNotRead,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(s.balance),
          _BalanceCard(balance: balance),
          const SizedBox(height: 14),
          _Section(s.pricingTitle),
          _PricingCard(settings: balance.settings),
          const SizedBox(height: 14),
          _Section(s.otherDevices),
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
    final s = S.of(context);
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
                  value == null ? s.none : formatManat(value),
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
                      s.approxSms(affordable),
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
                  ? s.balanceNotChecked
                  : s.balanceUpdated(DateFormatting.dateTime(balance.updatedAt!)),
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
                  s.operatorReply(balance.lastReply!),
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
                          ? s.waitingReply
                          : s.checkViaSms(balance.settings.requestNumber),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _enterManually(context, ref),
                  child: Text(s.manual),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterManually(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final controller = TextEditingController(
      text: balance.balance?.toStringAsFixed(2) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.balanceTmt),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: s.forExample),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(controller.text.trim().replaceAll(',', '.')),
            ),
            child: Text(s.save),
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
    final s = S.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: s.pricePerPart,
                helperText: s.priceHelper,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _number,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: s.requestNumber),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _text,
                    decoration: InputDecoration(labelText: s.requestText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _save,
                child: Text(s.save),
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
      SnackBar(content: Text(S.of(context).saved)),
    );
  }
}

class _OthersCard extends ConsumerWidget {
  const _OthersCard({required this.state});

  final DevicesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
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
          s.otherDevicesUnsupported,
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
              child: Text(s.retry),
            ),
          ],
        ),
      );
    } else if (state.others.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          s.noOtherDevices,
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
                '${d.number.isEmpty ? s.numberUnknown : d.number} · '
                '${s.todaySms(d.sentToday)}'
                '${d.lastSeen != null ? ' · ${DateFormatting.dateTime(d.lastSeen!)}' : ''}',
              ),
              trailing: Text(
                d.balance == null ? s.none : formatManat(d.balance!),
                style: TextStyle(fontWeight: FontWeight.w800, color: t.accent),
              ),
            ),
        ],
      );
    }

    return Card(child: body);
  }
}
