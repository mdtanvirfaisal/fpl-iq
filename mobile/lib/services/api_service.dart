import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/squad.dart';

class ApiService {
  // Allow overriding baseUrl (e.g. 10.0.2.2 for Android emulator, localhost for desktop/web)
  static String baseUrl = 'http://127.0.0.1:8000/api/v1';

  static Future<SquadResponse> getManagerSquad(int managerId, {int? gameweek}) async {
    final gwParam = gameweek != null ? '?gameweek=$gameweek' : '';
    final uri = Uri.parse('$baseUrl/manager/$managerId/squad$gwParam');

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SquadResponse.fromJson(data);
    } else {
      throw Exception('Failed to load squad: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  static Future<RankImpactResult> evaluateRankImpact({
    required int playerId,
    required String playerName,
    required int points,
    required int userMultiplier,
    required double cohortEffectiveOwnership,
    String cohortName = 'Overall Top 100k',
    String? rivalName,
    int? rivalMultiplier,
  }) async {
    final uri = Uri.parse('$baseUrl/rank/impact');
    final payload = {
      'player_id': playerId,
      'player_name': playerName,
      'points': points,
      'user_multiplier': userMultiplier,
      'cohort_effective_ownership': cohortEffectiveOwnership,
      'cohort_name': cohortName,
      ...?rivalName != null ? {'rival_name': rivalName} : null,
      ...?rivalMultiplier != null ? {'rival_multiplier': rivalMultiplier} : null,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return RankImpactResult.fromJson(data);
    } else {
      throw Exception('Failed to evaluate rank impact: HTTP ${response.statusCode}');
    }
  }

