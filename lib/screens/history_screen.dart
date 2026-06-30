import 'package:flutter/material.dart';

import '../widgets/history_tile.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Jun 14, 2026', '09:30 AM', 'Speech to Sign'),
      ('Jun 13, 2026', '07:10 PM', 'Sign to Speech'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return HistoryTile(date: item.$1, time: item.$2, type: item.$3);
      },
    );
  }
}
