class PlayerSummary {
  final int id;
  final String webName;
  final String firstName;
  final String secondName;
  final int teamId;
  final int elementType;
  final String positionName;
  final double nowCost;
  final String status;
  final int totalPoints;
  final double selectedByPercent;
  final double form;
  final int eventPoints;
  final String? news;

  PlayerSummary({
    required this.id,
    required this.webName,
    required this.firstName,
    required this.secondName,
    required this.teamId,
    required this.elementType,
    required this.positionName,
    required this.nowCost,
    required this.status,
    required this.totalPoints,
    required this.selectedByPercent,
    required this.form,
    required this.eventPoints,
    this.news,
  });

  factory PlayerSummary.fromJson(Map<String, dynamic> json) {
    return PlayerSummary(
      id: json['id'] as int,
      webName: json['web_name'] as String,
      firstName: json['first_name'] as String,
      secondName: json['second_name'] as String,
      teamId: json['team_id'] as int,
      elementType: json['element_type'] as int,
      positionName: json['position_name'] as String,
      nowCost: (json['now_cost'] as num).toDouble(),
      status: json['status'] as String? ?? 'a',
      totalPoints: json['total_points'] as int? ?? 0,
      selectedByPercent: (json['selected_by_percent'] as num).toDouble(),
      form: (json['form'] as num).toDouble(),
      eventPoints: json['event_points'] as int? ?? 0,
      news: json['news'] as String?,
    );
  }
}

class TeamSummary {
  final int id;
  final String name;
  final String shortName;
  final int strength;

  TeamSummary({
    required this.id,
    required this.name,
    required this.shortName,
    required this.strength,
  });

  factory TeamSummary.fromJson(Map<String, dynamic> json) {
    return TeamSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      shortName: json['short_name'] as String,
      strength: json['strength'] as int? ?? 3,
    );
  }
}

class SquadPick {
  final int elementId;
  final int position;
  final int multiplier;
  final bool isCaptain;
  final bool isViceCaptain;

  SquadPick({
    required this.elementId,
    required this.position,
    required this.multiplier,
    required this.isCaptain,
    required this.isViceCaptain,
  });

  factory SquadPick.fromJson(Map<String, dynamic> json) {
    return SquadPick(
      elementId: json['element_id'] as int,
      position: json['position'] as int,
      multiplier: json['multiplier'] as int,
      isCaptain: json['is_captain'] as bool,
      isViceCaptain: json['is_vice_captain'] as bool,
    );
  }
}

class EnrichedSquadPlayer {
  final PlayerSummary player;
  final TeamSummary team;
  final SquadPick pick;
  final int livePoints;
  final bool isStarter;

  EnrichedSquadPlayer({
    required this.player,
    required this.team,
    required this.pick,
    required this.livePoints,
    required this.isStarter,
  });

  factory EnrichedSquadPlayer.fromJson(Map<String, dynamic> json) {
    return EnrichedSquadPlayer(
      player: PlayerSummary.fromJson(json['player'] as Map<String, dynamic>),
      team: TeamSummary.fromJson(json['team'] as Map<String, dynamic>),
      pick: SquadPick.fromJson(json['pick'] as Map<String, dynamic>),
      livePoints: json['live_points'] as int? ?? 0,
      isStarter: json['is_starter'] as bool? ?? true,
    );
  }
}

class ManagerProfile {
  final int id;
  final String playerName;
  final String teamName;
  final String? region;
  final int? overallPoints;
  final int? overallRank;
  final double? lastDeadlineBank;
  final double? lastDeadlineValue;

  ManagerProfile({
    required this.id,
    required this.playerName,
    required this.teamName,
    this.region,
    this.overallPoints,
    this.overallRank,
    this.lastDeadlineBank,
    this.lastDeadlineValue,
  });

