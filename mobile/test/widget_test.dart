import 'package:flutter_test/flutter_test.dart';
import 'package:fpl_iq/main.dart';
import 'package:fpl_iq/models/squad.dart';

void main() {
  testWidgets('FplIqApp smoke test loads all 5 navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const FplIqApp());

    expect(find.text('Squad'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Planner'), findsOneWidget);
    expect(find.text('Leagues'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
  });

  test('RankImpactResult JSON deserialization', () {
    final json = {
      'player_id': 101,
      'player_name': 'Saka',
      'points': 10,
      'user_effective_ownership': 100.0,
      'cohort_effective_ownership': 40.0,
      'net_exposure': 60.0,
      'relative_points_swing': 6.0,
      'impact_category': 'significantly_positive',
      'summary_text': 'Boosted rank',
      'provisional': false,
      'confidence_level': 'Estimated',
    };

    final result = RankImpactResult.fromJson(json);
    expect(result.playerName, 'Saka');
    expect(result.relativePointsSwing, 6.0);
    expect(result.impactCategory, 'significantly_positive');
  });

  test('FixtureMatch and BonusSummary JSON deserialization', () {
    final json = {
      'id': 94,
      'gameweek': 10,
      'kickoff_time': '2026-11-06T20:00:00Z',
      'started': true,
      'finished': false,
      'finished_provisional': true,
      'minutes': 90,
      'home_team': {'id': 9, 'name': 'Everton', 'short_name': 'EVE', 'strength': 3},
      'away_team': {'id': 7, 'name': 'Coventry City', 'short_name': 'COV', 'strength': 3},
      'home_score': 3,
      'away_score': 1,
      'events': [
        {
          'event_type': 'goal',
          'element_id': 249,
          'player_name': 'Barry',
          'team_short_name': 'EVE',
          'is_home': true,
          'count': 2
        }
      ],
      'bonus_candidates': [
        {
          'element_id': 249,
          'player_name': 'Barry',
          'bps': 59,
          'bonus_points': 3,
          'is_provisional': true,
          'is_home': true
        }
      ],
      'status_display': 'FT (Provisional Bonus)'
    };

    final match = FixtureMatch.fromJson(json);
    expect(match.id, 94);
    expect(match.homeScore, 3);
    expect(match.events.length, 1);
    expect(match.bonusCandidates.length, 1);
    expect(match.bonusCandidates[0].bonusPoints, 3);
  });

  test('HeadToHeadComparison JSON deserialization', () {
    final json = {
      'user_manager_id': 1,
      'user_team_name': 'Team Alpha',
      'user_player_name': 'Manager One',
      'rival_manager_id': 2,
      'rival_team_name': 'Team Beta',
      'rival_player_name': 'Manager Two',
      'gameweek': 10,
      'overall_points_gap': 25,
      'gameweek_points_gap': 6,
      'user_captain_name': 'Haaland',
      'user_captain_multiplier': 2,
      'user_captain_pts': 16,
      'rival_captain_name': 'Salah',
      'rival_captain_multiplier': 2,
      'rival_captain_pts': 10,
      'captain_points_delta': 6,
      'user_differentials': [],
      'rival_differentials': [],
      'shared_players': [],
      'summary_verdict': 'Leading by +6 pts in GW10.'
    };

    final comp = HeadToHeadComparison.fromJson(json);
    expect(comp.userManagerId, 1);
    expect(comp.overallPointsGap, 25);
    expect(comp.gameweekPointsGap, 6);
  });

  test('ClubFixtureTicker and TransferSimulationResult deserialization', () {
    final tickerJson = {
      'team_id': 1,
      'team_name': 'Arsenal',
      'team_short_name': 'ARS',
      'fixtures': [
        {
          'gameweek': 11,
          'opponent_id': 6,
          'opponent_short_name': 'CHE',
          'is_home': false,
          'difficulty': 4
        }
      ]
    };
    final ticker = ClubFixtureTicker.fromJson(tickerJson);
    expect(ticker.teamShortName, 'ARS');
    expect(ticker.fixtures.length, 1);
    expect(ticker.fixtures[0].difficulty, 4);

    final simJson = {
      'valid': true,
      'validation_error': null,
      'initial_bank': 1.5,
      'final_bank': 0.8,
      'transfers_count': 1,
      'points_cost': 0,
      'active_chip': 'wildcard',
      'club_counts': {'ARS': 3},
      'projected_points_estimate': 58,
      'summary_text': 'Valid plan'
    };
    final sim = TransferSimulationResult.fromJson(simJson);
    expect(sim.valid, true);
    expect(sim.finalBank, 0.8);
    expect(sim.activeChip, 'wildcard');
    expect(sim.pointsCost, 0);
  });
}
