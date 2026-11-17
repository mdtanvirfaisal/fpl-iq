# FPL IQ — Fantasy Premier League Command Centre

Turn FPL data into timely, personalized decisions. FPL IQ monitors a manager’s squad, watchlist, rivals and the wider player market, then explains what matters to their points and rank.

Based on [PRD.md](PRD.md) (Product Requirements Document v1.0).

---

## Architecture Overview

```
FPL IQ/
├── PRD.md                         # Core Product Requirements Document
├── backend/                       # Python FastAPI Analytical Backend
│   ├── app/
│   │   ├── api/v1/router.py       # REST endpoints (squad, live, rank, leagues, planner, FDR, notifications, trends, injuries)
│   │   ├── core/config.py         # App configuration & cache TTL settings
│   │   ├── engine/
│   │   │   ├── rank_impact.py     # Signature Rank-Impact & relative swing engine
│   │   │   ├── bonus.py           # Official tie-breaking Provisional Bonus engine
│   │   │   └── planner.py         # Transfer constraint validator & Chip Simulator
│   │   ├── models/fpl.py          # Pydantic v2 schemas
│   │   ├── services/fpl/
│   │   │   ├── client.py          # Resilient FPL client with backoff & smart caching
│   │   │   ├── watchlist_store.py # Persistent watchlist JSON store
│   │   │   └── notification_store.py # Notifications & alert preferences engine
│   │   └── main.py                # FastAPI entrypoint with CORS
│   └── tests/test_fpl.py          # 19 Unit & live FPL integration tests
│
└── mobile/                        # Flutter Mobile App (iOS / Android)
    ├── lib/
    │   ├── core/theme.dart        # Premier League signature dark theme
    │   ├── models/squad.dart      # Dart models matching backend schemas
    │   ├── services/api_service.dart # HTTP API client
    │   └── features/
    │       ├── home/              # Main navigation shell & squad pitch view
    │       ├── live/              # Live Match Centre with provisional bonus & timeline
    │       ├── planner/           # Transfers, FDR Ticker, & Market Trends
    │       ├── leagues/           # Mini-League standings & Head-to-Head Rival Radar
    │       ├── notifications/     # Alert Feed with priorities & preferences modal
    │       └── watchlist/         # Player search & status tracking
    └── test/widget_test.dart      # 6 Widget & deserialization tests
```

---

## Delivered MVP Capabilities (Phases 1–5)

1. **Phase 1: Foundation & FPL Data Ingestion Spike**
   - Connected with official `fantasy.premierleague.com/api` endpoints (`bootstrap-static/`, `entry/{id}/`, `entry/{id}/event/{gw}/picks/`, `event/{gw}/live/`, `fixtures/`).
   - Resilient caching, rate-limit backoff, and loop-safe connection pooling.
   - Interactive Football Pitch layout with captain multipliers (`C`, `TC`, `V`), injury flags, and bench order.
   - Core Rank Impact model:
     $$\text{Relative Impact} \approx (\text{User Multiplier} - \text{Cohort EO}) \times \text{Player Points}$$

2. **Phase 2: Live Match Centre & Provisional Bonus Points**
   - Live fixture cards with real-time match statuses (`Live 64'`, `FT (Provisional Bonus)`, `Full Time`).
   - Match event timeline (goals, assists, cards, saves, penalties).
   - Official BPS bonus tie-breaking system strictly distinguishing **Provisional** estimates from **Official Finalized** bonus points.
   - Persistent Watchlist store with instant player search across all 600+ Premier League players.

3. **Phase 3: Mini-Leagues & Head-to-Head Rival Radar**
   - Auto-detection of all classic mini-leagues for a manager.
   - Live league standings table with rank badges and event scores.
   - Head-to-Head Rival Comparison sheet:
     - Live Gameweek points gap indicator
     - **Captaincy Clash** (points delta between captains)
     - **Differentials Radar** (User differentials vs Rival threat differentials vs Shared core)

4. **Phase 4: Transfer Planner, Chip Simulator & Fixture Ticker (FDR)**
   - **Transfer Scenario Simulator**:
     - Budget deficit checks (`final_bank >= 0`)
     - Premier League club limit constraint (max 3 players per club)
     - Penalty hit calculation (-4 pts per transfer beyond free transfers)
   - **Chip Simulator**:
     - **Wildcard**: Waives transfer hit costs completely
     - **Free Hit**: Simulates single-gameweek squad transformation
     - **Triple Captain**: Multiplies captain return by x3
     - **Bench Boost**: Adds bench player points to active total
   - **Fixture Difficulty Ticker (FDR)**:
     - 5-gameweek forward ticker for all 20 Premier League clubs
     - Color-coded difficulty badges (Green = Easy, Slate = Medium, Red/Orange = Hard) with Home/Away indicators (`(H)` / `(A)`).

5. **Phase 5: Notification Alert Engine, Injury Feed & Market Trends**
   - **Priority-Ranked Notifications**:
     - Priority tiers: `CRITICAL` (deadline imminent, injury crisis), `HIGH` (differential hauls, rival captain scores), `NORMAL`, `LOW`.
     - Granular user preferences: toggle match events, rank impact, injuries, market trends, deadline countdowns, and overnight **Quiet Hours** (23:00 – 07:00).
   - **Injury & Availability Feed**:
     - Aggregates official FPL availability flags (`d` doubtful, `i` injured, `s` suspended), chance-of-playing percentages, reasons, and timestamps.
   - **Market Transfer Trends**:
     - Real-time ranking of the most transferred in (GW buy targets) and most transferred out (GW exits) players in the Premier League.

---

## Verification & Testing

### Backend Tests
```powershell
.\backend\.venv\Scripts\pytest -c backend\pytest.ini backend\tests -v
```
**19/19 tests passing** (unit logic + live integration with Premier League endpoints).

### Mobile Tests & Analysis
```powershell
cd mobile
flutter analyze
flutter test
```
**0 analysis issues**, **6/6 widget & model tests passing**.

---

## How to Run

1. **Start the Backend Server:**
   ```powershell
   .\backend\.venv\Scripts\uvicorn app.main:app --reload --port 8000
   ```
   Interactive API docs are available at: `http://localhost:8000/docs`.

2. **Run the Flutter Mobile App:**
   ```powershell
   cd mobile
   flutter run
   ```