  factory ManagerProfile.fromJson(Map<String, dynamic> json) {
    return ManagerProfile(
      id: json['id'] as int,
      playerName: json['player_name'] as String,
      teamName: json['team_name'] as String,
      region: json['region'] as String?,
      overallPoints: json['overall_points'] as int?,
      overallRank: json['overall_rank'] as int?,
      lastDeadlineBank: (json['last_deadline_bank'] as num?)?.toDouble(),
      lastDeadlineValue: (json['last_deadline_value'] as num?)?.toDouble(),
    );
  }
}

class SquadResponse {
  final ManagerProfile manager;
  final int gameweek;
  final String? activeChip;
  final List<EnrichedSquadPlayer> startingXi;
  final List<EnrichedSquadPlayer> bench;
  final int gameweekPoints;
  final bool isLive;
  final String dataFreshnessTs;

  SquadResponse({
    required this.manager,
    required this.gameweek,
    this.activeChip,
    required this.startingXi,
    required this.bench,
    required this.gameweekPoints,
    required this.isLive,
    required this.dataFreshnessTs,
  });

  factory SquadResponse.fromJson(Map<String, dynamic> json) {
    return SquadResponse(
      manager: ManagerProfile.fromJson(json['manager'] as Map<String, dynamic>),
      gameweek: json['gameweek'] as int,
      activeChip: json['active_chip'] as String?,
      startingXi: (json['starting_xi'] as List<dynamic>)
          .map((e) => EnrichedSquadPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      bench: (json['bench'] as List<dynamic>)
          .map((e) => EnrichedSquadPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      gameweekPoints: json['gameweek_points'] as int? ?? 0,
      isLive: json['is_live'] as bool? ?? false,
      dataFreshnessTs: json['data_freshness_ts'] as String? ?? '',
    );
  }
}

class RankImpactResult {
  final int playerId;
  final String playerName;
  final int points;
  final double userEffectiveOwnership;
  final double cohortEffectiveOwnership;
  final double netExposure;
  final double relativePointsSwing;
  final String impactCategory;
  final String summaryText;
  final bool provisional;
  final String confidenceLevel;

  RankImpactResult({
    required this.playerId,
    required this.playerName,
    required this.points,
    required this.userEffectiveOwnership,
    required this.cohortEffectiveOwnership,
    required this.netExposure,
    required this.relativePointsSwing,
    required this.impactCategory,
    required this.summaryText,
    required this.provisional,
    required this.confidenceLevel,
  });

  factory RankImpactResult.fromJson(Map<String, dynamic> json) {
    return RankImpactResult(
      playerId: json['player_id'] as int,
      playerName: json['player_name'] as String,
      points: json['points'] as int,
      userEffectiveOwnership: (json['user_effective_ownership'] as num).toDouble(),
      cohortEffectiveOwnership: (json['cohort_effective_ownership'] as num).toDouble(),
      netExposure: (json['net_exposure'] as num).toDouble(),
      relativePointsSwing: (json['relative_points_swing'] as num).toDouble(),
      impactCategory: json['impact_category'] as String,
      summaryText: json['summary_text'] as String,
      provisional: json['provisional'] as bool? ?? false,
      confidenceLevel: json['confidence_level'] as String? ?? 'Estimated',
    );
  }
}


class MatchEvent {
  final String eventType;
  final int elementId;
  final String playerName;
  final String teamShortName;
  final bool isHome;
  final int count;

  MatchEvent({
    required this.eventType,
    required this.elementId,
    required this.playerName,
    required this.teamShortName,
    required this.isHome,
    required this.count,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    return MatchEvent(
      eventType: json['event_type'] as String,
      elementId: json['element_id'] as int,
      playerName: json['player_name'] as String,
      teamShortName: json['team_short_name'] as String,
      isHome: json['is_home'] as bool,
      count: json['count'] as int? ?? 1,
    );
  }
}

class BonusSummary {
  final int elementId;
  final String playerName;
  final int bps;
  final int bonusPoints;
  final bool isProvisional;
  final bool isHome;

  BonusSummary({
    required this.elementId,
    required this.playerName,
    required this.bps,
    required this.bonusPoints,
    required this.isProvisional,
    required this.isHome,
  });

  factory BonusSummary.fromJson(Map<String, dynamic> json) {
    return BonusSummary(
      elementId: json['element_id'] as int,
      playerName: json['player_name'] as String,
      bps: json['bps'] as int,
      bonusPoints: json['bonus_points'] as int,
      isProvisional: json['is_provisional'] as bool,
      isHome: json['is_home'] as bool,
    );
  }
}

class FixtureMatch {
  final int id;
  final int gameweek;
  final String kickoffTime;
  final bool started;
  final bool finished;
  final bool finishedProvisional;
  final int minutes;
  final TeamSummary homeTeam;
  final TeamSummary awayTeam;
  final int? homeScore;
  final int? awayScore;
  final List<MatchEvent> events;
  final List<BonusSummary> bonusCandidates;
  final String statusDisplay;

  FixtureMatch({
    required this.id,
    required this.gameweek,
    required this.kickoffTime,
    required this.started,
    required this.finished,
    required this.finishedProvisional,
    required this.minutes,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    required this.events,
    required this.bonusCandidates,
    required this.statusDisplay,
  });

  factory FixtureMatch.fromJson(Map<String, dynamic> json) {
    return FixtureMatch(
      id: json['id'] as int,
      gameweek: json['gameweek'] as int,
      kickoffTime: json['kickoff_time'] as String? ?? '',
      started: json['started'] as bool? ?? false,
      finished: json['finished'] as bool? ?? false,
      finishedProvisional: json['finished_provisional'] as bool? ?? false,
      minutes: json['minutes'] as int? ?? 0,
      homeTeam: TeamSummary.fromJson(json['home_team'] as Map<String, dynamic>),
      awayTeam: TeamSummary.fromJson(json['away_team'] as Map<String, dynamic>),
      homeScore: json['home_score'] as int?,
      awayScore: json['away_score'] as int?,
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => MatchEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      bonusCandidates: (json['bonus_candidates'] as List<dynamic>? ?? [])
          .map((e) => BonusSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      statusDisplay: json['status_display'] as String? ?? 'Upcoming',
    );
  }
}

class LiveMatchCenterResponse {
  final int gameweek;
  final List<FixtureMatch> matches;
  final String dataFreshnessTs;

  LiveMatchCenterResponse({
    required this.gameweek,
    required this.matches,
    required this.dataFreshnessTs,
  });

  factory LiveMatchCenterResponse.fromJson(Map<String, dynamic> json) {
    return LiveMatchCenterResponse(
      gameweek: json['gameweek'] as int,
      matches: (json['matches'] as List<dynamic>)
          .map((e) => FixtureMatch.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataFreshnessTs: json['data_freshness_ts'] as String? ?? '',
    );
  }
}

class WatchlistPlayerItem {
  final PlayerSummary player;
  final TeamSummary team;
  final String addedAt;

  WatchlistPlayerItem({
    required this.player,
    required this.team,
    required this.addedAt,
  });

  factory WatchlistPlayerItem.fromJson(Map<String, dynamic> json) {
    return WatchlistPlayerItem(
      player: PlayerSummary.fromJson(json['player'] as Map<String, dynamic>),
      team: TeamSummary.fromJson(json['team'] as Map<String, dynamic>),
      addedAt: json['added_at'] as String? ?? '',
    );
  }
}


class ClassicLeagueSummary {
  final int id;
  final String name;
  final int? entryRank;
  final int? entryLastRank;
  final String leagueType;

  ClassicLeagueSummary({
    required this.id,
    required this.name,
    this.entryRank,
    this.entryLastRank,
    required this.leagueType,
  });

  factory ClassicLeagueSummary.fromJson(Map<String, dynamic> json) {
    return ClassicLeagueSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      entryRank: json['entry_rank'] as int?,
      entryLastRank: json['entry_last_rank'] as int?,
      leagueType: json['league_type'] as String? ?? 'x',
    );
  }
}

class LeagueStandingEntry {
  final int entryId;
  final String entryName;
  final String playerName;
  final int rank;
  final int? lastRank;
  final int eventTotal;
  final int total;

  LeagueStandingEntry({
    required this.entryId,
    required this.entryName,
    required this.playerName,
    required this.rank,
    this.lastRank,
    required this.eventTotal,
    required this.total,
  });

  factory LeagueStandingEntry.fromJson(Map<String, dynamic> json) {
    return LeagueStandingEntry(
      entryId: json['entry_id'] as int,
      entryName: json['entry_name'] as String,
      playerName: json['player_name'] as String,
      rank: json['rank'] as int,
      lastRank: json['last_rank'] as int?,
      eventTotal: json['event_total'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }
}

class LeagueStandingsResponse {
  final int leagueId;
  final String leagueName;
  final List<LeagueStandingEntry> standings;

  LeagueStandingsResponse({
    required this.leagueId,
    required this.leagueName,
    required this.standings,
  });

  factory LeagueStandingsResponse.fromJson(Map<String, dynamic> json) {
    return LeagueStandingsResponse(
      leagueId: json['league_id'] as int,
      leagueName: json['league_name'] as String,
      standings: (json['standings'] as List<dynamic>)
          .map((e) => LeagueStandingEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HeadToHeadComparison {
  final int userManagerId;
  final String userTeamName;
  final String userPlayerName;
  final int rivalManagerId;
  final String rivalTeamName;
  final String rivalPlayerName;
  final int gameweek;
  final int overallPointsGap;
  final int gameweekPointsGap;
  final String userCaptainName;
  final int userCaptainMultiplier;
  final int userCaptainPts;
  final String rivalCaptainName;
  final int rivalCaptainMultiplier;
  final int rivalCaptainPts;
  final int captainPointsDelta;
  final List<EnrichedSquadPlayer> userDifferentials;
  final List<EnrichedSquadPlayer> rivalDifferentials;
  final List<EnrichedSquadPlayer> sharedPlayers;
  final String summaryVerdict;

  HeadToHeadComparison({
    required this.userManagerId,
    required this.userTeamName,
    required this.userPlayerName,
    required this.rivalManagerId,
    required this.rivalTeamName,
    required this.rivalPlayerName,
    required this.gameweek,
    required this.overallPointsGap,
    required this.gameweekPointsGap,
    required this.userCaptainName,
    required this.userCaptainMultiplier,
    required this.userCaptainPts,
    required this.rivalCaptainName,
    required this.rivalCaptainMultiplier,
    required this.rivalCaptainPts,
    required this.captainPointsDelta,
    required this.userDifferentials,
    required this.rivalDifferentials,
    required this.sharedPlayers,
    required this.summaryVerdict,
  });

  factory HeadToHeadComparison.fromJson(Map<String, dynamic> json) {
    return HeadToHeadComparison(
      userManagerId: json['user_manager_id'] as int,
      userTeamName: json['user_team_name'] as String,
      userPlayerName: json['user_player_name'] as String,
      rivalManagerId: json['rival_manager_id'] as int,
      rivalTeamName: json['rival_team_name'] as String,
      rivalPlayerName: json['rival_player_name'] as String,
      gameweek: json['gameweek'] as int,
      overallPointsGap: json['overall_points_gap'] as int,
      gameweekPointsGap: json['gameweek_points_gap'] as int,
      userCaptainName: json['user_captain_name'] as String,
      userCaptainMultiplier: json['user_captain_multiplier'] as int,
      userCaptainPts: json['user_captain_pts'] as int,
      rivalCaptainName: json['rival_captain_name'] as String,
      rivalCaptainMultiplier: json['rival_captain_multiplier'] as int,
      rivalCaptainPts: json['rival_captain_pts'] as int,
      captainPointsDelta: json['captain_points_delta'] as int,
      userDifferentials: (json['user_differentials'] as List<dynamic>)
          .map((e) => EnrichedSquadPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      rivalDifferentials: (json['rival_differentials'] as List<dynamic>)
          .map((e) => EnrichedSquadPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      sharedPlayers: (json['shared_players'] as List<dynamic>)
          .map((e) => EnrichedSquadPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      summaryVerdict: json['summary_verdict'] as String,
    );
  }
}


class ClubFixtureTickerItem {
  final int gameweek;
  final int opponentId;
  final String opponentShortName;
  final bool isHome;
  final int difficulty;

  ClubFixtureTickerItem({
    required this.gameweek,
    required this.opponentId,
    required this.opponentShortName,
    required this.isHome,
    required this.difficulty,
  });

  factory ClubFixtureTickerItem.fromJson(Map<String, dynamic> json) {
    return ClubFixtureTickerItem(
      gameweek: json['gameweek'] as int,
      opponentId: json['opponent_id'] as int,
      opponentShortName: json['opponent_short_name'] as String,
      isHome: json['is_home'] as bool,
      difficulty: json['difficulty'] as int,
    );
  }
}

class ClubFixtureTicker {
  final int teamId;
  final String teamName;
  final String teamShortName;
  final List<ClubFixtureTickerItem> fixtures;

  ClubFixtureTicker({
    required this.teamId,
    required this.teamName,
    required this.teamShortName,
    required this.fixtures,
  });

  factory ClubFixtureTicker.fromJson(Map<String, dynamic> json) {
    return ClubFixtureTicker(
      teamId: json['team_id'] as int,
      teamName: json['team_name'] as String,
      teamShortName: json['team_short_name'] as String,
      fixtures: (json['fixtures'] as List<dynamic>)
          .map((e) => ClubFixtureTickerItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TransferSimulationResult {
  final bool valid;
  final String? validationError;
  final double initialBank;
  final double finalBank;
  final int transfersCount;
  final int pointsCost;
  final String? activeChip;
  final Map<String, int> clubCounts;
  final int projectedPointsEstimate;
  final String summaryText;

  TransferSimulationResult({
    required this.valid,
    this.validationError,
    required this.initialBank,
    required this.finalBank,
    required this.transfersCount,
    required this.pointsCost,
    this.activeChip,
    required this.clubCounts,
    required this.projectedPointsEstimate,
    required this.summaryText,
  });

  factory TransferSimulationResult.fromJson(Map<String, dynamic> json) {
    return TransferSimulationResult(
      valid: json['valid'] as bool,
      validationError: json['validation_error'] as String?,
      initialBank: (json['initial_bank'] as num).toDouble(),
      finalBank: (json['final_bank'] as num).toDouble(),
      transfersCount: json['transfers_count'] as int,
      pointsCost: json['points_cost'] as int,
      activeChip: json['active_chip'] as String?,
      clubCounts: (json['club_counts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      projectedPointsEstimate: json['projected_points_estimate'] as int,
      summaryText: json['summary_text'] as String,
    );
  }
}


class InjuryNewsItem {
  final int playerId;
  final String playerName;
  final String teamName;
  final String teamShortName;
  final String positionName;
  final String status;
  final String statusLabel;
  final String news;
  final String? newsAdded;
  final int? chanceOfPlaying;

  InjuryNewsItem({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.teamShortName,
    required this.positionName,
    required this.status,
    required this.statusLabel,
    required this.news,
    this.newsAdded,
    this.chanceOfPlaying,
  });

  factory InjuryNewsItem.fromJson(Map<String, dynamic> json) {
    return InjuryNewsItem(
      playerId: json['player_id'] as int,
      playerName: json['player_name'] as String,
      teamName: json['team_name'] as String,
      teamShortName: json['team_short_name'] as String,
      positionName: json['position_name'] as String,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      news: json['news'] as String? ?? 'No details provided',
      newsAdded: json['news_added'] as String?,
      chanceOfPlaying: json['chance_of_playing'] as int?,
    );
  }
}

class MarketTrendPlayer {
  final int playerId;
  final String playerName;
  final String teamShortName;
  final String positionName;
  final double nowCost;
  final int transfersInEvent;
  final int transfersOutEvent;
  final int netTransfersEvent;
  final double selectedByPercent;
  final double form;

  MarketTrendPlayer({
    required this.playerId,
    required this.playerName,
    required this.teamShortName,
    required this.positionName,
    required this.nowCost,
    required this.transfersInEvent,
    required this.transfersOutEvent,
    required this.netTransfersEvent,
    required this.selectedByPercent,
    required this.form,
  });

  factory MarketTrendPlayer.fromJson(Map<String, dynamic> json) {
    return MarketTrendPlayer(
      playerId: json['player_id'] as int,
      playerName: json['player_name'] as String,
      teamShortName: json['team_short_name'] as String,
      positionName: json['position_name'] as String,
      nowCost: (json['now_cost'] as num).toDouble(),
      transfersInEvent: json['transfers_in_event'] as int,
      transfersOutEvent: json['transfers_out_event'] as int,
      netTransfersEvent: json['net_transfers_event'] as int,
      selectedByPercent: (json['selected_by_percent'] as num).toDouble(),
      form: (json['form'] as num).toDouble(),
    );
  }
}

class MarketTrendsResponse {
  final List<MarketTrendPlayer> mostTransferredIn;
  final List<MarketTrendPlayer> mostTransferredOut;
  final String dataFreshnessTs;

  MarketTrendsResponse({
    required this.mostTransferredIn,
    required this.mostTransferredOut,
    required this.dataFreshnessTs,
  });

  factory MarketTrendsResponse.fromJson(Map<String, dynamic> json) {
    return MarketTrendsResponse(
      mostTransferredIn: (json['most_transferred_in'] as List<dynamic>)
          .map((e) => MarketTrendPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      mostTransferredOut: (json['most_transferred_out'] as List<dynamic>)
          .map((e) => MarketTrendPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataFreshnessTs: json['data_freshness_ts'] as String? ?? '',
    );
  }
}

class NotificationItem {
  final String id;
  final String priority;
  final String category;
  final String title;
  final String body;
  final String timestamp;
  final bool read;
  final String? deepLink;

  NotificationItem({
    required this.id,
    required this.priority,
    required this.category,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.read,
    this.deepLink,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      priority: json['priority'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: json['timestamp'] as String,
      read: json['read'] as bool? ?? false,
      deepLink: json['deep_link'] as String?,
    );
  }
}

class NotificationSettings {
  final bool enablePlayerEvents;
  final bool enableRankImpact;
  final bool enableInjuries;
  final bool enableTransfers;
  final bool enableDeadline;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;

  NotificationSettings({
    this.enablePlayerEvents = true,
    this.enableRankImpact = true,
    this.enableInjuries = true,
    this.enableTransfers = true,
    this.enableDeadline = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '23:00',
    this.quietHoursEnd = '07:00',
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enablePlayerEvents: json['enable_player_events'] as bool? ?? true,
      enableRankImpact: json['enable_rank_impact'] as bool? ?? true,
      enableInjuries: json['enable_injuries'] as bool? ?? true,
      enableTransfers: json['enable_transfers'] as bool? ?? true,
      enableDeadline: json['enable_deadline'] as bool? ?? true,
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart: json['quiet_hours_start'] as String? ?? '23:00',
      quietHoursEnd: json['quiet_hours_end'] as String? ?? '07:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable_player_events': enablePlayerEvents,
      'enable_rank_impact': enableRankImpact,
      'enable_injuries': enableInjuries,
      'enable_transfers': enableTransfers,
      'enable_deadline': enableDeadline,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
    };
  }
}


class AdvisorRecommendationItem {
  final String title;
  final String category;
  final String confidence;
  final String rationale;
  final List<String> playerNames;
  final String tradeOffs;

  AdvisorRecommendationItem({
    required this.title,
    required this.category,
    required this.confidence,
    required this.rationale,
    required this.playerNames,
    required this.tradeOffs,
  });

  factory AdvisorRecommendationItem.fromJson(Map<String, dynamic> json) {
    return AdvisorRecommendationItem(
      title: json['title'] as String,
      category: json['category'] as String,
      confidence: json['confidence'] as String,
      rationale: json['rationale'] as String,
      playerNames: (json['player_names'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      tradeOffs: json['trade_offs'] as String? ?? '',
    );
  }
}

class AdvisorResponse {
  final int managerId;
  final String teamName;
  final int squadHealthScore;
  final String primaryCaptainRecommendation;
  final String viceCaptainRecommendation;
  final List<AdvisorRecommendationItem> recommendations;
  final List<String> groundedFactsUsed;
  final String disclaimer;

  AdvisorResponse({
    required this.managerId,
    required this.teamName,
    required this.squadHealthScore,
    required this.primaryCaptainRecommendation,
    required this.viceCaptainRecommendation,
    required this.recommendations,
    required this.groundedFactsUsed,
    required this.disclaimer,
  });

  factory AdvisorResponse.fromJson(Map<String, dynamic> json) {
    return AdvisorResponse(
      managerId: json['manager_id'] as int,
      teamName: json['team_name'] as String,
      squadHealthScore: json['squad_health_score'] as int,
      primaryCaptainRecommendation: json['primary_captain_recommendation'] as String,
      viceCaptainRecommendation: json['vice_captain_recommendation'] as String,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => AdvisorRecommendationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      groundedFactsUsed: (json['grounded_facts_used'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}


class OcrDetectedPlayer {
  final int playerId;
  final String matchedName;
  final String detectedToken;
  final String positionName;
  final int elementType;
  final String teamShortName;
  final double nowCost;
  final double confidence;
  final bool isCaptain;
  final bool isViceCaptain;
  final bool isStarter;

  OcrDetectedPlayer({
    required this.playerId,
    required this.matchedName,
    required this.detectedToken,
    required this.positionName,
    required this.elementType,
    required this.teamShortName,
    required this.nowCost,
    required this.confidence,
    required this.isCaptain,
    required this.isViceCaptain,
    required this.isStarter,
  });

  factory OcrDetectedPlayer.fromJson(Map<String, dynamic> json) {
    return OcrDetectedPlayer(
      playerId: json['player_id'] as int,
      matchedName: json['matched_name'] as String,
      detectedToken: json['detected_token'] as String,
      positionName: json['position_name'] as String,
      elementType: json['element_type'] as int,
      teamShortName: json['team_short_name'] as String,
      nowCost: (json['now_cost'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      isCaptain: json['is_captain'] as bool? ?? false,
      isViceCaptain: json['is_vice_captain'] as bool? ?? false,
      isStarter: json['is_starter'] as bool? ?? true,
    );
  }
}

class OcrSquadImportResponse {
  final bool success;
  final int totalDetected;
  final List<OcrDetectedPlayer> startingXi;
  final List<OcrDetectedPlayer> bench;
  final int missingCount;
  final List<String> warnings;
  final int rawTokensProcessed;

  OcrSquadImportResponse({
    required this.success,
    required this.totalDetected,
    required this.startingXi,
    required this.bench,
    required this.missingCount,
    required this.warnings,
    required this.rawTokensProcessed,
  });

  factory OcrSquadImportResponse.fromJson(Map<String, dynamic> json) {
    return OcrSquadImportResponse(
      success: json['success'] as bool,
      totalDetected: json['total_detected'] as int,
      startingXi: (json['starting_xi'] as List<dynamic>)
          .map((e) => OcrDetectedPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      bench: (json['bench'] as List<dynamic>)
          .map((e) => OcrDetectedPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      missingCount: json['missing_count'] as int? ?? 0,
      warnings: (json['warnings'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      rawTokensProcessed: json['raw_tokens_processed'] as int? ?? 0,
    );
  }
}
