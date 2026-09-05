import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../domain/user_profile.dart';
import 'auth_provider.dart';

/// "Leaderboards ... for ranked play" (Phase 9) — top players by
/// [UserProfile.rating]. See [FirestoreProfileRepository.watchLeaderboard]
/// for why anonymous guests are excluded.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.read<AuthProvider>();
    final String? myUid = auth.user?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: SafeArea(
        child: StreamBuilder<List<UserProfile>>(
          stream: auth.leaderboard(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Text(
                    'Could not load the leaderboard right now.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final List<UserProfile> players = snapshot.data ?? const <UserProfile>[];
            if (players.isEmpty) {
              return Center(
                child: Text(
                  'No ranked players yet — create an account and play an\nonline game to appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.sp, color: Colors.white70),
                ),
              );
            }
            return ListView.separated(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              itemCount: players.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final UserProfile p = players[index];
                final bool isMe = p.uid == myUid;
                return ListTile(
                  leading: SizedBox(
                    width: 32.w,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(p.avatarEmoji, style: TextStyle(fontSize: 18.sp)),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          p.displayName,
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.w800 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('You', style: TextStyle(fontSize: 10)),
                        ),
                    ],
                  ),
                  subtitle: Text('${p.gamesWon}W · ${p.gamesLost}L · ${p.gamesDrawn}D'),
                  trailing: Text(
                    '${p.rating}',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
