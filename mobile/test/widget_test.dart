import 'package:flutter_test/flutter_test.dart';
import 'package:fpl_iq/main.dart';
import 'package:fpl_iq/models/squad.dart';

void main() {
  testWidgets('FplIqApp smoke test loads navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const FplIqApp());

    expect(find.text('Squad Pitch'), findsOneWidget);
    expect(find.text('Live Matches'), findsOneWidget);
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
    expect(match.awayScore, 1);
    expect(match.events.length, 1);
    expect(match.events[0].playerName, 'Barry');
    expect(match.bonusCandidates.length, 1);
    expect(match.bonusCandidates[0].bonusPoints, 3);
    expect(match.bonusCandidates[0].isProvisional, true);
  });
}
