import 'package:flutter_test/flutter_test.dart';
import 'package:fpl_iq/main.dart';
import 'package:fpl_iq/models/squad.dart';

void main() {
  testWidgets('FplIqApp smoke test loads title', (WidgetTester tester) async {
    await tester.pumpWidget(const FplIqApp());

    expect(find.text('FPL IQ'), findsOneWidget);
    expect(find.text('Command Centre'), findsOneWidget);
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
}
