import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../online_game_provider.dart';

/// Shows the opponent's name plus a live connection indicator — "Handle
/// disconnection and reconnection gracefully" (Phase 7) starts with the
/// player being able to *see* that the opponent has dropped, rather than
/// just staring at a board that stopped updating.
class OpponentBar extends StatelessWidget {
  const OpponentBar({super.key, required this.provider});

  final OnlineGameProvider provider;

  @override
  Widget build(BuildContext context) {
    final ConnectionStatus status = provider.connectionStatus;
    final (IconData icon, Color color, String label) = switch (status) {
      ConnectionStatus.connected => (Icons.circle, const Color(0xFF00C853), 'Connected'),
      ConnectionStatus.reconnecting => (Icons.sync, const Color(0xFFFFC107), 'Reconnecting…'),
      ConnectionStatus.opponentDisconnected => (
          Icons.circle,
          const Color(0xFFE53935),
          'Opponent disconnected',
        ),
    };

    return Row(
      children: [
        Icon(Icons.person_outline, size: 16.w, color: Colors.white54),
        SizedBox(width: 4.w),
        Text(provider.opponentName, style: TextStyle(fontSize: 13.sp)),
        SizedBox(width: 8.w),
        Icon(icon, size: 10.w, color: color),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontSize: 11.sp, color: color)),
      ],
    );
  }
}
