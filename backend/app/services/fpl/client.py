import asyncio
import time
from typing import Dict, Any, Optional, List, Tuple
import httpx
from app.core.config import settings
from app.models.fpl import (
    PlayerSummary, TeamSummary, GameweekEvent, ManagerProfile,
    SquadPick, EnrichedSquadPlayer, SquadResponse,
    MatchEvent, BonusSummary, FixtureMatch, LiveMatchCenterResponse,
    ClassicLeagueSummary, LeagueStandingEntry, LeagueStandingsResponse,
    HeadToHeadComparison
)
from app.engine.bonus import calculate_provisional_bonus

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
        self._loop: Optional[asyncio.AbstractEventLoop] = None

    async def get_client(self) -> httpx.AsyncClient:
        current_loop = asyncio.get_running_loop()
        if self._client is None or self._client.is_closed or self._loop != current_loop:
            self._loop = current_loop
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

    async def get_live_match_center(self, gameweek: Optional[int] = None) -> LiveMatchCenterResponse:
        """
        Parses live fixtures, match events (goals, assists, cards),
        and calculates provisional vs confirmed bonus points for all matches in the GW.
        """
        if gameweek is None:
            gameweek = await self.get_current_gameweek()

        bootstrap = await self.get_bootstrap_static()
        raw_fixtures = await self.get_fixtures(gameweek)

        teams_map = {
            t["id"]: TeamSummary(
                id=t["id"],
                name=t["name"],
                short_name=t["short_name"],
                strength=t.get("strength") or 3,
                strength_overall_home=t.get("strength_overall_home"),
                strength_overall_away=t.get("strength_overall_away"),
            )
            for t in bootstrap.get("teams", [])
        }

        players_map = {
            p["id"]: p["web_name"]
            for p in bootstrap.get("elements", [])
        }

        fixture_matches: List[FixtureMatch] = []

        for f in raw_fixtures:
            home_t = teams_map.get(f["team_h"], TeamSummary(id=f["team_h"], name="Home", short_name="HOM", strength=3))
            away_t = teams_map.get(f["team_a"], TeamSummary(id=f["team_a"], name="Away", short_name="AWY", strength=3))

            started = f.get("started", False)
            finished = f.get("finished", False)
            fin_prov = f.get("finished_provisional", False)
            minutes = f.get("minutes", 0)

            if not started:
                status_display = "Upcoming"
            elif fin_prov and not finished:
                status_display = "FT (Provisional Bonus)"
            elif finished:
                status_display = "Full Time"
            else:
                status_display = f"Live {minutes}'"

            stats = f.get("stats", [])
            stats_dict = {s["identifier"]: s for s in stats}

            events: List[MatchEvent] = []
            event_type_labels = {
                "goals_scored": "goal",
                "assists": "assist",
                "own_goals": "own_goal",
                "yellow_cards": "yellow_card",
                "red_cards": "red_card",
                "penalties_saved": "penalty_saved",
                "penalties_missed": "penalty_missed",
            }

            for stat_key, label in event_type_labels.items():
                stat_obj = stats_dict.get(stat_key)
                if not stat_obj:
                    continue
                # Home team events
                for item in stat_obj.get("h", []):
                    elem_id = item["element"]
                    events.append(MatchEvent(
                        event_type=label,
                        element_id=elem_id,
                        player_name=players_map.get(elem_id, f"Player {elem_id}"),
                        team_short_name=home_t.short_name,
                        is_home=True,
                        count=item["value"]
                    ))
                # Away team events
                for item in stat_obj.get("a", []):
                    elem_id = item["element"]
                    events.append(MatchEvent(
                        event_type=label,
                        element_id=elem_id,
                        player_name=players_map.get(elem_id, f"Player {elem_id}"),
                        team_short_name=away_t.short_name,
                        is_home=False,
                        count=item["value"]
                    ))

            # Bonus calculation (Provisional vs Confirmed)
            bps_stat = stats_dict.get("bps", {})
            official_bonus_stat = stats_dict.get("bonus", {})

            bonus_candidates_raw = calculate_provisional_bonus(
                home_bps=bps_stat.get("h", []),
                away_bps=bps_stat.get("a", []),
                is_match_final=finished,
                official_bonus=official_bonus_stat if finished and official_bonus_stat.get("h") else None
            )

            bonus_summaries = [
                BonusSummary(
                    element_id=c.element_id,
                    player_name=players_map.get(c.element_id, f"Player {c.element_id}"),
                    bps=c.bps,
                    bonus_points=c.bonus_points,
                    is_provisional=c.is_provisional,
                    is_home=c.is_home
                )
                for c in bonus_candidates_raw
            ]

            fixture_matches.append(FixtureMatch(
                id=f["id"],
                gameweek=gameweek,
                kickoff_time=f.get("kickoff_time", ""),
                started=started,
                finished=finished,
                finished_provisional=fin_prov,
                minutes=minutes,
                home_team=home_t,
                away_team=away_t,
                home_score=f.get("team_h_score"),
                away_score=f.get("team_a_score"),
                events=events,
                bonus_candidates=bonus_summaries,
                status_display=status_display
            ))

        return LiveMatchCenterResponse(
            gameweek=gameweek,
            matches=fixture_matches,
            data_freshness_ts=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        )

    async def search_players(self, query: str, limit: int = 25) -> List[PlayerSummary]:
        bootstrap = await self.get_bootstrap_static()
        q = query.lower().strip()
        results = []

        for p in bootstrap.get("elements", []):
            name = p["web_name"].lower()
            full_name = f"{p['first_name']} {p['second_name']}".lower()
            if q in name or q in full_name:
                results.append(PlayerSummary(
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
                ))
                if len(results) >= limit:
                    break

        return results

    async def get_manager_leagues(self, manager_id: int) -> List[ClassicLeagueSummary]:
        mgr = await self.get_manager(manager_id)
        raw_classic = mgr.get("leagues", {}).get("classic", [])
        return [
            ClassicLeagueSummary(
                id=item["id"],
                name=item["name"],
                entry_rank=item.get("entry_rank"),
                entry_last_rank=item.get("entry_last_rank"),
                league_type=item.get("league_type", "x"),
            )
            for item in raw_classic
        ]

    async def get_league_standings(self, league_id: int) -> LeagueStandingsResponse:
        raw = await self._fetch_with_retry(f"/leagues-classic/{league_id}/standings/", settings.CACHE_MANAGER_TTL)
        league_meta = raw.get("league", {})
        standings_raw = raw.get("standings", {}).get("results", [])

        standings = [
            LeagueStandingEntry(
                entry_id=item["entry"],
                entry_name=item["entry_name"],
                player_name=item["player_name"],
                rank=item["rank"],
                last_rank=item.get("last_rank"),
                event_total=item.get("event_total", 0),
                total=item.get("total", 0),
            )
            for item in standings_raw
        ]

        return LeagueStandingsResponse(
            league_id=league_id,
            league_name=league_meta.get("name", f"League {league_id}"),
            standings=standings
        )

    async def compare_squads_head_to_head(
        self,
        user_manager_id: int,
        rival_manager_id: int,
        gameweek: Optional[int] = None
    ) -> HeadToHeadComparison:
        if gameweek is None:
            gameweek = await self.get_current_gameweek()

        user_squad = await self.get_enriched_squad(user_manager_id, gameweek)
        rival_squad = await self.get_enriched_squad(rival_manager_id, gameweek)

        # Starters map: element_id -> EnrichedSquadPlayer
        user_starters = {p.player.id: p for p in user_squad.starting_xi}
        rival_starters = {p.player.id: p for p in rival_squad.starting_xi}

        shared_ids = set(user_starters.keys()) & set(rival_starters.keys())
        user_diff_ids = set(user_starters.keys()) - set(rival_starters.keys())
        rival_diff_ids = set(rival_starters.keys()) - set(user_starters.keys())

        shared_players = [user_starters[pid] for pid in shared_ids]
        user_differentials = [user_starters[pid] for pid in user_diff_ids]
        rival_differentials = [rival_starters[pid] for pid in rival_diff_ids]

        # Captains
        user_cap = next((p for p in user_squad.starting_xi if p.pick.is_captain), user_squad.starting_xi[0])
        rival_cap = next((p for p in rival_squad.starting_xi if p.pick.is_captain), rival_squad.starting_xi[0])

        user_cap_pts = user_cap.live_points * user_cap.pick.multiplier
        rival_cap_pts = rival_cap.live_points * rival_cap.pick.multiplier
        cap_delta = user_cap_pts - rival_cap_pts

        user_total = user_squad.manager.overall_points or 0
        rival_total = rival_squad.manager.overall_points or 0
        overall_gap = user_total - rival_total
        gw_gap = user_squad.gameweek_points - rival_squad.gameweek_points

        # Summary verdict
        if gw_gap > 0:
            verdict = f"Leading by +{gw_gap} pts in GW{gameweek}. "
        elif gw_gap < 0:
            verdict = f"Trailing by {gw_gap} pts in GW{gameweek}. "
        else:
            verdict = f"Level on points in GW{gameweek}. "

        if cap_delta != 0:
            cap_sign = "+" if cap_delta > 0 else ""
            verdict += f"Captaincy swing: {user_cap.player.web_name} ({user_cap_pts} pts) vs {rival_cap.player.web_name} ({rival_cap_pts} pts) yields {cap_sign}{cap_delta} pts delta."
        else:
            verdict += "Captaincy pick neutralized."

        return HeadToHeadComparison(
            user_manager_id=user_manager_id,
            user_team_name=user_squad.manager.team_name,
            user_player_name=user_squad.manager.player_name,
            rival_manager_id=rival_manager_id,
            rival_team_name=rival_squad.manager.team_name,
            rival_player_name=rival_squad.manager.player_name,
            gameweek=gameweek,
            overall_points_gap=overall_gap,
            gameweek_points_gap=gw_gap,
            user_captain_name=user_cap.player.web_name,
            user_captain_multiplier=user_cap.pick.multiplier,
            user_captain_pts=user_cap_pts,
            rival_captain_name=rival_cap.player.web_name,
            rival_captain_multiplier=rival_cap.pick.multiplier,
            rival_captain_pts=rival_cap_pts,
            captain_points_delta=cap_delta,
            user_differentials=user_differentials,
            rival_differentials=rival_differentials,
            shared_players=shared_players,
            summary_verdict=verdict
        )


fpl_client = FPLClient()
