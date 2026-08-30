import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../online_game_provider.dart';

/// A dismiss-free banner across the top of the board while the opponent
/// looks disconnected — reassures the player the game isn't stuck, it's
/// specifically waiting on the other side to come back (see
/// `FirestoreMultiplayerRepository`'s reconnection notes for what
/// "reconnect" means in a Firestore-sync model: the stream just resumes
/// on its own, no explicit reconnect handshake needed).
class ReconnectBanner extends StatelessWidget {
  const ReconnectBanner({super.key, required this.provider});

  final OnlineGameProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.connectionStatus != ConnectionStatus.opponentDisconnected) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFFE53935),
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
      child: Text(
        '${provider.opponentName} appears to have disconnected — the clock keeps '
        'running, and the game will resume automatically if they return.',
        style: TextStyle(fontSize: 12.sp, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}
