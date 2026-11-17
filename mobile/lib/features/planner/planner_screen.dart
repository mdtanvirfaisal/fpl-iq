import 'package:flutter/material.dart';
import '../../models/squad.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';

class PlannerScreen extends StatefulWidget {
  final int managerId;

  const PlannerScreen({super.key, this.managerId = 1});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Simulator State
  SquadResponse? _squad;
  bool _loadingSquad = false;
  EnrichedSquadPlayer? _selectedPlayerOut;
  PlayerSummary? _selectedPlayerIn;
  String? _selectedChip; // "wildcard", "freehit", "3xc", "bboost"
  final int _freeTransfers = 1;
  TransferSimulationResult? _simResult;
  bool _simulating = false;

  // Search in Simulator
  final TextEditingController _searchInController = TextEditingController();
  List<PlayerSummary> _searchResults = [];
  bool _searchingIn = false;

  // Ticker State
  List<ClubFixtureTicker> _tickerList = [];
  bool _loadingTicker = false;

  // Market Trends State
  MarketTrendsResponse? _trends;
  bool _loadingTrends = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSquad();
    _loadTicker();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    setState(() => _loadingTrends = true);
    try {
      final res = await ApiService.getMarketTrends(limit: 8);
      setState(() {
        _trends = res;
        _loadingTrends = false;
      });
    } catch (_) {
      setState(() => _loadingTrends = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchInController.dispose();
    super.dispose();
  }

  Future<void> _loadSquad() async {
    setState(() => _loadingSquad = true);
    try {
      final res = await ApiService.getManagerSquad(widget.managerId);
      setState(() {
        _squad = res;
        _loadingSquad = false;
        if (res.startingXi.isNotEmpty) {
          _selectedPlayerOut = res.startingXi.first;
        }
      });
    } catch (_) {
      setState(() => _loadingSquad = false);
    }
  }

  Future<void> _loadTicker() async {
    setState(() => _loadingTicker = true);
    try {
      final res = await ApiService.getFixtureTicker(count: 5);
      setState(() {
        _tickerList = res;
        _loadingTicker = false;
      });
    } catch (_) {
      setState(() => _loadingTicker = false);
    }
  }

  Future<void> _searchIncomingPlayer(String q) async {
    if (q.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searchingIn = true);
    try {
      final res = await ApiService.searchPlayers(q);
      setState(() {
        _searchResults = res;
        _searchingIn = false;
      });
    } catch (_) {
      setState(() => _searchingIn = false);
    }
  }

  Future<void> _runSimulation() async {
    if (_selectedPlayerOut == null || _selectedPlayerIn == null) return;
    setState(() => _simulating = true);

    try {
      final res = await ApiService.simulateTransfers(
        managerId: widget.managerId,
        transfersOut: [_selectedPlayerOut!.player.id],
        transfersIn: [_selectedPlayerIn!.id],
        activeChip: _selectedChip,
        freeTransfers: _freeTransfers,
      );
      setState(() {
        _simResult = res;
        _simulating = false;
      });
    } catch (e) {
      setState(() {
        _simResult = TransferSimulationResult(
          valid: false,
          validationError: e.toString(),
          initialBank: 0,
          finalBank: 0,
          transfersCount: 1,
          pointsCost: 0,
          clubCounts: {},
          projectedPointsEstimate: 0,
          summaryText: 'Simulation error: $e',
        );
        _simulating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner & Chips', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.fplGreen,
          labelColor: AppTheme.fplGreen,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.swap_horiz), text: 'Transfers'),
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'FDR Ticker'),
            Tab(icon: Icon(Icons.trending_up), text: 'Market Trends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSimulatorTab(),
          _buildFixtureTickerTab(),
          _buildMarketTrendsTab(),
        ],
      ),
    );
  }

  Widget _buildSimulatorTab() {
    if (_loadingSquad) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.fplGreen));
    }

    if (_squad == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _loadSquad,
          icon: const Icon(Icons.refresh),
          label: const Text('Reload Squad'),
        ),
      );
    }

    final allSquadPlayers = _squad!.startingXi + _squad!.bench;
    final bank = _squad!.manager.lastDeadlineBank ?? 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bank & Free Transfer status banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.surfaceVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem('BANK BALANCE', '£${bank.toStringAsFixed(1)}m', AppTheme.fplGreen),
              _buildMetricItem('FREE TRANSFERS', '$_freeTransfers', AppTheme.fplCyan),
              _buildMetricItem('EXTRA HIT COST', '-4 pts', AppTheme.fplPink),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 1. Select Player to SELL
        const Text(
          '1. SELECT PLAYER TO SELL (OUT)',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<EnrichedSquadPlayer>(
          initialValue: _selectedPlayerOut,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.arrow_upward, color: AppTheme.fplPink),
            filled: true,
            fillColor: AppTheme.surface,
          ),
          dropdownColor: AppTheme.surface,
          items: allSquadPlayers.map((p) {
            return DropdownMenuItem<EnrichedSquadPlayer>(
              value: p,
              child: Text(
                '${p.player.webName} (${p.team.shortName} • ${p.player.positionName}) - £${p.player.nowCost}m',
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedPlayerOut = val;
              _simResult = null;
            });
          },
        ),
        const SizedBox(height: 18),

        // 2. Search & Select Player to BUY
        const Text(
          '2. SELECT PLAYER TO BUY (IN)',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchInController,
          decoration: InputDecoration(
            hintText: 'Search target player (e.g. Gabriel, Palmer)...',
            prefixIcon: const Icon(Icons.arrow_downward, color: AppTheme.fplGreen),
            suffixIcon: _searchInController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchInController.clear();
                      setState(() => _searchResults = []);
                    },
                  )
                : null,
          ),
          onChanged: _searchIncomingPlayer,
        ),
        if (_searchingIn)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: AppTheme.fplGreen),
          )
        else if (_searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surfaceVariant),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, idx) {
                final p = _searchResults[idx];
                final isSelected = _selectedPlayerIn?.id == p.id;
                return ListTile(
                  dense: true,
                  title: Text(p.webName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${p.positionName} • £${p.nowCost}m • Form: ${p.form}'),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppTheme.fplGreen)
                      : TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedPlayerIn = p;
                              _searchResults = [];
                              _searchInController.text = p.webName;
                              _simResult = null;
                            });
                          },
                          child: const Text('Select'),
                        ),
                );
              },
            ),
          ),
        const SizedBox(height: 18),

        // 3. Chip Simulation Selector
        const Text(
          '3. CHIP SIMULATION (OPTIONAL)',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildChipChoice(null, 'None'),
            _buildChipChoice('wildcard', 'Wildcard'),
            _buildChipChoice('freehit', 'Free Hit'),
            _buildChipChoice('3xc', 'Triple Captain'),
            _buildChipChoice('bboost', 'Bench Boost'),
          ],
        ),
        const SizedBox(height: 20),

        // Simulate Action Button
        ElevatedButton(
          onPressed: (_selectedPlayerOut != null && _selectedPlayerIn != null) ? _runSimulation : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.fplGreen,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _simulating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text(
                  'SIMULATE SCENARIO',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.1),
                ),
        ),
        const SizedBox(height: 18),

        // Simulation Outcome Banner
        if (_simResult != null) _buildSimulationResultCard(_simResult!),
      ],
    );
  }

  Widget _buildChipChoice(String? chipKey, String label) {
    final isSelected = _selectedChip == chipKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.fplPurple,
      backgroundColor: AppTheme.surfaceVariant,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.white70,
      ),
      onSelected: (sel) {
        setState(() {
          _selectedChip = sel ? chipKey : null;
          _simResult = null;
        });
      },
    );
  }

  Widget _buildSimulationResultCard(TransferSimulationResult res) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: res.valid
            ? AppTheme.fplGreen.withValues(alpha: 0.12)
            : AppTheme.fplPink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: res.valid ? AppTheme.fplGreen : AppTheme.fplPink,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                res.valid ? 'PLAN VIABLE' : 'RULE VIOLATION',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.1,
                  color: res.valid ? AppTheme.fplGreen : AppTheme.fplPink,
                ),
              ),
              if (res.valid)
                Text(
                  'Hit: ${res.pointsCost > 0 ? "-${res.pointsCost}" : "0"} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: res.pointsCost > 0 ? AppTheme.fplPink : AppTheme.fplGreen,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            res.valid ? res.summaryText : (res.validationError ?? res.summaryText),
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
          if (res.valid) ...[
            const Divider(height: 18, color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Final Bank: £${res.finalBank.toStringAsFixed(1)}m',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Est GW Score: ~${res.projectedPointsEstimate} pts',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.fplGreen),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixtureTickerTab() {
    if (_loadingTicker) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.fplGreen));
    }

    if (_tickerList.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _loadTicker,
          icon: const Icon(Icons.refresh),
          label: const Text('Load Fixture Ticker'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _tickerList.length,
      itemBuilder: (context, index) {
        final team = _tickerList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    team.teamName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: team.fixtures.map((fix) {
                      Color diffColor;
                      switch (fix.difficulty) {
                        case 1:
                        case 2:
                          diffColor = AppTheme.fplGreen;
                          break;
                        case 3:
                          diffColor = Colors.grey;
                          break;
                        case 4:
                          diffColor = Colors.orange;
                          break;
                        default:
                          diffColor = AppTheme.fplPink;
                      }

                      return Container(
                        width: 44,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: diffColor, width: 1),
                        ),
                        child: Column(
                          children: [
                            Text(
                              fix.opponentShortName,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              fix.isHome ? 'H' : 'A',
                              style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketTrendsTab() {
    if (_loadingTrends) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.fplGreen));
    }

    if (_trends == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _loadTrends,
          icon: const Icon(Icons.refresh),
          label: const Text('Load Market Trends'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Most Bought Header
        const Row(
          children: [
            Icon(Icons.trending_up, color: AppTheme.fplGreen, size: 18),
            SizedBox(width: 8),
            Text(
              'MOST TRANSFERRED IN (GW BUY TARGETS)',
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
        ..._trends!.mostTransferredIn.map((p) => _buildTrendTile(p, isBuy: true)),

        const SizedBox(height: 20),

        // Most Sold Header
        const Row(
          children: [
            Icon(Icons.trending_down, color: AppTheme.fplPink, size: 18),
            SizedBox(width: 8),
            Text(
              'MOST TRANSFERRED OUT (GW EXITS)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppTheme.fplPink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._trends!.mostTransferredOut.map((p) => _buildTrendTile(p, isBuy: false)),
      ],
    );
  }

  Widget _buildTrendTile(MarketTrendPlayer p, {required bool isBuy}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: isBuy
              ? AppTheme.fplGreen.withValues(alpha: 0.2)
              : AppTheme.fplPink.withValues(alpha: 0.2),
          child: Text(
            p.teamShortName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isBuy ? AppTheme.fplGreen : AppTheme.fplPink,
            ),
          ),
        ),
        title: Text(
          p.playerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text('${p.positionName} • £${p.nowCost}m • Form: ${p.form}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isBuy ? '+${p.transfersInEvent}' : '-${p.transfersOutEvent}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isBuy ? AppTheme.fplGreen : AppTheme.fplPink,
              ),
            ),
            Text(
              '${p.selectedByPercent}% owned',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
