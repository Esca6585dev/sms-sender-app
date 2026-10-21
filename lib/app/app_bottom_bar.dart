import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/app_shell.dart';
import 'package:sms_sender_app/app/theme.dart';

/// Bottom navigation drawn per design style: floating pill (Soft Glass),
/// navy bar with an indicator line (Bold Brand), hairline bar (Clean Mono)
/// or dark bar with a glowing dot (Dark Neon).
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = AppStyleTokens.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final items = Row(
      children: [
        for (final tab in AppTab.values)
          Expanded(
            child: _BarItem(
              tab: tab,
              selected: tab == current,
              tokens: t,
              onTap: () => onSelected(tab),
            ),
          ),
      ],
    );

    if (t.floatingNav) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: t.navBackground.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: items,
        ),
      );
    }

    final isBrand = t.style == AppStyle.boldBrand;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 6 + bottomInset),
      decoration: BoxDecoration(
        color: t.navBackground,
        borderRadius: isBrand
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : null,
        border: isBrand ? null : Border(top: BorderSide(color: t.cardBorder)),
      ),
      child: SizedBox(height: 60, child: items),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.tab,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final AppStyleTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final pill = t.floatingNav && selected;
    final color = pill ? t.onAccent : (selected ? t.navActive : t.navInactive);

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: pill ? t.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? tab.selectedIcon : tab.icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
              if (t.navGlow || t.style == AppStyle.boldBrand) ...[
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: t.navGlow ? 6 : 22,
                  height: t.navGlow ? 6 : 3,
                  decoration: BoxDecoration(
                    color: selected ? t.navActive : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: selected && t.navGlow
                        ? [BoxShadow(color: t.navActive, blurRadius: 10)]
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
