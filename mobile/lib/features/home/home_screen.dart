import 'package:flutter/material.dart';
import '../../models/squad.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';
import '../squad/squad_pitch_view.dart';
import '../notifications/notification_screen.dart';
import '../watchlist/watchlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _managerIdController = TextEditingController(text: '1');
  Future<SquadResponse>? _squadFuture;
  int _currentManagerId = 1;

  @override
  void initState() {
    super.initState();
    _loadSquad();
  }

  void _loadSquad() {
    final id = int.tryParse(_managerIdController.text.trim()) ?? 1;
    setState(() {
      _currentManagerId = id;
      _squadFuture = ApiService.getManagerSquad(_currentManagerId);
    });
  }

  void _showServerSettingsDialog() {
    final serverController = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.dns, color: AppTheme.fplCyan, size: 20),
            SizedBox(width: 8),
            Text('Backend Server URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the address of your backend server running on your PC:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: serverController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'e.g. http://192.168.1.15:8000/api/v1',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: For physical Android phones, use your computer\'s Wi-Fi IP (e.g. http://192.168.x.x:8000/api/v1).',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newUrl = serverController.text.trim();
              if (newUrl.isNotEmpty) {
                ApiService.baseUrl = newUrl;
                _loadSquad();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  void _showPlayerDetailModal(EnrichedSquadPlayer squadPlayer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PlayerRankImpactSheet(squadPlayer: squadPlayer),
    );
  }

  void _showOcrImportDialog() {
    final textController = TextEditingController();
    OcrSquadImportResponse? result;
    bool parsing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Row(
              children: [
                Icon(Icons.document_scanner, color: AppTheme.fplCyan, size: 20),
                SizedBox(width: 8),
                Text('Screenshot OCR Import', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste extracted OCR text from your FPL team screenshot:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'e.g.\nRaya\nGabriel Saliba Pedro Porro\nPalmer (C) Saka Groß Mitoma\nHaaland Barry',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: parsing
                          ? null
                          : () async {
                              setDialogState(() => parsing = true);
                              try {
                                final res = await ApiService.importSquadFromOcr(textController.text);
                                setDialogState(() {
                                  result = res;
                                  parsing = false;
                                });
                              } catch (_) {
                                setDialogState(() => parsing = false);
                              }
                            },
                      child: parsing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Parse & Propose Squad'),
                    ),
                    if (result != null) ...[
                      const Divider(height: 20, color: AppTheme.surfaceVariant),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Detected: ${result!.totalDetected}/15', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(result!.success ? 'Valid Proposal' : 'Incomplete', style: TextStyle(color: result!.success ? AppTheme.fplGreen : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Starting XI (${result!.startingXi.length}):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.fplGreen)),
                      Wrap(
                        spacing: 4,
                        children: result!.startingXi.map((p) => Chip(
                          label: Text('${p.matchedName}${p.isCaptain ? " (C)" : ""}', style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        )).toList(),
                      ),
                      if (result!.bench.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Bench (${result!.bench.length}):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Wrap(
                          spacing: 4,
                          children: result!.bench.map((p) => Chip(
                            label: Text(p.matchedName, style: const TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          )).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.fplGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'FPL IQ',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Command Centre',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WatchlistScreen()),
              );
            },
            tooltip: 'Watchlist',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
            tooltip: 'Alert Feed',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: _showServerSettingsDialog,
            tooltip: 'Server Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSquad,
            tooltip: 'Refresh live points',
          ),
        ],
      ),
      body: Column(
        children: [
          // Manager ID bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _managerIdController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'FPL Manager ID',
                      labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      prefixIcon: const Icon(Icons.person_search, color: AppTheme.fplGreen, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _loadSquad(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loadSquad,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.fplPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.fplGreen, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  child: const Text('Load', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.document_scanner, color: AppTheme.fplCyan),
                  onPressed: _showOcrImportDialog,
                  tooltip: 'Screenshot OCR Import',
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: FutureBuilder<SquadResponse>(
              future: _squadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.fplGreen),
                        SizedBox(height: 16),
                        Text('Fetching team & live match data...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.fplPink, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load squad',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadSquad,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final squad = snapshot.data!;
                return ListView(
                  children: [
                    // Gameweek & Manager Summary Header
                    _buildSummaryHeader(squad),

                    // Pitch Visualizer
                    SquadPitchView(
                      squad: squad,
                      onPlayerSelected: _showPlayerDetailModal,
                    ),

                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(SquadResponse squad) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      squad.manager.teamName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${squad.manager.playerName} • ID: ${squad.manager.id}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.fplPurple,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.fplGreen.withValues(alpha: 0.6)),
                ),
                child: Text(
                  'GW ${squad.gameweek}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.fplGreen,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.surfaceVariant),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(
                label: 'GW POINTS',
                value: '${squad.gameweekPoints}',
                color: AppTheme.fplGreen,
              ),
              _buildStatMetric(
                label: 'OVERALL RANK',
                value: squad.manager.overallRank != null
                    ? squad.manager.overallRank.toString()
                    : '-',
                color: AppTheme.fplCyan,
              ),
              _buildStatMetric(
                label: 'TOTAL PTS',
                value: squad.manager.overallPoints != null
                    ? squad.manager.overallPoints.toString()
                    : '-',
                color: Colors.white,
              ),
              _buildStatMetric(
                label: 'CHIP',
                value: squad.activeChip?.toUpperCase() ?? 'NONE',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class PlayerRankImpactSheet extends StatefulWidget {
  final EnrichedSquadPlayer squadPlayer;

  const PlayerRankImpactSheet({super.key, required this.squadPlayer});

  @override
  State<PlayerRankImpactSheet> createState() => _PlayerRankImpactSheetState();
}

class _PlayerRankImpactSheetState extends State<PlayerRankImpactSheet> {
  double _cohortEO = 45.0;
  RankImpactResult? _impactResult;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    // Use player selected_by_percent as initial baseline EO
    _cohortEO = widget.squadPlayer.player.selectedByPercent;
    _runRankCalculation();
  }

  Future<void> _runRankCalculation() async {
    setState(() => _calculating = true);
    try {
      final res = await ApiService.evaluateRankImpact(
        playerId: widget.squadPlayer.player.id,
        playerName: widget.squadPlayer.player.webName,
        points: widget.squadPlayer.livePoints > 0
            ? widget.squadPlayer.livePoints
            : widget.squadPlayer.player.eventPoints,
        userMultiplier: widget.squadPlayer.pick.multiplier,
        cohortEffectiveOwnership: _cohortEO,
      );
      setState(() {
        _impactResult = res;
        _calculating = false;
      });
    } catch (_) {
      setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.squadPlayer.player;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Club
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${player.firstName} ${player.secondName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.squadPlayer.team.name} • ${player.positionName} • £${player.nowCost}m',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.squadPlayer.livePoints} PTS',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.fplGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // News / Status notice if present
          if (player.news != null && player.news!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.fplPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.fplPink.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.fplPink, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      player.news!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Rank Impact Intelligence Section (PRD Section 7.3)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: AppTheme.fplGreen, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'RANK IMPACT INTELLIGENCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppTheme.fplGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Simulate relative points swing against rank cohort (Top 100k):',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Cohort EO: ${_cohortEO.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: _cohortEO,
                        min: 0.0,
                        max: 200.0,
                        divisions: 40,
                        activeColor: AppTheme.fplGreen,
                        onChanged: (val) {
                          setState(() => _cohortEO = val);
                        },
                        onChangeEnd: (_) => _runRankCalculation(),
                      ),
                    ),
                  ],
                ),

                if (_calculating)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(color: AppTheme.fplGreen),
                  )
                else if (_impactResult != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _impactResult!.relativePointsSwing > 0
                          ? AppTheme.fplGreen.withValues(alpha: 0.15)
                          : _impactResult!.relativePointsSwing < 0
                              ? AppTheme.fplPink.withValues(alpha: 0.15)
                              : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Relative Points Swing: ${_impactResult!.relativePointsSwing > 0 ? "+" : ""}${_impactResult!.relativePointsSwing} pts',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _impactResult!.relativePointsSwing >= 0
                                    ? AppTheme.fplGreen
                                    : AppTheme.fplPink,
                              ),
                            ),
                            Text(
                              _impactResult!.confidenceLevel,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _impactResult!.summaryText,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
