import 'package:flutter/material.dart';
import '../../models/squad.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<WatchlistPlayerItem> _watchlist = [];
  List<PlayerSummary> _searchResults = [];
  bool _loading = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() => _loading = true);
    try {
      final items = await ApiService.getWatchlist();
      setState(() {
        _watchlist = items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await ApiService.searchPlayers(query);
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  Future<void> _togglePlayer(PlayerSummary player) async {
    final isTracked = _watchlist.any((w) => w.player.id == player.id);
    if (isTracked) {
      await ApiService.removeFromWatchlist(player.id);
    } else {
      await ApiService.addToWatchlist(player.id);
    }
    _loadWatchlist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Watchlist', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWatchlist,
            tooltip: 'Refresh Watchlist',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search player to monitor...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.fplGreen),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
              ),
              onChanged: _onSearch,
            ),
          ),

          // Search results dropdown or Watchlist
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: AppTheme.fplGreen),
            )
          else if (_searchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SEARCH RESULTS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  TextButton(
                    onPressed: () => setState(() => _searchResults = []),
                    child: const Text('Close', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final p = _searchResults[index];
                  final isTracked = _watchlist.any((w) => w.player.id == p.id);
                  return ListTile(
                    dense: true,
                    title: Text('${p.firstName} ${p.secondName}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${p.positionName} • £${p.nowCost}m • Form: ${p.form}'),
                    trailing: IconButton(
                      icon: Icon(
                        isTracked ? Icons.check_circle : Icons.add_circle_outline,
                        color: isTracked ? AppTheme.fplGreen : Colors.grey,
                      ),
                      onPressed: () => _togglePlayer(p),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: AppTheme.surfaceVariant),
          ],

          // Watchlist Feed
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.fplGreen))
                : _watchlist.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.remove_red_eye_outlined, size: 48, color: Colors.grey[700]),
                            const SizedBox(height: 12),
                            const Text(
                              'No players on your watchlist',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Search and add players to monitor injuries, bonus, and rank impact.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _watchlist.length,
                        itemBuilder: (context, index) {
                          final item = _watchlist[index];
                          final p = item.player;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        item.team.shortName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              p.webName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                p.positionName,
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '£${p.nowCost}m • Owned: ${p.selectedByPercent}% • Form: ${p.form}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                        if (p.news != null && p.news!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            p.news!,
                                            style: const TextStyle(color: AppTheme.fplPink, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${p.totalPoints} PTS',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.fplGreen,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                        onPressed: () async {
                                          await ApiService.removeFromWatchlist(p.id);
                                          _loadWatchlist();
                                        },
                                      ),
                                    ],
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
