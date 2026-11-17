"""
Provisional Bonus Points Calculator for FPL IQ.
Implements official Fantasy Premier League bonus tie-breaking rules:
- 1st in BPS: 3 bonus pts
- 2nd in BPS: 2 bonus pts
- 3rd in BPS: 1 bonus pt
- Tied players receive identical bonus points; subsequent awards adjust accordingly.
"""
from typing import List, Dict, Any, Tuple, Optional
from pydantic import BaseModel


class BonusCandidate(BaseModel):
    element_id: int
    bps: int
    bonus_points: int
    is_provisional: bool
    is_home: bool


def calculate_provisional_bonus(
    home_bps: List[Dict[str, Any]],
    away_bps: List[Dict[str, Any]],
    is_match_final: bool = False,
    official_bonus: Optional[Dict[str, List[Dict[str, Any]]]] = None
) -> List[BonusCandidate]:
    """
    Given home and away BPS stats lists [{'element': id, 'value': bps}],
    returns top candidates with provisional/confirmed bonus points.
    """
    if is_match_final and official_bonus:
        # If official bonus is finalized, extract directly
        confirmed: List[BonusCandidate] = []
        home_elems = {p['element'] for p in home_bps}
        for p in official_bonus.get('h', []):
            confirmed.append(BonusCandidate(
                element_id=p['element'],
                bps=0,
                bonus_points=p['value'],
                is_provisional=False,
                is_home=True
            ))
        for p in official_bonus.get('a', []):
            confirmed.append(BonusCandidate(
                element_id=p['element'],
                bps=0,
                bonus_points=p['value'],
                is_provisional=False,
                is_home=False
            ))
        return sorted(confirmed, key=lambda x: x.bonus_points, reverse=True)

    # Merge players with BPS
    combined: List[Tuple[int, int, bool]] = []  # (element_id, bps, is_home)
    for p in home_bps:
        combined.append((p['element'], p['value'], True))
    for p in away_bps:
        combined.append((p['element'], p['value'], False))

    if not combined:
        return []

    # Sort descending by BPS
    combined.sort(key=lambda x: x[1], reverse=True)

    # Group players by BPS
    bps_groups: List[Tuple[int, List[Tuple[int, bool]]]] = []
    current_bps = None
    current_list: List[Tuple[int, bool]] = []

    for elem_id, bps, is_home in combined:
        if bps <= 0:
            continue
        if bps == current_bps:
            current_list.append((elem_id, is_home))
        else:
            if current_list:
                bps_groups.append((current_bps, current_list))
            current_bps = bps
            current_list = [(elem_id, is_home)]
    if current_list:
        bps_groups.append((current_bps, current_list))

    candidates: List[BonusCandidate] = []
    bonus_slots = [3, 2, 1]
    slot_idx = 0

    for bps, players in bps_groups:
        if slot_idx >= len(bonus_slots):
            break

        awarded_bonus = bonus_slots[slot_idx]
        for elem_id, is_home in players:
            candidates.append(BonusCandidate(
                element_id=elem_id,
                bps=bps,
                bonus_points=awarded_bonus,
                is_provisional=not is_match_final,
                is_home=is_home
            ))

        slot_idx += len(players)

    return candidates
