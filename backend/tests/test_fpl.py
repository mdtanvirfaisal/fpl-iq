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
