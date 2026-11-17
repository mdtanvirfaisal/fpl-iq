"""
Transfer Planner, Squad Constraint Validator & Chip Simulation Engine.
Implements Section 7.5 (TR-01 to TR-06) and Section 7.6 (SIM-01 to SIM-05) of PRD.
"""
from typing import List, Dict, Any, Optional, Tuple
from app.models.fpl import (
    EnrichedSquadPlayer, PlayerSummary, TeamSummary
)
from pydantic import BaseModel


class TransferSimulationRequest(BaseModel):
    manager_id: int
    gameweek: Optional[int] = None
    transfers_out: List[int] = []  # Element IDs being sold
    transfers_in: List[int] = []   # Element IDs being bought
    active_chip: Optional[str] = None  # "wildcard", "freehit", "3xc", "bboost"
    free_transfers: int = 1


class TransferSimulationResult(BaseModel):
    valid: bool
    validation_error: Optional[str] = None
    initial_bank: float
    final_bank: float
    transfers_count: int
    points_cost: int  # Penalty hits: 0, 4, 8, etc.
    active_chip: Optional[str] = None
    club_counts: Dict[str, int]
    projected_points_estimate: int
    summary_text: str


def simulate_transfer_plan(
    current_players: List[EnrichedSquadPlayer],
    incoming_players: List[PlayerSummary],
    teams_map: Dict[int, TeamSummary],
    initial_bank: float,
    transfers_out_ids: List[int],
    free_transfers: int = 1,
    active_chip: Optional[str] = None
) -> TransferSimulationResult:
    """
    Validates:
    1. 1-to-1 transfer counts match (equal in and out)
    2. Budget viability (final_bank >= 0)
    3. Club limit (<= 3 players per Premier League club)
    4. Hit cost calculation (-4 per extra transfer, waived if Wildcard or Free Hit)
    5. Chip effects
    """
    if len(transfers_out_ids) != len(incoming_players):
        return TransferSimulationResult(
            valid=False,
            validation_error=f"Transfer imbalance: selling {len(transfers_out_ids)} player(s) but buying {len(incoming_players)} player(s).",
            initial_bank=initial_bank,
            final_bank=initial_bank,
            transfers_count=len(transfers_out_ids),
            points_cost=0,
            active_chip=active_chip,
            club_counts={},
            projected_points_estimate=0,
            summary_text="Invalid transfer plan: counts do not match."
        )

    # Calculate money out (from sold players)
    sold_map = {p.player.id: p.player for p in current_players if p.player.id in transfers_out_ids}
    if len(sold_map) != len(transfers_out_ids):
        missing = set(transfers_out_ids) - set(sold_map.keys())
        return TransferSimulationResult(
            valid=False,
            validation_error=f"Player ID(s) {missing} are not currently in your squad.",
            initial_bank=initial_bank,
            final_bank=initial_bank,
            transfers_count=len(transfers_out_ids),
            points_cost=0,
            active_chip=active_chip,
            club_counts={},
            projected_points_estimate=0,
            summary_text="Invalid transfer plan: player not in squad."
        )

    money_freed = sum(p.now_cost for p in sold_map.values())
    money_spent = sum(p.now_cost for p in incoming_players)
    final_bank = round(initial_bank + money_freed - money_spent, 2)

    if final_bank < -0.01:
        return TransferSimulationResult(
            valid=False,
            validation_error=f"Insufficient funds: transfer requires £{abs(final_bank):.1f}m more than available bank.",
            initial_bank=initial_bank,
            final_bank=final_bank,
            transfers_count=len(transfers_out_ids),
            points_cost=0,
            active_chip=active_chip,
            club_counts={},
            projected_points_estimate=0,
            summary_text=f"Budget deficit of £{abs(final_bank):.1f}m."
        )

    # Check Club Limits (<= 3 per Premier League club)
    retained_players = [p.player for p in current_players if p.player.id not in transfers_out_ids]
    simulated_squad = retained_players + incoming_players

    club_counts: Dict[str, int] = {}
    for p in simulated_squad:
        team_name = teams_map.get(p.team_id, TeamSummary(id=p.team_id, name="Unknown", short_name="UNK", strength=3)).short_name
        club_counts[team_name] = club_counts.get(team_name, 0) + 1

    for team_short, count in club_counts.items():
        if count > 3:
            return TransferSimulationResult(
                valid=False,
                validation_error=f"Exceeded club limit: {team_short} has {count} players (maximum allowed is 3).",
                initial_bank=initial_bank,
                final_bank=final_bank,
                transfers_count=len(transfers_out_ids),
                points_cost=0,
                active_chip=active_chip,
                club_counts=club_counts,
                projected_points_estimate=0,
                summary_text=f"Rule violation: maximum 3 players per club ({team_short} has {count})."
            )

    # Hit Calculation
    num_transfers = len(transfers_out_ids)
    chip_lower = (active_chip or "").lower()

    if chip_lower in ["wildcard", "freehit"]:
        hits_cost = 0
    else:
        extra_transfers = max(0, num_transfers - free_transfers)
        hits_cost = extra_transfers * 4

    # Points projection baseline
    projected = int(sum(p.form for p in simulated_squad[:11]))
    if chip_lower == "3xc":
        projected += 10  # Triple captain boost
    elif chip_lower == "bboost":
        projected += int(sum(p.form for p in simulated_squad[11:]))  # Bench boost points

    net_projected = max(0, projected - hits_cost)

    summary = (
        f"Valid plan: {num_transfers} transfer(s) executed. "
        f"Bank remaining: £{final_bank:.1f}m. "
        f"Cost: {hits_cost} pts hit" + (f" (waived by {chip_lower.upper()})" if chip_lower in ['wildcard', 'freehit'] else "") + ". "
        f"Projected GW score: ~{net_projected} pts."
    )

    return TransferSimulationResult(
        valid=True,
        validation_error=None,
        initial_bank=initial_bank,
        final_bank=final_bank,
        transfers_count=num_transfers,
        points_cost=hits_cost,
        active_chip=active_chip,
        club_counts=club_counts,
        projected_points_estimate=net_projected,
        summary_text=summary
    )
