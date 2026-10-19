import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/glass_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';

/// "Lock after" chips. Shows only while App lock is switched on.
/// Put it right under the App lock switch in Settings > Security.
class LockTimeoutPicker extends StatelessWidget {
  const LockTimeoutPicker({super.key});

  static const _options = <(int, String)>[
    (0, 'Instantly'),
    (15, '15 sec'),
    (20, '20 sec'),
    (30, '30 sec'),
    (60, '1 min'),
    (300, '5 min'),
  ];

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (!st.settings.appLock) return const SizedBox.shrink();
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lock after leaving the app',
            style: TextStyle(color: g.text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in _options)
            GlassChip(
              label: o.$2,
              selected: st.settings.lockTimeoutSeconds == o.$1,
              onTap: () => st.updateSettings((x) => x.lockTimeoutSeconds = o.$1,
                  resched: false),
            ),
        ]),
      ]),
    );
  }
}
