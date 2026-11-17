# FPL IQ — Fantasy Premier League Command Centre

Turn FPL data into timely, personalized decisions. FPL IQ monitors a manager’s squad, watchlist, rivals and the wider player market, then explains what matters to their points and rank.

Based on [PRD.md](PRD.md) (Product Requirements Document v1.0).

---

## Architecture Overview

```
FPL IQ/
├── PRD.md                    # Core Product Requirements Document
├── backend/                  # Python FastAPI Analytical Backend
│   ├── app/
│   │   ├── api/v1/router.py  # REST endpoints (health, bootstrap, squad, rank impact)
│   │   ├── core/config.py    # Configuration & cache TTL settings
│   │   ├── engine/           # Signature Rank-Impact & swing calculation engine
│   │   ├── models/fpl.py     # Pydantic v2 schemas for squad, manager, players
│   │   ├── services/fpl/     # Resilient FPL API client with backoff & smart cache
│   │   └── main.py           # FastAPI application entrypoint with CORS
│   └── tests/test_fpl.py     # Unit & live FPL integration tests
│
└── mobile/                   # Flutter Mobile App (iOS / Android)
    ├── lib/
    │   ├── core/theme.dart   # Premier League signature dark theme
    │   ├── models/squad.dart # Dart models matching backend schemas
    │   ├── services/         # API client
    │   └── features/
    │       ├── home/         # Dashboard & Rank Impact intelligence sheet
    │       └── squad/        # Interactive football pitch visualizer & bench
    └── test/widget_test.dart # Widget & model tests
```

---

## Getting Started

### 1. Backend (FastAPI)

1. Activate virtual environment:
   ```powershell
   .\backend\.venv\Scripts\Activate.ps1
   ```

2. Run tests:
   ```powershell
   .\backend\.venv\Scripts\pytest -c backend\pytest.ini backend\tests -v
   ```

3. Start backend API server:
   ```powershell
   .\backend\.venv\Scripts\uvicorn app.main:app --reload --port 8000
   ```
   Interactive Swagger docs are accessible at: `http://localhost:8000/docs`.

### 2. Mobile App (Flutter)

1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```

2. Run analyzer and tests:
   ```bash
   flutter test
   ```

3. Launch on connected device, emulator, or Chrome:
   ```bash
   flutter run
   ```

---

## Phase 1 Capabilities Implemented

- **FPL Live Data Ingestion**: Direct connection with `fantasy.premierleague.com/api` endpoints (`bootstrap-static/`, `entry/{id}/`, `entry/{id}/event/{gw}/picks/`, `event/{gw}/live/`, `fixtures/`).
- **Resilient Caching & Backoff**: Exponential retry backoff, endpoint TTL caching, and rate-limiting protection.
- **Squad & Pitch Visualizer**: Responsive football pitch representation of starting XI with captaincy multipliers (`C`, `TC`, `V`) and designated bench order.
- **Rank Impact Intelligence**: Evaluates relative points swing against rank cohorts (Top 10k, Top 100k) and direct rivals using:
  $$\text{Relative Impact} \approx (\text{User Multiplier} - \text{Cohort EO}) \times \text{Player Points}$$