  static Future<LiveMatchCenterResponse> getLiveMatches({int? gameweek}) async {
    final gwParam = gameweek != null ? '?gameweek=$gameweek' : '';
    final uri = Uri.parse('$baseUrl/live/matches$gwParam');

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return LiveMatchCenterResponse.fromJson(data);
    } else {
      throw Exception('Failed to load live matches: HTTP ${response.statusCode}');
    }
  }

  static Future<List<PlayerSummary>> searchPlayers(String query) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.parse('$baseUrl/players/search?q=${Uri.encodeComponent(query)}');

    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((e) => PlayerSummary.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Player search failed: HTTP ${response.statusCode}');
    }
  }

  static Future<List<WatchlistPlayerItem>> getWatchlist() async {
    final uri = Uri.parse('$baseUrl/watchlist');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((e) => WatchlistPlayerItem.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch watchlist: HTTP ${response.statusCode}');
    }
  }

  static Future<void> addToWatchlist(int playerId) async {
    final uri = Uri.parse('$baseUrl/watchlist/$playerId');
    final response = await http.post(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Failed to add to watchlist: HTTP ${response.statusCode}');
    }
  }

  static Future<void> removeFromWatchlist(int playerId) async {
    final uri = Uri.parse('$baseUrl/watchlist/$playerId');
    final response = await http.delete(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Failed to remove from watchlist: HTTP ${response.statusCode}');
    }
  }

  static Future<List<ClassicLeagueSummary>> getManagerLeagues(int managerId) async {
    final uri = Uri.parse('$baseUrl/manager/$managerId/leagues');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((e) => ClassicLeagueSummary.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load manager leagues: HTTP ${response.statusCode}');
    }
  }

  static Future<LeagueStandingsResponse> getLeagueStandings(int leagueId) async {
    final uri = Uri.parse('$baseUrl/leagues/$leagueId/standings');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return LeagueStandingsResponse.fromJson(data);
    } else {
      throw Exception('Failed to load league standings: HTTP ${response.statusCode}');
    }
  }

  static Future<HeadToHeadComparison> compareWithRival(
    int managerId,
    int rivalId, {
    int? gameweek,
  }) async {
    final gwParam = gameweek != null ? '?gameweek=$gameweek' : '';
    final uri = Uri.parse('$baseUrl/manager/$managerId/rival/$rivalId/compare$gwParam');
    final response = await http.get(uri).timeout(const Duration(seconds: 14));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return HeadToHeadComparison.fromJson(data);
    } else {
      throw Exception('Failed to compare with rival: HTTP ${response.statusCode}');
    }
  }

  static Future<List<ClubFixtureTicker>> getFixtureTicker({
    int? startGw,
    int count = 5,
  }) async {
    final queryParams = [
      if (startGw != null) 'start_gw=$startGw',
      'count=$count',
    ].join('&');

    final uri = Uri.parse('$baseUrl/fixtures/ticker?$queryParams');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((e) => ClubFixtureTicker.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load fixture ticker: HTTP ${response.statusCode}');
    }
  }

  static Future<TransferSimulationResult> simulateTransfers({
    required int managerId,
    int? gameweek,
    required List<int> transfersOut,
    required List<int> transfersIn,
    String? activeChip,
    int freeTransfers = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/planner/simulate');
    final payload = {
      'manager_id': managerId,
      ...?gameweek != null ? {'gameweek': gameweek} : null,
      'transfers_out': transfersOut,
      'transfers_in': transfersIn,
      ...?activeChip != null ? {'active_chip': activeChip} : null,
      'free_transfers': freeTransfers,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return TransferSimulationResult.fromJson(data);
    } else {
      throw Exception('Failed to simulate transfers: HTTP ${response.statusCode}');
    }
  }

  static Future<List<InjuryNewsItem>> getInjuries({int? managerId}) async {
    final query = managerId != null ? '?manager_id=$managerId' : '';
    final uri = Uri.parse('$baseUrl/injuries$query');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((e) => InjuryNewsItem.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load injuries: HTTP ${response.statusCode}');
    }
  }

  static Future<MarketTrendsResponse> getMarketTrends({int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/market/trends?limit=$limit');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return MarketTrendsResponse.fromJson(data);
    } else {
      throw Exception('Failed to load market trends: HTTP ${response.statusCode}');
    }
  }

  static Future<List<NotificationItem>> getNotifications() async {
    final uri = Uri.parse('$baseUrl/notifications');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load notifications: HTTP ${response.statusCode}');
    }
  }

  static Future<void> markNotificationRead(String id) async {
    final uri = Uri.parse('$baseUrl/notifications/$id/read');
    await http.post(uri).timeout(const Duration(seconds: 6));
  }

  static Future<NotificationSettings> getNotificationSettings() async {
    final uri = Uri.parse('$baseUrl/notifications/settings');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return NotificationSettings.fromJson(data);
    } else {
      throw Exception('Failed to load notification settings: HTTP ${response.statusCode}');
    }
  }

  static Future<NotificationSettings> updateNotificationSettings(NotificationSettings settings) async {
    final uri = Uri.parse('$baseUrl/notifications/settings');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(settings.toJson()),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return NotificationSettings.fromJson(data);
    } else {
      throw Exception('Failed to update notification settings: HTTP ${response.statusCode}');
    }
  }

  static Future<AdvisorResponse> getAdvisorAnalysis(
    int managerId, {
    int? gameweek,
    String? query,
    String focusArea = 'general',
  }) async {
    final uri = Uri.parse('$baseUrl/advisor/analyze');
    final payload = {
      'manager_id': managerId,
      ...?gameweek != null ? {'gameweek': gameweek} : null,
      ...?query != null ? {'query': query} : null,
      'focus_area': focusArea,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 14));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return AdvisorResponse.fromJson(data);
    } else {
      throw Exception('Failed to load AI advisor analysis: HTTP ${response.statusCode}');
    }
  }

  static Future<OcrSquadImportResponse> importSquadFromOcr(String ocrText) async {
    final uri = Uri.parse('$baseUrl/squad/import/ocr');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'ocr_text': ocrText}),
    ).timeout(const Duration(seconds: 14));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return OcrSquadImportResponse.fromJson(data);
    } else {
      throw Exception('OCR squad import failed: HTTP ${response.statusCode}');
    }
  }
}
