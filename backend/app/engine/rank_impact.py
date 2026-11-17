"""
Rank-Impact Engine for FPL IQ.
Calculates relative points swing and rank delta against:
1. Target rank cohorts (e.g., Top 10k, Top 100k, Overall)
2. Direct mini-league rivals
Follows Section 7.3 and 10.3 of the PRD.
"""
from typing import Optional, Dict, Any
from app.models.fpl import RankImpactRequest, RankImpactResult


def calculate_rank_impact(
    request: RankImpactRequest,
    is_provisional: bool = False
) -> RankImpactResult:
    """
    Computes:
    - User Effective Ownership (e.g. 0% benched, 100% starter, 200% captain, 300% triple captain)
    - Net exposure = User EO% - Cohort EO%
    - Relative points swing = Net exposure * Points / 100
    - Qualitative impact categorization with plain-English summary.
    """
    user_eo = float(request.user_multiplier * 100.0)
    cohort_eo = request.cohort_effective_ownership
    net_exposure = user_eo - cohort_eo  # Positive means user has higher stake than cohort

    # Relative points gained (+) or lost (-) against the average manager in that cohort
    relative_swing = (net_exposure / 100.0) * request.points

    # Categorize impact
    if relative_swing >= 6.0:
        category = "significantly_positive"
    elif relative_swing >= 1.5:
        category = "positive"
    elif relative_swing <= -6.0:
        category = "significantly_negative"
    elif relative_swing <= -1.5:
        category = "negative"
    else:
        category = "neutral"

    # Generate explanatory summary text
    sign = "+" if relative_swing > 0 else ""
    swing_str = f"{sign}{relative_swing:.1f}"

    if net_exposure > 20:
        summary = (
            f"{request.player_name}'s {request.points} pts boosted your rank vs {request.cohort_name}. "
            f"You hold {user_eo:.0f}% EO vs cohort {cohort_eo:.1f}% ({swing_str} net pts swing)."
        )
    elif net_exposure < -20:
        summary = (
            f"{request.player_name}'s {request.points} pts hurt your rank vs {request.cohort_name}. "
            f"Cohort holds {cohort_eo:.1f}% EO vs your {user_eo:.0f}% ({swing_str} net pts swing)."
        )
    else:
        summary = (
            f"{request.player_name}'s return has minimal rank impact against {request.cohort_name} "
            f"due to matched ownership ({swing_str} net pts swing)."
        )

    # If rival comparison was provided
    if request.rival_multiplier is not None and request.rival_name:
        rival_eo = float(request.rival_multiplier * 100.0)
        rival_swing = ((user_eo - rival_eo) / 100.0) * request.points
        r_sign = "+" if rival_swing > 0 else ""
        summary += f" Against rival {request.rival_name}: {r_sign}{rival_swing:.0f} pts delta."

    return RankImpactResult(
        player_id=request.player_id,
        player_name=request.player_name,
        points=request.points,
        user_effective_ownership=user_eo,
        cohort_effective_ownership=cohort_eo,
        net_exposure=round(net_exposure, 1),
        relative_points_swing=round(relative_swing, 2),
        impact_category=category,
        summary_text=summary,
        provisional=is_provisional,
        confidence_level="Provisional Estimate" if is_provisional else "Estimated"
    )
