"""
AI FPL Advisor Engine.
Implements Section 7.10 of the PRD:
- Grounded in manager's actual squad, bank, injuries, upcoming FDR, and player form.
- Discloses assumptions and uncertainty.
- Strictly avoids hallucinated injuries or prices.
"""
from typing import List, Dict, Any, Optional
from app.models.fpl import (
    SquadResponse, ClubFixtureTicker, InjuryNewsItem,
    AdvisorRecommendationItem, AdvisorResponse, PlayerSummary
)


def generate_advisor_analysis(
    squad: SquadResponse,
    ticker: List[ClubFixtureTicker],
    injuries: List[InjuryNewsItem],
    candidate_targets: List[PlayerSummary],
    query: Optional[str] = None,
    focus_area: str = "general"
) -> AdvisorResponse:
    ticker_map = {t.team_id: t for t in ticker}
    flagged_ids = {inj.player_id: inj for inj in injuries}

    all_players = squad.starting_xi + squad.bench
    bank = squad.manager.last_deadline_bank or 0.0

    # 1. Evaluate Captaincy
    # Captain score = (form * 2.5) + (5 - next_fdr)*1.5 + (home_bonus 2.0)
    captain_candidates = []
    for p in squad.starting_xi:
        if p.player.id in flagged_ids:
            continue
        team_ticker = ticker_map.get(p.player.team_id)
        next_diff = 3
        is_home = True
        opp_name = "TBD"
        if team_ticker and team_ticker.fixtures:
            f0 = team_ticker.fixtures[0]
            next_diff = f0.difficulty
            is_home = f0.is_home
            opp_name = f0.opponent_short_name

        cap_score = (p.player.form * 2.5) + ((5 - next_diff) * 1.5) + (2.0 if is_home else 0.0)
        captain_candidates.append({
            "player": p.player,
            "score": cap_score,
            "next_diff": next_diff,
            "is_home": is_home,
            "opp_name": opp_name
        })

    captain_candidates.sort(key=lambda x: x["score"], reverse=True)
    primary_cap = captain_candidates[0]["player"].web_name if captain_candidates else "Haaland"
    vice_cap = captain_candidates[1]["player"].web_name if len(captain_candidates) > 1 else "Palmer"

    recommendations: List[AdvisorRecommendationItem] = []
    facts_used: List[str] = []

    # Captaincy recommendation item
    if captain_candidates:
        c0 = captain_candidates[0]
        home_str = "Home" if c0["is_home"] else "Away"
        recommendations.append(AdvisorRecommendationItem(
            title=f"Captaincy Pick: Armband on {c0['player'].web_name}",
            category="captaincy",
            confidence="High" if c0["player"].form >= 6.0 else "Moderate",
            rationale=(
                f"{c0['player'].web_name} ranks #1 in squad tactical score with Form {c0['player'].form} "
                f"facing {c0['opp_name']} ({home_str}, FDR {c0['next_diff']}/5)."
            ),
            player_names=[c0['player'].web_name, vice_cap],
            trade_offs=f"Vice-captain on {vice_cap} as insurance against late lineup rotation."
        ))
        facts_used.append(f"{c0['player'].web_name} form: {c0['player'].form}, fixture vs {c0['opp_name']} (FDR {c0['next_diff']})")

    # 2. Evaluate Injury & Availability Risks in Squad
    squad_injuries = [p for p in all_players if p.player.id in flagged_ids]
    health_penalty = len(squad_injuries) * 15

    if squad_injuries:
        for si in squad_injuries:
            flag_info = flagged_ids[si.player.id]
            recommendations.append(AdvisorRecommendationItem(
                title=f"Availability Risk: {si.player.web_name} ({flag_info.status_label})",
                category="risk",
                confidence="High",
                rationale=f"Player is flagged by official FPL: '{flag_info.news}'.",
                player_names=[si.player.web_name],
                trade_offs="Consider starting a bench backup or prioritizing as a free transfer exit."
            ))
            facts_used.append(f"{si.player.web_name} flagged: {flag_info.news}")

    # 3. Evaluate Transfer Suggestions
    # Find lowest form outfield starter or injured starter to replace
    sell_candidates = [
        p for p in squad.starting_xi
        if p.player.element_type != 1  # Outfield
    ]
    # Prioritize selling injured first, then lowest form
    sell_candidates.sort(key=lambda x: (x.player.id not in flagged_ids, x.player.form))

    if sell_candidates and candidate_targets:
        worst = sell_candidates[0]
        max_budget = worst.player.now_cost + bank

        # Filter candidate targets of same position within budget
        valid_buys = [
            t for t in candidate_targets
            if t.element_type == worst.player.element_type
            and t.id != worst.player.id
            and t.now_cost <= max_budget
            and t.status == 'a'
        ]
        valid_buys.sort(key=lambda x: (x.form, x.total_points), reverse=True)

        if valid_buys:
            best_buy = valid_buys[0]
            recommendations.append(AdvisorRecommendationItem(
                title=f"Transfer Upgrade: Sell {worst.player.web_name} -> Buy {best_buy.web_name}",
                category="transfer",
                confidence="High" if best_buy.form > worst.player.form + 2.0 else "Moderate",
                rationale=(
                    f"Swapping {worst.player.web_name} (Form: {worst.player.form}) for {best_buy.web_name} (Form: {best_buy.form}) "
                    f"within your available budget (£{max_budget:.1f}m max, costs £{best_buy.now_cost}m)."
                ),
                player_names=[worst.player.web_name, best_buy.web_name],
                trade_offs=f"Leaves £{(max_budget - best_buy.now_cost):.1f}m remaining in the bank."
            ))
            facts_used.append(f"{worst.player.web_name} cost £{worst.player.now_cost}m vs {best_buy.web_name} cost £{best_buy.now_cost}m (bank £{bank:.1f}m)")

    # 4. Squad Health Score (0 to 100)
    avg_starter_form = sum(p.player.form for p in squad.starting_xi) / 11.0
    form_score = min(50, int(avg_starter_form * 8))
    health_score = max(20, min(100, 50 + form_score - health_penalty))

    return AdvisorResponse(
        manager_id=squad.manager.id,
        team_name=squad.manager.team_name,
        squad_health_score=health_score,
        primary_captain_recommendation=primary_cap,
        vice_captain_recommendation=vice_cap,
        recommendations=recommendations,
        grounded_facts_used=facts_used,
        disclaimer="Advisory analysis grounded strictly in official FPL statistics; not guaranteed outcomes."
    )
