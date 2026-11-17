from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query
from app.services.fpl.client import fpl_client, FPLResourceNotFound
from app.services.fpl.watchlist_store import watchlist_store
from app.models.fpl import (
    SquadResponse, ManagerProfile, RankImpactRequest, RankImpactResult,
    LiveMatchCenterResponse, PlayerSummary, WatchlistPlayerItem, TeamSummary
)
from app.engine.rank_impact import calculate_rank_impact
from app.core.config import settings
import time

api_router = APIRouter()


@api_router.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }


@api_router.get("/bootstrap")
async def get_bootstrap_summary():
    try:
        data = await fpl_client.get_bootstrap_static()
        current_gw = await fpl_client.get_current_gameweek()
        return {
            "current_gameweek": current_gw,
            "total_players": len(data.get("elements", [])),
            "total_teams": len(data.get("teams", [])),
            "events_count": len(data.get("events", [])),
            "data_freshness_ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch FPL bootstrap data: {str(e)}")


@api_router.get("/manager/{manager_id}", response_model=ManagerProfile)
async def get_manager(manager_id: int):
    try:
        data = await fpl_client.get_manager(manager_id)
        return ManagerProfile(
            id=manager_id,
            player_name=f"{data.get('player_first_name', '')} {data.get('player_last_name', '')}".strip(),
            team_name=data.get("name", "FPL Team"),
            region=data.get("player_region_name"),
            overall_points=data.get("summary_overall_points"),
            overall_rank=data.get("summary_overall_rank"),
        )
    except FPLResourceNotFound as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch manager data: {str(e)}")


@api_router.get("/manager/{manager_id}/squad", response_model=SquadResponse)
async def get_manager_squad(
    manager_id: int,
    gameweek: Optional[int] = Query(None, description="Gameweek number; defaults to active gameweek")
):
    try:
        squad = await fpl_client.get_enriched_squad(manager_id, gameweek)
        return squad
    except FPLResourceNotFound as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to load squad for manager {manager_id}: {str(e)}")


@api_router.get("/fixtures")
async def get_fixtures(gameweek: Optional[int] = Query(None)):
    try:
        return await fpl_client.get_fixtures(gameweek)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch fixtures: {str(e)}")


@api_router.post("/rank/impact", response_model=RankImpactResult)
async def evaluate_rank_impact(request: RankImpactRequest):
    """
    Computes user vs cohort/rival impact for player match events (goals, assists, cards, bonus).
    """
    return calculate_rank_impact(request)


@api_router.get("/live/matches", response_model=LiveMatchCenterResponse)
async def get_live_matches(gameweek: Optional[int] = Query(None)):
    """
    Live match centre: fixtures, live score, match events (goals, assists, cards),
    and provisional vs confirmed bonus points.
    """
    try:
        return await fpl_client.get_live_match_center(gameweek)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch live matches: {str(e)}")


@api_router.get("/players/search", response_model=List[PlayerSummary])
async def search_players(q: str = Query(..., min_length=2, description="Player name prefix or substring")):
    try:
        return await fpl_client.search_players(q)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to search players: {str(e)}")


@api_router.get("/watchlist", response_model=List[WatchlistPlayerItem])
async def get_watchlist():
    """
    Retrieves all tracked watchlist players enriched with current stats.
    """
    try:
        entries = watchlist_store.get_all()
        if not entries:
            return []

        bootstrap = await fpl_client.get_bootstrap_static()
        teams_map = {
            t["id"]: TeamSummary(
                id=t["id"],
                name=t["name"],
                short_name=t["short_name"],
                strength=t.get("strength") or 3,
            )
            for t in bootstrap.get("teams", [])
        }

        players_dict = {p["id"]: p for p in bootstrap.get("elements", [])}
        result = []

        from app.services.fpl.client import POSITION_MAP

        for entry in entries:
            pid = entry["player_id"]
            p = players_dict.get(pid)
            if not p:
                continue

            summary = PlayerSummary(
                id=p["id"],
                web_name=p["web_name"],
                first_name=p["first_name"],
                second_name=p["second_name"],
                team_id=p["team"],
                element_type=p["element_type"],
                position_name=POSITION_MAP.get(p["element_type"], "UNK"),
                now_cost=p["now_cost"] / 10.0,
                cost_raw=p["now_cost"],
                status=p.get("status", "a"),
                chance_of_playing_next_round=p.get("chance_of_playing_next_round"),
                news=p.get("news") or None,
                news_added=p.get("news_added") or None,
                total_points=p.get("total_points", 0),
                selected_by_percent=float(p.get("selected_by_percent", 0.0)),
                form=float(p.get("form", 0.0)),
                event_points=p.get("event_points", 0)
            )
            team = teams_map.get(summary.team_id, TeamSummary(id=0, name="Unknown", short_name="UNK", strength=3))
            result.append(WatchlistPlayerItem(
                player=summary,
                team=team,
                added_at=entry["added_at"]
            ))

        return result
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch watchlist: {str(e)}")


@api_router.post("/watchlist/{player_id}")
async def add_to_watchlist(player_id: int):
    added = watchlist_store.add(player_id)
    return {"status": "added" if added else "already_present", "player_id": player_id}


@api_router.delete("/watchlist/{player_id}")
async def remove_from_watchlist(player_id: int):
    removed = watchlist_store.remove(player_id)
    return {"status": "removed" if removed else "not_found", "player_id": player_id}
