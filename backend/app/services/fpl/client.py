import asyncio
import time
from typing import Dict, Any, Optional, List, Tuple
import httpx
from app.core.config import settings
from app.models.fpl import (
    PlayerSummary, TeamSummary, GameweekEvent, ManagerProfile,
    SquadPick, EnrichedSquadPlayer, SquadResponse
)

POSITION_MAP = {
    1: "GKP",
    2: "DEF",
    3: "MID",
    4: "FWD"
}


class FPLResourceNotFound(Exception):
    pass


class CacheEntry:
    def __init__(self, data: Any, ttl: int):
        self.data = data
        self.expires_at = time.time() + ttl

    def is_expired(self) -> bool:
        return time.time() > self.expires_at


class FPLClient:
    """
    Robust FPL API client with:
    - Smart caching (TTL per endpoint type)
    - Exponential backoff & retries
    - Graceful error handling & fallback
    - Strict rate limiting protection
    """

    def __init__(self):
        self.base_url = settings.FPL_BASE_URL.rstrip("/")
        self.headers = {
            "User-Agent": settings.FPL_USER_AGENT,
            "Accept": "application/json",
        }
        self._cache: Dict[str, CacheEntry] = {}
        self._client: Optional[httpx.AsyncClient] = None

    async def get_client(self) -> httpx.AsyncClient:
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                headers=self.headers,
                timeout=settings.FPL_TIMEOUT_SECONDS,
                follow_redirects=True
            )
        return self._client

    async def close(self):
        if self._client and not self._client.is_closed:
            await self._client.aclose()

    def _get_from_cache(self, key: str) -> Optional[Any]:
        entry = self._cache.get(key)
        if entry and not entry.is_expired():
            return entry.data
        return None

    def _set_cache(self, key: str, data: Any, ttl: int):
        self._cache[key] = CacheEntry(data, ttl)

    async def _fetch_with_retry(self, endpoint: str, ttl: int) -> Dict[str, Any]:
        cache_key = f"endpoint:{endpoint}"
        cached = self._get_from_cache(cache_key)
        if cached is not None:
            return cached

        client = await self.get_client()
        last_error = None
        delay = 0.5

        for attempt in range(settings.FPL_MAX_RETRIES):
            try:
                response = await client.get(endpoint)
                if response.status_code == 200:
                    data = response.json()
                    self._set_cache(cache_key, data, ttl)
                    return data
                elif response.status_code == 404:
                    raise FPLResourceNotFound(f"FPL resource not found: {endpoint}")
                elif response.status_code == 429:
                    await asyncio.sleep(delay * 2)
                else:
                    response.raise_for_status()
            except (httpx.RequestError, httpx.HTTPStatusError) as e:
                last_error = e
                await asyncio.sleep(delay)
                delay *= settings.FPL_BACKOFF_FACTOR

        raise RuntimeError(f"FPL API error after {settings.FPL_MAX_RETRIES} retries for '{endpoint}': {last_error}")

    async def get_bootstrap_static(self) -> Dict[str, Any]:
        """Fetch elements, teams, events static data."""
        return await self._fetch_with_retry("/bootstrap-static/", settings.CACHE_BOOTSTRAP_TTL)

    async def get_fixtures(self, gameweek: Optional[int] = None) -> List[Dict[str, Any]]:
        endpoint = f"/fixtures/?event={gameweek}" if gameweek else "/fixtures/"
        return await self._fetch_with_retry(endpoint, settings.CACHE_BOOTSTRAP_TTL)

    async def get_manager(self, manager_id: int) -> Dict[str, Any]:
        """Fetch manager basic profile and overall rank."""
        return await self._fetch_with_retry(f"/entry/{manager_id}/", settings.CACHE_MANAGER_TTL)

    async def get_manager_picks(self, manager_id: int, gameweek: int) -> Dict[str, Any]:
        """Fetch team picks for a given manager and gameweek."""
        return await self._fetch_with_retry(f"/entry/{manager_id}/event/{gameweek}/picks/", settings.CACHE_PICKS_TTL)

    async def get_live_gameweek(self, gameweek: int) -> Dict[str, Any]:
        """Fetch live element points, bonus, and match stats for a gameweek."""
        return await self._fetch_with_retry(f"/event/{gameweek}/live/", settings.CACHE_LIVE_TTL)

    async def get_current_gameweek(self) -> int:
        bootstrap = await self.get_bootstrap_static()
        events = bootstrap.get("events", [])
        for event in events:
            if event.get("is_current"):
                return event["id"]
        for event in events:
            if event.get("is_next"):
                return event["id"]
        return 1

    async def get_enriched_squad(self, manager_id: int, gameweek: Optional[int] = None) -> SquadResponse:
        """
        Orchestrates full squad loading:
        1. Manager entry info
        2. Gameweek resolution
        3. Manager picks
        4. Bootstrap lookup (players & teams)
        5. Live scores enrichment
        """
        bootstrap = await self.get_bootstrap_static()
        if gameweek is None:
            gameweek = await self.get_current_gameweek()

        manager_data = await self.get_manager(manager_id)
        picks_data = await self.get_manager_picks(manager_id, gameweek)

        try:
            live_data = await self.get_live_gameweek(gameweek)
            live_elements_map = {
                elem["id"]: elem.get("stats", {}).get("total_points", 0)
                for elem in live_data.get("elements", [])
            }
            is_live = True
        except Exception:
            live_elements_map = {}
            is_live = False

        # Build lookup tables
        teams_map = {
            t["id"]: TeamSummary(
                id=t["id"],
                name=t["name"],
                short_name=t["short_name"],
                strength=t.get("strength") or 3,
                strength_overall_home=t.get("strength_overall_home"),
                strength_overall_away=t.get("strength_overall_away"),
                strength_attack_home=t.get("strength_attack_home"),
                strength_attack_away=t.get("strength_attack_away"),
                strength_defence_home=t.get("strength_defence_home"),
                strength_defence_away=t.get("strength_defence_away"),
            )
            for t in bootstrap.get("teams", [])
        }

        players_map = {
            p["id"]: PlayerSummary(
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
        }

        starting_xi: List[EnrichedSquadPlayer] = []
        bench: List[EnrichedSquadPlayer] = []
        total_gw_points = 0

        for pick_raw in picks_data.get("picks", []):
            elem_id = pick_raw["element"]
            multiplier = pick_raw["multiplier"]
            pos = pick_raw["position"]
            is_captain = pick_raw["is_captain"]
            is_vice = pick_raw["is_vice_captain"]

            player = players_map.get(elem_id)
            if not player:
                continue

            team = teams_map.get(player.team_id, TeamSummary(id=0, name="Unknown", short_name="UNK", strength=3))
            pick_obj = SquadPick(
                element_id=elem_id,
                position=pos,
                multiplier=multiplier,
                is_captain=is_captain,
                is_vice_captain=is_vice
            )

            # Determine points: live points if available, else event points from player
            live_pts = live_elements_map.get(elem_id, player.event_points)
            is_starter = pos <= 11

            enriched = EnrichedSquadPlayer(
                player=player,
                team=team,
                pick=pick_obj,
                live_points=live_pts,
                is_starter=is_starter
            )

            if is_starter:
                starting_xi.append(enriched)
                total_gw_points += (live_pts * multiplier)
            else:
                bench.append(enriched)

        entry_hist = picks_data.get("entry_history", {})
        manager_profile = ManagerProfile(
            id=manager_id,
            player_name=f"{manager_data.get('player_first_name', '')} {manager_data.get('player_last_name', '')}".strip(),
            team_name=manager_data.get("name", "FPL Team"),
            region=manager_data.get("player_region_name"),
            overall_points=manager_data.get("summary_overall_points"),
            overall_rank=manager_data.get("summary_overall_rank"),
            last_deadline_bank=(entry_hist.get("bank", 0) / 10.0) if entry_hist else None,
            last_deadline_value=(entry_hist.get("value", 0) / 10.0) if entry_hist else None,
            last_deadline_total_transfers=entry_hist.get("total_transfers") if entry_hist else None,
        )

        return SquadResponse(
            manager=manager_profile,
            gameweek=gameweek,
            active_chip=picks_data.get("active_chip"),
            starting_xi=starting_xi,
            bench=bench,
            gameweek_points=total_gw_points,
            is_live=is_live,
            data_freshness_ts=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        )


fpl_client = FPLClient()
