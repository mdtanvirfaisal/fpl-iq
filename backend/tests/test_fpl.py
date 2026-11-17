import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app
from app.models.fpl import RankImpactRequest
from app.engine.rank_impact import calculate_rank_impact


def test_rank_impact_differential_haul():
    # User owns player as starter (100% EO), Top 100k cohort only has 10% EO.
    # Player scores 12 points (goal + assist + bonus).
    req = RankImpactRequest(
        player_id=101,
        player_name="Mitoma",
        points=12,
        user_multiplier=1,
        cohort_effective_ownership=10.0,
        cohort_name="Top 100k"
    )
    res = calculate_rank_impact(req)

    assert res.user_effective_ownership == 100.0
    assert res.net_exposure == 90.0
    # Swing = 0.90 * 12 = 10.8 pts
    assert res.relative_points_swing == 10.8
    assert res.impact_category == "significantly_positive"
    assert "boosted your rank" in res.summary_text


def test_rank_impact_non_owned_essential():
    # User does NOT own player (0% EO), cohort has 160% EO (heavily captained).
    # Player scores 8 points.
    req = RankImpactRequest(
        player_id=202,
        player_name="Haaland",
        points=8,
        user_multiplier=0,
        cohort_effective_ownership=160.0,
        cohort_name="Overall Top 10k"
    )
    res = calculate_rank_impact(req)

    assert res.user_effective_ownership == 0.0
    assert res.net_exposure == -160.0
    # Swing = -1.60 * 8 = -12.8 pts
    assert res.relative_points_swing == -12.8
    assert res.impact_category == "significantly_negative"
    assert "hurt your rank" in res.summary_text


def test_rank_impact_with_rival_comparison():
    # User has Salah captain (200%), rival has Salah as vice (started, 100%).
    # Salah scores 10 points.
    req = RankImpactRequest(
        player_id=303,
        player_name="Salah",
        points=10,
        user_multiplier=2,
        cohort_effective_ownership=140.0,
        rival_name="John Doe",
        rival_multiplier=1
    )
    res = calculate_rank_impact(req)

    assert res.user_effective_ownership == 200.0
    # Against rival: (200 - 100) / 100 * 10 = +10 pts
    assert "Against rival John Doe: +10 pts delta" in res.summary_text


@pytest.mark.asyncio
async def test_health_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["app"] == "FPL IQ Backend"


