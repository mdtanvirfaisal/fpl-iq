import 'package:flutter/material.dart';
import '../../models/squad.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';

class LiveMatchCentreScreen extends StatefulWidget {
  const LiveMatchCentreScreen({super.key});

  @override
  State<LiveMatchCentreScreen> createState() => _LiveMatchCentreScreenState();
}

class _LiveMatchCentreScreenState extends State<LiveMatchCentreScreen> {
  Future<LiveMatchCenterResponse>? _matchesFuture;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  void _fetchMatches() {
    setState(() {
      _matchesFuture = ApiService.getLiveMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Match Centre', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMatches,
            tooltip: 'Refresh live matches',
          ),
        ],
      ),
      body: FutureBuilder<LiveMatchCenterResponse>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.fplGreen));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: AppTheme.fplPink, size: 48),
                    const SizedBox(height: 12),
                    const Text('Unable to load live matches',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchMatches,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final response = snapshot.data!;
          final matches = response.matches;

          if (matches.isEmpty) {
            return const Center(child: Text('No fixtures scheduled for this gameweek.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              return _MatchCard(match: matches[index]);
            },
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final FixtureMatch match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.started && !match.finished && !match.finishedProvisional;
    final isProvisional = match.finishedProvisional && !match.finished;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isLive ? AppTheme.fplGreen : AppTheme.surfaceVariant,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Header: Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppTheme.fplGreen.withValues(alpha: 0.2)
                        : isProvisional
                            ? Colors.orange.withValues(alpha: 0.2)
                            : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isLive
                          ? AppTheme.fplGreen
                          : isProvisional
                              ? Colors.orange
                              : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.fplGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        match.statusDisplay.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLive
                              ? AppTheme.fplGreen
                              : isProvisional
                                  ? Colors.orange
                                  : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'GW ${match.gameweek}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scoreline
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.homeTeam.name,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    match.started
                        ? '${match.homeScore ?? 0} - ${match.awayScore ?? 0}'
                        : 'VS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: match.started ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    match.awayTeam.name,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            // Key Events Timeline (Goals, Cards)
            if (match.events.isNotEmpty) ...[
              const Divider(height: 24, color: AppTheme.surfaceVariant),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: match.events.map((e) {
                  IconData icon;
                  Color iconColor;
                  switch (e.eventType) {
                    case 'goal':
                      icon = Icons.sports_soccer;
                      iconColor = AppTheme.fplGreen;
                      break;
                    case 'assist':
                      icon = Icons.handshake_outlined;
                      iconColor = AppTheme.fplCyan;
                      break;
                    case 'yellow_card':
                      icon = Icons.square;
                      iconColor = Colors.yellow;
                      break;
                    case 'red_card':
                      icon = Icons.square;
                      iconColor = Colors.red;
                      break;
                    default:
                      icon = Icons.fiber_manual_record;
                      iconColor = Colors.grey;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 12, color: iconColor),
                        const SizedBox(width: 4),
                        Text(
                          '${e.playerName}${e.count > 1 ? " x${e.count}" : ""}',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Provisional vs Confirmed Bonus Points (Section 7.2 LIVE-03)
            if (match.bonusCandidates.isNotEmpty) ...[
              const Divider(height: 20, color: AppTheme.surfaceVariant),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.stars,
                                size: 14,
                                color: match.bonusCandidates.first.isProvisional
                                    ? Colors.orange
                                    : AppTheme.fplGreen),
                            const SizedBox(width: 5),
                            Text(
                              match.bonusCandidates.first.isProvisional
                                  ? 'PROVISIONAL BONUS'
                                  : 'FINAL BONUS POINTS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: match.bonusCandidates.first.isProvisional
                                    ? Colors.orange
                                    : AppTheme.fplGreen,
                              ),
                            ),
                          ],
                        ),
                        if (match.bonusCandidates.first.isProvisional)
                          const Text(
                            'Estimated until confirmed',
                            style: TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: match.bonusCandidates.map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${c.playerName} +${c.bonusPoints}${c.bps > 0 ? " (${c.bps} BPS)" : ""}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
