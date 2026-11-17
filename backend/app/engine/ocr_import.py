"""
OCR / Screenshot Squad Importer (Section 7.1 ONB-02).
Parses extracted text from FPL team screenshots, fuzzy-matches player names against
official Premier League elements, proposes Starting XI, Bench, and Captaincy with confidence ratings.
"""
import re
from typing import List, Dict, Any, Optional, Set
from pydantic import BaseModel
from app.models.fpl import PlayerSummary, TeamSummary


class OcrDetectedPlayer(BaseModel):
    player_id: int
    matched_name: str
    detected_token: str
    position_name: str
    element_type: int
    team_short_name: str
    now_cost: float
    confidence: float
    is_captain: bool = False
    is_vice_captain: bool = False
    is_starter: bool = True


class OcrSquadImportResponse(BaseModel):
    success: bool
    total_detected: int
    starting_xi: List[OcrDetectedPlayer]
    bench: List[OcrDetectedPlayer]
    missing_count: int
    warnings: List[str]
    raw_tokens_processed: int


def parse_screenshot_ocr_text(
    ocr_text: str,
    all_elements: List[Dict[str, Any]],
    teams_map: Dict[int, TeamSummary]
) -> OcrSquadImportResponse:
    lines = [line.strip() for line in ocr_text.splitlines() if line.strip()]

    # Normalize players list
    player_lookup = []
    for p in all_elements:
        w_name = p["web_name"].lower()
        s_name = p["second_name"].lower()
        full = f"{p['first_name']} {p['second_name']}".lower()
        player_lookup.append({
            "id": p["id"],
            "raw": p,
            "web_name": p["web_name"],
            "keys": {w_name, s_name, full}
        })

    detected: List[OcrDetectedPlayer] = []
    seen_ids: Set[int] = set()
    warnings: List[str] = []

    # Clean words and match
    for line in lines:
        is_cap = bool(re.search(r'\b(c|\(c\)|capt|captain)\b', line, re.IGNORECASE))
        is_vice = bool(re.search(r'\b(v|\(v\)|vc|vice)\b', line, re.IGNORECASE))

        # Remove non-alphabetical noise for matching
        clean_line = re.sub(r'[^a-zA-Z\s]', ' ', line).strip().lower()
        tokens = [t for t in clean_line.split() if len(t) >= 3]

        for token in tokens:
            if token in ["gkp", "def", "mid", "fwd", "bench", "captain", "vice"]:
                continue

            best_match = None
            best_score = 0.0

            for candidate in player_lookup:
                pid = candidate["id"]
                if pid in seen_ids:
                    continue

                for key in candidate["keys"]:
                    if token == key:
                        score = 1.0
                    elif len(token) >= 4 and (token == key[:len(token)] or key == token[:len(key)]):
                        score = 0.85
                    else:
                        score = 0.0

                    if score > best_score:
                        best_score = score
                        best_match = candidate

            if best_match and best_score >= 0.8:
                raw_p = best_match["raw"]
                seen_ids.add(best_match["id"])
                t_obj = teams_map.get(raw_p["team"], TeamSummary(id=0, name="Unknown", short_name="UNK", strength=3))

                from app.services.fpl.client import POSITION_MAP
                detected.append(OcrDetectedPlayer(
                    player_id=raw_p["id"],
                    matched_name=raw_p["web_name"],
                    detected_token=token,
                    position_name=POSITION_MAP.get(raw_p["element_type"], "UNK"),
                    element_type=raw_p["element_type"],
                    team_short_name=t_obj.short_name,
                    now_cost=raw_p["now_cost"] / 10.0,
                    confidence=round(best_score, 2),
                    is_captain=is_cap,
                    is_vice_captain=is_vice,
                    is_starter=len(detected) < 11
                ))

    # Sort into Starting XI and Bench
    # Starting XI needs: 1 GKP, at least 3 DEF, 2 MID, 1 FWD
    gkps = [p for p in detected if p.element_type == 1]
    defs = [p for p in detected if p.element_type == 2]
    mids = [p for p in detected if p.element_type == 3]
    fwds = [p for p in detected if p.element_type == 4]

    starters: List[OcrDetectedPlayer] = []
    bench: List[OcrDetectedPlayer] = []

    # 1 GK starter, rest to bench
    if gkps:
        starters.append(gkps[0])
        bench.extend(gkps[1:])

    # 3-5 DEFs
    starters.extend(defs[:min(5, max(3, len(defs)))])
    bench.extend(defs[min(5, max(3, len(defs))):])

    # 2-5 MIDs
    needed = 10 - len(starters)
    mids_to_start = min(needed, len(mids))
    starters.extend(mids[:mids_to_start])
    bench.extend(mids[mids_to_start:])

    # FWDs
    remaining_spots = 11 - len(starters)
    starters.extend(fwds[:remaining_spots])
    bench.extend(fwds[remaining_spots:])

    # Mark starter flags
    for s in starters:
        s.is_starter = True
    for b in bench:
        b.is_starter = False

    missing = max(0, 15 - len(detected))
    if missing > 0:
        warnings.append(f"Detected {len(detected)} out of 15 players. Please manually confirm missing slots.")

    return OcrSquadImportResponse(
        success=len(detected) >= 11,
        total_detected=len(detected),
        starting_xi=starters[:11],
        bench=bench,
        missing_count=missing,
        warnings=warnings,
        raw_tokens_processed=len(lines)
    )
