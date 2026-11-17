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


from app.engine.planner import simulate_transfer_plan
from app.models.fpl import TeamSummary, PlayerSummary, EnrichedSquadPlayer, SquadPick


def test_transfer_planner_budget_deficit():
    # Setup mock squad with bank 1.0
    from app.models.fpl import SquadPick

    dummy_team = TeamSummary(id=1, name="Arsenal", short_name="ARS", strength=4)
    p_out = PlayerSummary(
        id=10, web_name="OutPlayer", first_name="A", second_name="B",
        team_id=1, element_type=3, position_name="MID", now_cost=5.0, cost_raw=50,
        status="a", total_points=50, selected_by_percent=5.0, form=4.0, event_points=2
    )
    squad_player = EnrichedSquadPlayer(
        player=p_out, team=dummy_team,
        pick=SquadPick(element_id=10, position=1, multiplier=1, is_captain=False, is_vice_captain=False),
        live_points=2, is_starter=True
    )

    p_in_expensive = PlayerSummary(
        id=99, web_name="ExpensiveIn", first_name="C", second_name="D",
        team_id=2, element_type=3, position_name="MID", now_cost=12.0, cost_raw=120,
        status="a", total_points=100, selected_by_percent=20.0, form=7.0, event_points=5
    )

    # Initial bank is £1.0m. Out gives £5.0m. In costs £12.0m. Deficit is £6.0m.
    result = simulate_transfer_plan(
        current_players=[squad_player],
        incoming_players=[p_in_expensive],
        teams_map={1: dummy_team, 2: TeamSummary(id=2, name="Chelsea", short_name="CHE", strength=3)},
        initial_bank=1.0,
        transfers_out_ids=[10]
    )

    assert result.valid is False
    assert "Insufficient funds" in result.validation_error


def test_transfer_planner_hits_and_wildcard():
    from app.models.fpl import SquadPick
    dummy_team = TeamSummary(id=1, name="Arsenal", short_name="ARS", strength=4)

    players_out = [
        PlayerSummary(id=i, web_name=f"Out{i}", first_name="A", second_name="B",
                      team_id=1, element_type=3, position_name="MID", now_cost=6.0, cost_raw=60,
                      status="a", total_points=50, selected_by_percent=5.0, form=4.0, event_points=2)
        for i in [1, 2, 3]
    ]
    squad = [
        EnrichedSquadPlayer(
            player=p, team=dummy_team,
            pick=SquadPick(element_id=p.id, position=idx+1, multiplier=1, is_captain=False, is_vice_captain=False),
            live_points=2, is_starter=True
        )
        for idx, p in enumerate(players_out)
    ]
    players_in = [
        PlayerSummary(id=i+100, web_name=f"In{i}", first_name="X", second_name="Y",
                      team_id=i+2, element_type=3, position_name="MID", now_cost=6.0, cost_raw=60,
                      status="a", total_points=50, selected_by_percent=5.0, form=4.0, event_points=2)
        for i in [1, 2, 3]
    ]

    # Standard scenario: 3 transfers with 1 free transfer -> 2 extra transfers = 8 pts hit
    res_hits = simulate_transfer_plan(
        current_players=squad,
        incoming_players=players_in,
        teams_map={1: dummy_team, 3: dummy_team, 4: dummy_team, 5: dummy_team},
        initial_bank=1.0,
        transfers_out_ids=[1, 2, 3],
        free_transfers=1
    )
    assert res_hits.valid is True
    assert res_hits.points_cost == 8

    # Wildcard chip scenario: hits waived
    res_wc = simulate_transfer_plan(
        current_players=squad,
        incoming_players=players_in,
        teams_map={1: dummy_team, 3: dummy_team, 4: dummy_team, 5: dummy_team},
        initial_bank=1.0,
        transfers_out_ids=[1, 2, 3],
        free_transfers=1,
        active_chip="wildcard"
    )
    assert res_wc.valid is True
    assert res_wc.points_cost == 0


@pytest.mark.asyncio
async def test_fixture_ticker_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.get("/api/v1/fixtures/ticker?count=5")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 20  # All 20 clubs
        arsenal = next((c for c in data if c["team_short_name"] == "ARS"), None)
        assert arsenal is not None
        assert len(arsenal["fixtures"]) <= 5
        if arsenal["fixtures"]:
            assert 1 <= arsenal["fixtures"][0]["difficulty"] <= 5


@pytest.mark.asyncio
async def test_planner_simulate_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Load manager 1 squad to pick a player to swap
        squad_resp = await ac.get("/api/v1/manager/1/squad")
        squad_data = squad_resp.json()
        player_to_sell = squad_data["starting_xi"][0]["player"]["id"]

        # Search for a replacement
        search_resp = await ac.get("/api/v1/players/search?q=Gabriel")
        gabriel = search_resp.json()[0]["id"]

        payload = {
            "manager_id": 1,
            "transfers_out": [player_to_sell],
            "transfers_in": [gabriel],
            "free_transfers": 1,
            "active_chip": None
        }
        sim_resp = await ac.post("/api/v1/planner/simulate", json=payload)
        assert sim_resp.status_code == 200
        sim_result = sim_resp.json()
        assert "valid" in sim_result
        assert sim_result["transfers_count"] == 1
