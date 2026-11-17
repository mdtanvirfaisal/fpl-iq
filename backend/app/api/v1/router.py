from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Query
from app.services.fpl.client import fpl_client, FPLResourceNotFound
from app.services.fpl.watchlist_store import watchlist_store
from app.services.fpl.notification_store import notification_store
from app.models.fpl import (
    SquadResponse, ManagerProfile, RankImpactRequest, RankImpactResult,
    LiveMatchCenterResponse, PlayerSummary, WatchlistPlayerItem, TeamSummary,
    ClassicLeagueSummary, LeagueStandingsResponse, HeadToHeadComparison,
    ClubFixtureTicker, InjuryNewsItem, MarketTrendsResponse,
    NotificationItem, NotificationSettings,
    AdvisorQueryRequest, AdvisorResponse
)
from app.engine.planner import (
    TransferSimulationRequest, TransferSimulationResult, simulate_transfer_plan
)
from app.engine.advisor import generate_advisor_analysis
from app.engine.ocr_import import parse_screenshot_ocr_text, OcrSquadImportResponse
from pydantic import BaseModel


class OcrImportRequest(BaseModel):
    ocr_text: str
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


@api_router.get("/manager/{manager_id}/leagues", response_model=List[ClassicLeagueSummary])
async def get_manager_leagues(manager_id: int):
    """
    Retrieves all classic mini-leagues a manager participates in.
    """
    try:
        return await fpl_client.get_manager_leagues(manager_id)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch manager leagues: {str(e)}")


@api_router.get("/leagues/{league_id}/standings", response_model=LeagueStandingsResponse)
async def get_league_standings(league_id: int):
    """
    Retrieves current rankings, manager names, and live event scores for a mini-league.
    """
    try:
        return await fpl_client.get_league_standings(league_id)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch league standings: {str(e)}")


@api_router.get("/manager/{manager_id}/rival/{rival_id}/compare", response_model=HeadToHeadComparison)
async def compare_rival(
    manager_id: int,
    rival_id: int,
    gameweek: Optional[int] = Query(None)
):
    """
    Compares two managers head-to-head for a gameweek:
    calculates points gap, captaincy swing, shared players, and differentials.
    """
    try:
        return await fpl_client.compare_squads_head_to_head(manager_id, rival_id, gameweek)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to compare manager with rival: {str(e)}")


@api_router.get("/fixtures/ticker", response_model=List[ClubFixtureTicker])
async def get_fixture_ticker(
    start_gw: Optional[int] = Query(None, description="Starting gameweek for ticker"),
    count: int = Query(5, ge=1, le=10, description="Number of future gameweeks to display")
):
    """
    Returns fixture difficulty ticker for all 20 Premier League clubs.
    """
    try:
        return await fpl_client.get_fixture_ticker(start_gw, count)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch fixture ticker: {str(e)}")


