import 'package:flutter/material.dart';
import '../../models/squad.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';

class AiAdvisorScreen extends StatefulWidget {
  final int managerId;

  const AiAdvisorScreen({super.key, this.managerId = 1});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  AdvisorResponse? _advisorData;
  bool _loading = false;
  String _selectedFocus = 'general';

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis({String focus = 'general'}) async {
    setState(() {
      _loading = true;
      _selectedFocus = focus;
    });

    try {
      final res = await ApiService.getAdvisorAnalysis(
        widget.managerId,
        focusArea: focus,
      );
      setState(() {
        _advisorData = res;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.fplGreen, size: 20),
            SizedBox(width: 8),
            Text('AI FPL Advisor', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAnalysis(focus: _selectedFocus),
            tooltip: 'Rerun Analysis',
          ),
        ],
      ),
      body: Column(
        children: [
          // Focus Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppTheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFocusChip('general', 'All Insights'),
                  const SizedBox(width: 8),
                  _buildFocusChip('captaincy', 'Captaincy'),
                  const SizedBox(width: 8),
                  _buildFocusChip('transfers', 'Transfer Moves'),
                  const SizedBox(width: 8),
                  _buildFocusChip('audit', 'Squad Audit'),
                ],
              ),
            ),
          ),

          // Main Advisor Content
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.fplGreen),
                        SizedBox(height: 14),
                        Text(
                          'Evaluating form, fixtures, ownership & squad health...',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : _advisorData == null
                    ? Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _loadAnalysis(focus: _selectedFocus),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Analyze Squad'),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          // Health Score & Captaincy Overview Card
                          _buildExecutiveSummaryCard(_advisorData!),
                          const SizedBox(height: 16),

                          // Recommendations List
                          const Text(
                            'TACTICAL RECOMMENDATIONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._advisorData!.recommendations.map(_buildRecommendationCard),

                          const SizedBox(height: 18),

                          // Grounded Evidence & Verification Section
                          _buildGroundedFactsCard(_advisorData!),
                          const SizedBox(height: 14),

                          // Guardrail Disclaimer (PRD Section 7.10)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                _advisorData!.disclaimer,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusChip(String focusKey, String label) {
    final isSelected = _selectedFocus == focusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.fplGreen,
      backgroundColor: AppTheme.surfaceVariant,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.black : Colors.white70,
      ),
      onSelected: (sel) {
        if (sel) {
          _loadAnalysis(focus: focusKey);
        }
      },
    );
  }

  Widget _buildExecutiveSummaryCard(AdvisorResponse data) {
    Color healthColor = data.squadHealthScore >= 75
        ? AppTheme.fplGreen
        : data.squadHealthScore >= 50
            ? Colors.orange
            : AppTheme.fplPink;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.teamName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text('AI Squad Health Evaluation', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: healthColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety, size: 14, color: healthColor),
                    const SizedBox(width: 4),
                    Text(
                      '${data.squadHealthScore}/100',
                      style: TextStyle(fontWeight: FontWeight.bold, color: healthColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: AppTheme.surfaceVariant),

          // Recommended Captains
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.fplPurple.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.fplGreen.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield, color: AppTheme.fplGreen, size: 12),
                          SizedBox(width: 4),
                          Text('PRIMARY CAPTAIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.fplGreen)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.primaryCaptainRecommendation,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppTheme.fplCyan, size: 12),
                          SizedBox(width: 4),
                          Text('VICE CAPTAIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.fplCyan)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.viceCaptainRecommendation,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(AdvisorRecommendationItem item) {
    Color catColor;
    IconData catIcon;
    switch (item.category) {
      case 'captaincy':
        catColor = AppTheme.fplGreen;
        catIcon = Icons.shield;
        break;
      case 'transfer':
        catColor = AppTheme.fplCyan;
        catIcon = Icons.swap_horiz;
        break;
      case 'risk':
        catColor = AppTheme.fplPink;
        catIcon = Icons.warning_amber_rounded;
        break;
      default:
        catColor = Colors.orange;
        catIcon = Icons.lightbulb_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(catIcon, size: 14, color: catColor),
                    const SizedBox(width: 6),
                    Text(
                      item.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.confidence} Confidence',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              item.rationale,
              style: TextStyle(fontSize: 12, color: Colors.grey[300], height: 1.3),
            ),
            if (item.tradeOffs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 12, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Trade-off: ${item.tradeOffs}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroundedFactsCard(AdvisorResponse data) {
    if (data.groundedFactsUsed.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified, size: 14, color: AppTheme.fplCyan),
              SizedBox(width: 6),
              Text(
                'GROUNDED FACTS & STATISTICAL INPUTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.fplCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...data.groundedFactsUsed.map(
            (fact) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.grey)),
                  Expanded(
                    child: Text(fact, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
