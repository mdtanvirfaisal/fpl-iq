import 'package:flutter/material.dart';
import '../../models/squad.dart';
import '../../core/theme.dart';

class SquadPitchView extends StatelessWidget {
  final SquadResponse squad;
  final Function(EnrichedSquadPlayer player) onPlayerSelected;

  const SquadPitchView({
    super.key,
    required this.squad,
    required this.onPlayerSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Group starting XI by position: GKP (1), DEF (2), MID (3), FWD (4)
    final gkps = squad.startingXi.where((p) => p.player.elementType == 1).toList();
    final defs = squad.startingXi.where((p) => p.player.elementType == 2).toList();
    final mids = squad.startingXi.where((p) => p.player.elementType == 3).toList();
    final fwds = squad.startingXi.where((p) => p.player.elementType == 4).toList();

    return Column(
      children: [
        // Pitch Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3B25), Color(0xFF1B5E39), Color(0xFF0F3B25)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.pitchLine, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Pitch lines overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: PitchLinesPainter(),
                ),
              ),
              // Players layout
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPlayerRow(gkps),
                    const SizedBox(height: 14),
                    _buildPlayerRow(defs),
                    const SizedBox(height: 14),
                    _buildPlayerRow(mids),
                    const SizedBox(height: 14),
                    _buildPlayerRow(fwds),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bench Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.event_seat_outlined, size: 16, color: Colors.grey),
                  SizedBox(width: 6),
                  Text(
                    'BENCH & SUBSTITUTES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: squad.bench.map((p) {
                  return _buildPlayerItem(p, isBench: true);
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerRow(List<EnrichedSquadPlayer> players) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: players.map((p) => _buildPlayerItem(p)).toList(),
    );
  }

  Widget _buildPlayerItem(EnrichedSquadPlayer squadPlayer, {bool isBench = false}) {
    final player = squadPlayer.player;
    final pick = squadPlayer.pick;

    return GestureDetector(
      onTap: () => onPlayerSelected(squadPlayer),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shirt / Avatar with Captain Badge
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBench ? const Color(0xFF2C3E50) : const Color(0xFF1E293B),
                    border: Border.all(
                      color: pick.isCaptain
                          ? AppTheme.fplGreen
                          : pick.isViceCaptain
                              ? AppTheme.fplCyan
                              : Colors.white24,
                      width: pick.isCaptain || pick.isViceCaptain ? 2.5 : 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      squadPlayer.team.shortName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Captain / Vice badge
                if (pick.isCaptain)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.fplGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pick.multiplier == 3 ? 'TC' : 'C',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  )
                else if (pick.isViceCaptain)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.fplCyan,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'V',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                // Injury / status indicator
                if (player.status != 'a')
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: player.status == 'i' || player.status == 's'
                            ? AppTheme.fplPink
                            : Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Player name banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isBench ? const Color(0xFF22272E) : const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                player.webName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Points Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (squadPlayer.livePoints * (pick.multiplier > 0 ? pick.multiplier : 1)) >= 8
                    ? AppTheme.fplGreen.withValues(alpha: 0.25)
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${squadPlayer.livePoints * (pick.multiplier > 0 ? pick.multiplier : 1)} pts',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: (squadPlayer.livePoints * (pick.multiplier > 0 ? pick.multiplier : 1)) >= 8
                      ? AppTheme.fplGreen
                      : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PitchLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.pitchLine.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Halfway line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Center circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      35,
      paint,
    );

    // Top penalty box
    canvas.drawRect(
      Rect.fromLTWH((size.width - 140) / 2, 0, 140, 50),
      paint,
    );

    // Bottom penalty box
    canvas.drawRect(
      Rect.fromLTWH((size.width - 140) / 2, size.height - 50, 140, 50),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