@api_router.post("/planner/simulate", response_model=TransferSimulationResult)
async def simulate_transfers(request: TransferSimulationRequest):
    """
    Simulates a multi-transfer scenario or chip activation (Wildcard, Free Hit, Triple Captain, Bench Boost).
    Validates budget, team limits (max 3 per club), and calculates point hits.
    """
    try:
        squad = await fpl_client.get_enriched_squad(request.manager_id, request.gameweek)
        bootstrap = await fpl_client.get_bootstrap_static()

        teams_map = {
            t["id"]: TeamSummary(
                id=t["id"],
                name=t["name"],
                short_name=t["short_name"],
                strength=t.get("strength") or 3
            )
            for t in bootstrap.get("teams", [])
        }

        elements_dict = {p["id"]: p for p in bootstrap.get("elements", [])}
        incoming_summaries = []

        from app.services.fpl.client import POSITION_MAP

        for pid in request.transfers_in:
            raw = elements_dict.get(pid)
            if not raw:
                raise HTTPException(status_code=404, detail=f"Transfer-in player ID {pid} not found in Premier League")
            incoming_summaries.append(PlayerSummary(
                id=raw["id"],
                web_name=raw["web_name"],
                first_name=raw["first_name"],
                second_name=raw["second_name"],
                team_id=raw["team"],
                element_type=raw["element_type"],
                position_name=POSITION_MAP.get(raw["element_type"], "UNK"),
                now_cost=raw["now_cost"] / 10.0,
                cost_raw=raw["now_cost"],
                status=raw.get("status", "a"),
                chance_of_playing_next_round=raw.get("chance_of_playing_next_round"),
                news=raw.get("news") or None,
                news_added=raw.get("news_added") or None,
                total_points=raw.get("total_points", 0),
                selected_by_percent=float(raw.get("selected_by_percent", 0.0)),
                form=float(raw.get("form", 0.0)),
                event_points=raw.get("event_points", 0)
            ))

        bank = squad.manager.last_deadline_bank or 0.0

        all_players = squad.starting_xi + squad.bench
        return simulate_transfer_plan(
            current_players=all_players,
            incoming_players=incoming_summaries,
            teams_map=teams_map,
            initial_bank=bank,
            transfers_out_ids=request.transfers_out,
            free_transfers=request.free_transfers,
            active_chip=request.active_chip
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Transfer simulation failed: {str(e)}")


@api_router.get("/injuries", response_model=List[InjuryNewsItem])
async def get_injuries(manager_id: Optional[int] = Query(None)):
    """
    Returns injury, doubtful, and suspension availability news.
    If manager_id is specified, filters news to the manager's 15-player squad.
    """
    try:
        squad_ids = None
        if manager_id is not None:
            squad = await fpl_client.get_enriched_squad(manager_id)
            squad_ids = [p.player.id for p in squad.starting_xi + squad.bench]
        return await fpl_client.get_injury_news(squad_ids)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch injury news: {str(e)}")


@api_router.get("/market/trends", response_model=MarketTrendsResponse)
async def get_market_trends(limit: int = Query(10, ge=1, le=25)):
    """
    Returns top transferred in and transferred out players in the market for the current gameweek.
    """
    try:
        return await fpl_client.get_market_trends(limit)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch market trends: {str(e)}")


@api_router.get("/notifications", response_model=List[NotificationItem])
async def get_notifications():
    """
    Fetches the manager's personalized alert feed with priorities, categories, and deep links.
    """
    return notification_store.get_notifications()


@api_router.post("/notifications/{notif_id}/read")
async def mark_notification_read(notif_id: str):
    success = notification_store.mark_as_read(notif_id)
    return {"status": "marked_read" if success else "not_found", "id": notif_id}


@api_router.get("/notifications/settings", response_model=NotificationSettings)
async def get_notification_settings():
    return notification_store.get_settings()


@api_router.post("/notifications/settings", response_model=NotificationSettings)
async def update_notification_settings(settings: NotificationSettings):
    return notification_store.update_settings(settings)


@api_router.post("/advisor/analyze", response_model=AdvisorResponse)
async def analyze_squad_with_advisor(request: AdvisorQueryRequest):
    """
    AI FPL Advisor (Section 7.10 of PRD):
    Evaluates captaincy, transfer moves, fixture traps, and injury risks grounded strictly in real FPL statistics.
    """
    try:
        squad = await fpl_client.get_enriched_squad(request.manager_id, request.gameweek)
        ticker = await fpl_client.get_fixture_ticker(count=3)
        injuries = await fpl_client.get_injury_news()

        bootstrap = await fpl_client.get_bootstrap_static()
        from app.services.fpl.client import POSITION_MAP

        candidate_targets = [
            PlayerSummary(
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
            for p in bootstrap.get("elements", [])
        ]

        return generate_advisor_analysis(
            squad=squad,
            ticker=ticker,
            injuries=injuries,
            candidate_targets=candidate_targets,
            query=request.query,
            focus_area=request.focus_area
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI Advisor analysis failed: {str(e)}")


@api_router.post("/squad/import/ocr", response_model=OcrSquadImportResponse)
async def import_squad_from_ocr(request: OcrImportRequest):
    """
    Screenshot Squad Import Assist (Section 7.1 ONB-02):
    Parses OCR / screenshot text, fuzzy-matches player names against official Premier League elements,
    and proposes Starting XI, Bench, and Captaincy with confidence ratings.
    """
    try:
        bootstrap = await fpl_client.get_bootstrap_static()
        teams_map = {
            t["id"]: TeamSummary(
                id=t["id"],
                name=t["name"],
                short_name=t["short_name"],
                strength=t.get("strength") or 3
            )
            for t in bootstrap.get("teams", [])
        }

        return parse_screenshot_ocr_text(
            ocr_text=request.ocr_text,
            all_elements=bootstrap.get("elements", []),
            teams_map=teams_map
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Screenshot OCR import failed: {str(e)}")
