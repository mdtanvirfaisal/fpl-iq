from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query
from app.services.fpl.client import fpl_client, FPLResourceNotFound
from app.models.fpl import (
    SquadResponse, ManagerProfile, RankImpactRequest, RankImpactResult
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
