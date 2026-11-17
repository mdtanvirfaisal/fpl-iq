import 'package:flutter/material.dart';
import '../../models/squad.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';

class LeaguesScreen extends StatefulWidget {
  final int managerId;

  const LeaguesScreen({super.key, this.managerId = 1});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  List<ClassicLeagueSummary> _leagues = [];
  ClassicLeagueSummary? _selectedLeague;
  LeagueStandingsResponse? _standings;
  bool _loadingLeagues = false;
  bool _loadingStandings = false;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    setState(() => _loadingLeagues = true);
    try {
      final list = await ApiService.getManagerLeagues(widget.managerId);
      setState(() {
        _leagues = list;
        _loadingLeagues = false;
        if (list.isNotEmpty) {
          _selectedLeague = list.first;
          _loadStandings(list.first.id);
        }
      });
    } catch (_) {
      setState(() => _loadingLeagues = false);
    }
  }

  Future<void> _loadStandings(int leagueId) async {
    setState(() => _loadingStandings = true);
    try {
      final resp = await ApiService.getLeagueStandings(leagueId);
      setState(() {
        _standings = resp;
        _loadingStandings = false;
      });
    } catch (_) {
      setState(() => _loadingStandings = false);
    }
  }

  void _showRivalComparison(LeagueStandingEntry rival) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RivalComparisonSheet(
        userManagerId: widget.managerId,
        rivalEntryId: rival.entryId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini-Leagues & Rivals', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedLeague != null) {
                _loadStandings(_selectedLeague!.id);
              } else {
                _loadLeagues();
              }
            },
            tooltip: 'Refresh Standings',
          ),
        ],
      ),
      body: _loadingLeagues
          ? const Center(child: CircularProgressIndicator(color: AppTheme.fplGreen))
          : _leagues.isEmpty
              ? const Center(child: Text('No mini-leagues found for this manager.'))
              : Column(
                  children: [
                    // League Selector Chips
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      color: AppTheme.surface,
                      child: SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _leagues.length,
                          itemBuilder: (context, index) {
                            final lg = _leagues[index];
                            final isSelected = _selectedLeague?.id == lg.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  lg.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.black : Colors.white70,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppTheme.fplGreen,
                                backgroundColor: AppTheme.surfaceVariant,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() => _selectedLeague = lg);
                                    _loadStandings(lg.id);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // League Standings List
                    Expanded(
                      child: _loadingStandings
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.fplGreen))
                          : _standings == null
                              ? const Center(child: Text('Unable to load standings.'))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _standings!.standings.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = _standings!.standings[index];
                                    final isUser = item.entryId == widget.managerId;

                                    return Card(
                                      color: isUser
                                          ? AppTheme.fplPurple.withValues(alpha: 0.5)
                                          : AppTheme.surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: isUser ? AppTheme.fplGreen : AppTheme.surfaceVariant,
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: item.rank <= 3
                                              ? AppTheme.fplGreen
                                              : AppTheme.surfaceVariant,
                                          foregroundColor: item.rank <= 3
                                              ? Colors.black
                                              : Colors.white,
                                          radius: 16,
                                          child: Text(
                                            '${item.rank}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        title: Text(
                                          item.entryName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isUser ? AppTheme.fplGreen : Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${item.playerName} • GW: ${item.eventTotal} pts',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${item.total}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (!isUser)
                                              IconButton(
                                                icon: const Icon(Icons.compare_arrows,
                                                    color: AppTheme.fplCyan, size: 20),
                                                tooltip: 'Compare Head-to-Head',
                                                onPressed: () => _showRivalComparison(item),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
    );
  }
}

class _RivalComparisonSheet extends StatefulWidget {
  final int userManagerId;
  final int rivalEntryId;

  const _RivalComparisonSheet({
    required this.userManagerId,
    required this.rivalEntryId,
  });

  @override
  State<_RivalComparisonSheet> createState() => _RivalComparisonSheetState();
}

class _RivalComparisonSheetState extends State<_RivalComparisonSheet> {
  Future<HeadToHeadComparison>? _comparisonFuture;

  @override
  void initState() {
    super.initState();
    _comparisonFuture = ApiService.compareWithRival(
      widget.userManagerId,
      widget.rivalEntryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HeadToHeadComparison>(
      future: _comparisonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 320,
            child: Center(child: CircularProgressIndicator(color: AppTheme.fplGreen)),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.fplPink, size: 40),
                const SizedBox(height: 10),
                const Text('Head-to-head comparison unavailable',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        }

        final comp = snapshot.data!;
        final isLeading = comp.gameweekPointsGap >= 0;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            shrinkWrap: true,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('HEAD-TO-HEAD RADAR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppTheme.fplGreen,
                      )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLeading
                          ? AppTheme.fplGreen.withValues(alpha: 0.2)
                          : AppTheme.fplPink.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'GW GAP: ${isLeading ? "+" : ""}${comp.gameweekPointsGap} PTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLeading ? AppTheme.fplGreen : AppTheme.fplPink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Matchup Card
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('YOU', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(comp.userTeamName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(comp.userPlayerName,
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('RIVAL', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(comp.rivalTeamName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(comp.rivalPlayerName,
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.surfaceVariant),

              // Summary Verdict Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  comp.summaryVerdict,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),

              // Captaincy Battle Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.fplPurple.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.fplPurple),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CAPTAINCY CLASH',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your C: ${comp.userCaptainName} (${comp.userCaptainPts} pts)',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fplGreen)),
                        Text('Rival C: ${comp.rivalCaptainName} (${comp.rivalCaptainPts} pts)',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fplCyan)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Your Differentials
              Text(
                'YOUR DIFFERENTIALS (${comp.userDifferentials.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.fplGreen),
              ),
              const SizedBox(height: 6),
              if (comp.userDifferentials.isEmpty)
                const Text('None (matched)', style: TextStyle(color: Colors.grey, fontSize: 12))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: comp.userDifferentials.map((p) {
                    return Chip(
                      label: Text('${p.player.webName} (${p.livePoints} pts)'),
                      backgroundColor: AppTheme.fplGreen.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(fontSize: 11, color: AppTheme.fplGreen),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),

              // Rival Differentials
              Text(
                'RIVAL DIFFERENTIALS (${comp.rivalDifferentials.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.fplPink),
              ),
              const SizedBox(height: 6),
              if (comp.rivalDifferentials.isEmpty)
                const Text('None (matched)', style: TextStyle(color: Colors.grey, fontSize: 12))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: comp.rivalDifferentials.map((p) {
                    return Chip(
                      label: Text('${p.player.webName} (${p.livePoints} pts)'),
                      backgroundColor: AppTheme.fplPink.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(fontSize: 11, color: AppTheme.fplPink),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