@pytest.mark.asyncio
async def test_rank_impact_endpoint():
    payload = {
        "player_id": 50,
        "player_name": "Palmer",
        "points": 15,
        "user_multiplier": 2,
        "cohort_effective_ownership": 90.0,
        "cohort_name": "Top 10k"
    }
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.post("/api/v1/rank/impact", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["player_name"] == "Palmer"
        assert data["relative_points_swing"] == 16.5  # (200 - 90)/100 * 15 = 1.1 * 15 = 16.5
        assert data["impact_category"] == "significantly_positive"


@pytest.mark.asyncio
async def test_live_fpl_integration_manager_and_squad():
    """
    Live test against official FPL endpoints for Entry ID 1.
    Verifies bootstrap, manager, and squad parsing.
    """
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Check manager profile
        mgr_resp = await ac.get("/api/v1/manager/1")
        assert mgr_resp.status_code == 200
        mgr_data = mgr_resp.json()
        assert mgr_data["id"] == 1
        assert "team_name" in mgr_data

        # Check squad retrieval
        squad_resp = await ac.get("/api/v1/manager/1/squad")
        assert squad_resp.status_code == 200
        squad_data = squad_resp.json()
        assert len(squad_data["starting_xi"]) == 11
        assert len(squad_data["bench"]) == 4
        assert squad_data["gameweek"] >= 1


from app.engine.bonus import calculate_provisional_bonus


def test_provisional_bonus_standard():
    home_bps = [{'element': 1, 'value': 45}, {'element': 2, 'value': 28}]
    away_bps = [{'element': 3, 'value': 35}, {'element': 4, 'value': 12}]

    candidates = calculate_provisional_bonus(home_bps, away_bps, is_match_final=False)
    # Ranks:
    # 1: elem 1 (45 BPS) -> 3 pts
    # 2: elem 3 (35 BPS) -> 2 pts
    # 3: elem 2 (28 BPS) -> 1 pt
    assert len(candidates) == 3
    assert candidates[0].element_id == 1
    assert candidates[0].bonus_points == 3
    assert candidates[0].is_provisional is True

    assert candidates[1].element_id == 3
    assert candidates[1].bonus_points == 2

    assert candidates[2].element_id == 2
    assert candidates[2].bonus_points == 1


def test_provisional_bonus_tied_for_first():
    # Two players tied with 40 BPS
    home_bps = [{'element': 10, 'value': 40}]
    away_bps = [{'element': 20, 'value': 40}, {'element': 30, 'value': 30}]

    candidates = calculate_provisional_bonus(home_bps, away_bps, is_match_final=False)
    # Both 10 & 20 should receive 3 bonus pts. Next player receives 1 bonus pt.
    assert len(candidates) == 3
    assert candidates[0].bonus_points == 3
    assert candidates[1].bonus_points == 3
    assert candidates[2].element_id == 30
    assert candidates[2].bonus_points == 1


@pytest.mark.asyncio
async def test_live_matches_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.get("/api/v1/live/matches?gameweek=10")
        assert resp.status_code == 200, f"Error: {resp.status_code} - {resp.text}"
        data = resp.json()
        assert data["gameweek"] == 10
        assert len(data["matches"]) > 0
        match = data["matches"][0]
        assert "home_team" in match
        assert "away_team" in match
        assert "bonus_candidates" in match


@pytest.mark.asyncio
async def test_watchlist_workflow():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Search for Haaland
        search_resp = await ac.get("/api/v1/players/search?q=Haaland")
        assert search_resp.status_code == 200
        players = search_resp.json()
        assert len(players) > 0
        haaland = players[0]
        assert "Haaland" in haaland["web_name"]

        # Add to watchlist
        add_resp = await ac.post(f"/api/v1/watchlist/{haaland['id']}")
        assert add_resp.status_code == 200

        # Retrieve watchlist
        list_resp = await ac.get("/api/v1/watchlist")
        assert list_resp.status_code == 200
        tracked = list_resp.json()
        assert any(item["player"]["id"] == haaland["id"] for item in tracked)

        # Remove from watchlist
        del_resp = await ac.delete(f"/api/v1/watchlist/{haaland['id']}")
        assert del_resp.status_code == 200
        assert del_resp.json()["status"] == "removed"


@pytest.mark.asyncio
async def test_manager_leagues_and_standings():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        leagues_resp = await ac.get("/api/v1/manager/1/leagues")
        assert leagues_resp.status_code == 200
        leagues = leagues_resp.json()
        assert len(leagues) > 0
        first_league = leagues[0]
        assert "name" in first_league

        # Fetch standings
        standings_resp = await ac.get(f"/api/v1/leagues/{first_league['id']}/standings")
        assert standings_resp.status_code == 200
        standings_data = standings_resp.json()
        assert "standings" in standings_data


@pytest.mark.asyncio
async def test_head_to_head_rival_comparison():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Compare entry 1 with entry 1 (symmetric test)
        resp = await ac.get("/api/v1/manager/1/rival/1/compare")
        assert resp.status_code == 200
        data = resp.json()
        assert data["user_manager_id"] == 1
        assert data["rival_manager_id"] == 1
        assert data["gameweek_points_gap"] == 0
        assert data["captain_points_delta"] == 0
        assert len(data["shared_players"]) == 11
        assert len(data["user_differentials"]) == 0
        assert "Captaincy pick neutralized" in data["summary_verdict"]
