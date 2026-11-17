# FPL IQ — Fantasy Premier League Command Centre

Turn FPL data into timely, personalized decisions. FPL IQ monitors a manager’s squad, watchlist, rivals and the wider player market, then explains what matters to their points and rank.

Based on [PRD.md](PRD.md) (Product Requirements Document v1.0).

---

## Architecture Overview

```
FPL IQ/
├── PRD.md                         # Core Product Requirements Document
├── docker-compose.yml             # Full-stack Docker orchestration (Backend + Worker + DB)
├── start.bat / start.ps1          # One-click Windows launch scripts
│
├── backend/                       # Python FastAPI Analytical Backend
│   ├── Dockerfile                 # Production container image
│   ├── app/
│   │   ├── api/v1/router.py       # REST endpoints (squad, live, rank, leagues, planner, FDR, notifications, trends, advisor, OCR)
│   │   ├── core/
│   │   │   ├── config.py          # App configuration & cache TTL settings
│   │   │   └── database.py        # SQLAlchemy database engine (SQLite / PostgreSQL)
│   │   ├── engine/
│   │   │   ├── rank_impact.py     # Signature Rank-Impact & relative swing engine
│   │   │   ├── bonus.py           # Official tie-breaking Provisional Bonus engine
│   │   │   ├── planner.py         # Transfer constraint validator & Chip Simulator
│   │   │   ├── advisor.py         # Grounded AI FPL Advisor & Squad Health engine
│   │   │   └── ocr_import.py      # Screenshot squad importer & name matcher
│   │   ├── models/
│   │   │   ├── fpl.py             # Pydantic v2 schemas
│   │   │   └── db.py              # SQLAlchemy database ORM models
│   │   ├── services/fpl/
│   │   │   ├── client.py          # Resilient FPL client with backoff & smart caching
│   │   │   ├── watchlist_store.py # Persistent watchlist JSON store
│   │   │   └── notification_store.py # Notifications & alert preferences engine
│   │   ├── workers/
│   │   │   └── poller.py          # Background live matchday event ingestion worker
│   │   └── main.py                # FastAPI entrypoint with CORS & DB migration
│   └── tests/test_fpl.py          # 24 Unit & live FPL integration tests
│
└── mobile/                        # Flutter Mobile App (iOS / Android)
    ├── lib/
    │   ├── core/theme.dart        # Premier League signature dark theme
    │   ├── models/squad.dart      # Dart models matching backend schemas
    │   ├── services/api_service.dart # HTTP API client
    │   └── features/
    │       ├── home/              # Main navigation shell, squad pitch view & OCR dialog
    │       ├── live/              # Live Match Centre with provisional bonus & timeline
    │       ├── advisor/           # AI FPL Advisor (Health score, captaincy, transfer upgrades)
    │       ├── planner/           # Transfers, FDR Ticker, & Market Trends
    │       ├── leagues/           # Mini-League standings & Head-to-Head Rival Radar
    │       ├── notifications/     # Alert Feed with priorities & preferences modal
    │       └── watchlist/         # Player search & status tracking
    └── test/widget_test.dart      # 8 Widget & deserialization tests
```

---

## Complete Capabilities Delivered (100% PRD Scope)

1. **Manager ID & Screenshot OCR Squad Import (Section 7.1 ONB-01 & ONB-02)**
   - Import any public manager team via ID.
   - Screenshot OCR import: parses text lines, fuzzy-matches player names against all 600+ Premier League players, and automatically proposes Starting XI, Bench, and Captaincy.

2. **Squad Pitch Visualizer (Section 7.1 ONB-03)**
   - Responsive football pitch displaying starting XI and bench.
   - Captaincy badges (`C`, `TC`, `V`), live points, injury flags, and form.

3. **Signature Rank Impact Engine (Section 7.3 & 10.3)**
   - Computes: $\text{Relative Impact} \approx (\text{User Multiplier} - \text{Cohort EO}) \times \text{Player Points}$.
   - Evaluates net exposure and relative point swings against rank cohorts (Top 10k, Top 100k, Overall).
   - Interactive slider sheet on every player card to simulate hypothetical match event swings.

4. **Live Match Centre & Provisional Bonus Points (Section 7.2 LIVE-01 to LIVE-06)**
   - Match cards for active gameweek with real-time statuses (`Upcoming`, `Live 64'`, `FT (Provisional Bonus)`, `Full Time`).
   - Match event timeline (goals, assists, cards, saves, penalties).
   - Official BPS bonus tie-breaking system strictly distinguishing **Provisional** estimates from **Official Finalized** bonus points.

5. **Mini-Leagues & Head-to-Head Rival Radar (Section 7.3 & ONB-05)**
   - Auto-detection of all classic mini-leagues for a manager.
   - Live league standings table with rank avatars and event scores.
   - Head-to-Head Rival Comparison sheet:
     - Live Gameweek points gap indicator
     - **Captaincy Clash** (points delta between captains)
     - **Differentials Radar** (User differentials vs Rival threat differentials vs Shared core)

6. **Transfer Planner, Chip Simulator & FDR Ticker (Section 7.5, 7.6, 7.7)**
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

7. **Notification Alert Engine & Market Trends (Section 7.8, 7.9, 12)**
   - **Priority-Ranked Notifications**:
     - Priority tiers: `CRITICAL`, `HIGH`, `NORMAL`, `LOW`.
     - Granular user preferences: toggle match events, rank impact, injuries, market trends, deadline countdowns, and overnight **Quiet Hours** (23:00 – 07:00).
   - **Injury & Availability Feed**:
     - Aggregates official availability flags (`d` doubtful, `i` injured, `s` suspended), chance-of-playing percentages, reasons, and timestamps.
   - **Market Transfer Trends**:
     - Real-time ranking of the most transferred in (GW buy targets) and most transferred out (GW exits) players in the Premier League.

8. **Grounded AI FPL Advisor (Section 7.10)**
   - **Squad Health Score**: 0–100 evaluation based on starter form, bench depth, and injury liability.
   - **Armband Verdict**: Tactical algorithm ranking captain and vice-captain options using form, opponent FDR, home advantage, and ownership risk.
   - **Budget-Aware Transfer Upgrades**: Evaluates low-performing or injured starters and proposes 1-to-1 replacements within the manager's exact bank balance.
   - **Grounded Verification**: Displays the exact statistical inputs used (avoiding hallucinated pricing or availability).

9. **Live Background Poller Worker (Section 10)**
   - `MatchEventPoller` daemon polls live matches, detects events, deduplicates triggers, and writes prioritized alerts directly to the notification feed.

10. **Database & Production Ready (Section 10.2)**
    - SQLAlchemy 2.0 ORM data layer (`fpl_iq.db` SQLite default, PostgreSQL/Supabase ready).
    - Multi-stage Docker containerization and `docker-compose.yml`.

---

## Verification & Testing

### Backend Tests
```powershell
.\backend\.venv\Scripts\pytest -c backend\pytest.ini backend\tests -v
```
**24/24 tests passing (100% pass rate)**.

### Mobile Tests & Analysis
```powershell
cd mobile
flutter analyze
flutter test
```
**0 analysis issues**, **8/8 widget & model tests passing (100% pass rate)**.

---

## How to Run

### Method 1: Local Single Command
Double click `start.bat` or run:
```powershell
.\start.ps1
```

### Method 2: Docker Compose (Backend + Poller + Postgres)
```bash
docker compose up -d
```

### Method 3: Flutter Mobile Client
```powershell
cd mobile
flutter run
```
Interactive Backend Swagger API docs are accessible at: `http://localhost:8000/docs`.
