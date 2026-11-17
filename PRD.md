# FPL IQ
## Your personal Fantasy Premier League command centre
### PRODUCT REQUIREMENTS DOCUMENT
**Version 1.0 | 18 November 2026 | Product concept and MVP specification**

**Product vision:** Turn FPL data into timely, personalized decisions. FPL IQ monitors a manager’s squad, watchlist, rivals and the wider player market, then explains what matters to their points and rank.

| Document field | Definition |
| :--- | :--- |
| **Product** | FPL IQ |
| **Platform** | Mobile-first app (Flutter); responsive web dashboard may follow |
| **Primary users** | Fantasy Premier League managers, from casual players to engaged mini-league competitors |
| **Core value** | Personalized live alerts, rank-impact intelligence and actionable planning |
| **Initial market** | Global FPL community; English-first interface |
| **Document status** | Proposed product requirements; validate data access and legal constraints before implementation |

---

## 1. Executive summary
FPL IQ is a companion app for Fantasy Premier League managers. A user imports a team using an FPL manager ID or a screenshot, selects additional players to watch, and receives personalized updates about live points, bonus estimates, injuries, lineups, transfers and deadlines. The app goes beyond score reporting by estimating how events affect the user’s overall rank and mini-league position.

The product combines five capabilities: live player monitoring, rank-impact analysis, team and chip simulation, transfer and fixture planning, and manager-market intelligence. The app is advisory: it does not make transfers or operate an FPL account on a user’s behalf.

---

## 2. Problem and opportunity
- FPL managers must check several sites and apps to understand live points, injury news, ownership, fixtures and transfer trends.
- A player’s points do not tell the whole story; the effect on rank depends on ownership, captaincy and the user’s comparison group.
- Managers need help evaluating multi-week transfer plans and chip timing, not just one-week recommendations.
- Important events can happen while users are away from the app; useful alerts need to be timely, configurable and prioritized.

---

## 3. Product goals and non-goals

### 3.1 Goals
1. Make importing a squad quick and reliable through manager ID, with screenshot import as a convenience path.
2. Provide a trustworthy live view of points, match events and provisional bonus estimates.
3. Explain estimated rank and mini-league impact using relevant ownership and captaincy data.
4. Help users plan transfers, lineups, chips and reminders across multiple future gameweeks.
5. Track injuries, suspensions, predicted/confirmed lineups and selected player news with source and timestamp.
6. Surface transfer trends among selected high-performing manager cohorts.
7. Deliver useful push notifications with controls to prevent alert fatigue.

### 3.2 Non-goals for MVP
- Executing transfers, activating chips or changing a user’s official FPL team.
- Guaranteeing rank predictions, price rises/falls, predicted lineups or injury return dates.
- Providing betting advice or financial-style guarantees.
- Reproducing every feature of a full football news platform.
- Supporting every fantasy football game before the FPL product is validated.

---

## 4. Target users and key use cases

| Persona | Needs | Representative use case |
| :--- | :--- | :--- |
| **Casual manager** | Simple live points, deadline and injury alerts | “Tell me when my players score or are ruled out.” |
| **Engaged manager** | Rank impact, watchlists, fixtures and transfers | “Did that goal help or hurt my rank?” |
| **Mini-league competitor** | Rival squads, differentials and league movement | “What happened to the gap between me and the manager above?” |
| **Data-driven manager** | Projections, ownership cohorts and scenario comparisons | “Compare these transfer plans over the next six gameweeks.” |

---

## 5. Product principles
1. **Personalized first**: prioritize the user’s squad, watchlist, rivals and rank cohort.
2. **Explain the impact**: show why an alert matters, not only what happened.
3. **Be honest about uncertainty**: label live estimates, projections and confirmed facts distinctly.
4. **User control**: let users choose players, alert categories, quiet hours and notification intensity.
5. **Trustworthy data**: show source, last-updated time and data freshness where relevant.
6. **Respect account security**: do not ask for FPL passwords or store session cookies in the MVP.

---

## 6. Information architecture and navigation

| Primary tab | Main contents |
| :--- | :--- |
| **Home** | Gameweek summary, live points, rank, high-priority alerts, deadline countdown, next actions |
| **Live** | Premier League match centre, player event timeline, live points, bonus estimates, mini-league live view |
| **Transfers** | Current squad, budget, free transfers, player comparison, transfer planner, transfer reminders |
| **Planner** | Future XI, bench order, captain/vice-captain, fixture ticker, chip simulator, saved scenarios |
| **Intelligence** | Rank impact, watchlist, differentials, top-manager trends, injury/news centre, AI advisor (later phase) |

---

## 7. Functional requirements

### 7.1 Onboarding and team import
- **ONB-01 (Must)**: Allow import by FPL manager/team ID. Valid ID loads the correct public team; invalid/private/unavailable cases show a useful explanation.
- **ONB-02 (Should)**: Allow screenshot-based squad import. OCR/vision proposes player names and positions; user confirms/corrects before saving.
- **ONB-03 (Must)**: Identify starting XI, bench, captain and vice-captain. Imported data is shown with clear source and last-updated timestamp.
- **ONB-04 (Must)**: Allow users to add multiple watchlist players outside their squad. Watchlist persists across sessions and supports add/remove/search.
- **ONB-05 (Should)**: Allow optional mini-league IDs and selected rival managers. User can add/remove leagues and rivals without sharing FPL credentials.

### 7.2 Live points and event tracking
- **LIVE-01 (Must)**: Display live gameweek points for squad players. Player points refresh according to configured backend polling and show last updated time.
- **LIVE-02 (Must)**: Track goals, assists, cards, saves, clean sheets, minutes and other FPL-scoring events. Events map to current official scoring rules and player position.
- **LIVE-03 (Must)**: Show provisional bonus points separately from confirmed bonus. UI labels estimated/provisional values and updates when official values finalize.
- **LIVE-04 (Must)**: Track watched players who are not in the user’s team. Watchlist events are visible and can trigger configured alerts.
- **LIVE-05 (Should)**: Provide a match centre and player event timeline. User can filter matches/events by own players and watchlist.
- **LIVE-06 (Should)**: Show live squad total and estimated automatic substitutions. Clearly label total as live/estimated until gameweek is finalized.

### 7.3 Rank impact intelligence
*Rank impact is a signature feature, presented as an estimate rather than an exact live rank calculation.*
- **RANK-01 (Must)**: Estimate whether an event helps or hurts the user relative to a selected comparison group.
- **RANK-02 (Should)**: Support overall-rank cohorts such as top 10k, 100k and 1m, subject to data availability.
- **RANK-03 (Must)**: Calculate mini-league impact against selected rivals. Show points gained/lost versus selected rival teams.
- **RANK-04 (Must)**: Account for captaincy and effective ownership. Captained ownership is distinguished from ordinary ownership.
- **RANK-05 (Could)**: Estimate rank movement and relative points swing with clear assumptions.
- **RANK-06 (Must)**: Send high-priority alerts for meaningful rank-impact events with customizable thresholds.

### 7.4 Injury, availability and team news
- **NEWS-01 (Must)**: Track official FPL availability flags for squad and watchlist players with flag, reason, source, and timestamp.
- **NEWS-02 (Should)**: Track suspensions and return-to-training updates from trusted sources.
- **NEWS-03 (Should)**: Show predicted and confirmed starting lineups when available with proper labeling and timestamps.
- **NEWS-04 (Must)**: Notify users when a tracked player’s status materially changes; suppress duplicates.
- **NEWS-05 (Must)**: Allow users to select players outside their squad for injury/news monitoring.

### 7.5 Transfer planner
- **TR-01 (Must)**: Show squad, bank, team value and free transfers.
- **TR-02 (Must)**: Compare players using price, position, minutes, form, fixtures and underlying stats.
- **TR-03 (Should)**: Suggest single and multi-transfer combinations across future gameweeks respecting budget/rules.
- **TR-04 (Must)**: Allow manual transfer scenarios and save multiple plans (rename, duplicate, delete).
- **TR-05 (Should)**: Estimate points over configurable horizons (e.g. 3, 5, 8 gameweeks).
- **TR-06 (Must)**: Provide transfer deadline reminders with quiet hours and custom schedules.

### 7.6 Team and chip simulator
- **SIM-01 (Must)**: Build a future squad and starting XI for a selected gameweek with valid formations and squad constraints.
- **SIM-02 (Must)**: Set captain, vice-captain and bench order, reflecting multipliers and autosubs.
- **SIM-03 (Must)**: Simulate Wildcard, Free Hit, Bench Boost and Triple Captain using active season rules.
- **SIM-04 (Should)**: Compare scenarios side by side with projected points and costs.
- **SIM-05 (Must)**: Save, rename and revisit scenarios.

### 7.7 Fixture difficulty and projections
- **FDR-01 (Must)**: Show fixture ticker for each club across future gameweeks.
- **FDR-02 (Should)**: Create separate attacking, defensive and goalkeeper difficulty scores.
- **FDR-03 (Should)**: Factor in league position, form, home/away, goals, and xG/xGA where available.
- **FDR-04 (Could)**: Show player expected points and minutes estimates with ranges/confidence.
- **FDR-05 (Should)**: Update fixture ratings dynamically with last calculated timestamps.

### 7.8 Top-manager and transfer trend tracker
- **MGR-01 (Should)**: Track transfer activity among configurable manager cohorts.
- **MGR-02 (Should)**: Show most bought/sold players, captain picks and chip usage.
- **MGR-03 (Could)**: Allow users to follow selected public managers.
- **MGR-04 (Should)**: Compare market trends with user's squad and budget.
- **MGR-05 (Must)**: Distinguish completed transfers from delayed/inferred trend signals.

### 7.9 Notifications and reminders
- Delivers push notifications through backend + Firebase Cloud Messaging (FCM).
- Granular controls: per-player, per-event, quiet hours, rank-impact thresholds, deadline schedules.
- Batching, deduplication, and deep links into relevant app screens.

### 7.10 AI FPL advisor (post-MVP)
- Natural-language advice grounded strictly in current squad, watchlist, and verified statistics.
- Explicitly disclose assumptions and projections; never hallucinate injury or pricing facts.

---

## 8. Key user journeys
1. **First-time setup**: Explanations -> Enter FPL manager ID (or OCR) -> Confirm squad -> Add watchlist/rivals -> Choose alert settings -> Land on Home.
2. **Live match alert**: Event ingested -> Points calculated -> Rank engine estimates cohort/rival impact -> Push sent via FCM -> Deep link opens event context.
3. **Transfer planning**: Select horizon -> Load current squad & budget -> Select sell/buy candidates or ask suggestions -> Compare projections/risks -> Save scenario & set reminders.

---

## 9. Screen-level requirements
- **Onboarding**: ID input, OCR upload, squad confirmation.
- **Home**: GW points, overall rank, deadline, live alerts, injury summary.
- **Squad**: Pitch/list view, starters, bench, captain, points, status flags.
- **Player detail**: Price, points, form, fixtures, stats, ownership, news, impact.
- **Live centre**: Fixtures, score, timeline, player points, filters.
- **Rank impact**: Cohort & rival comparisons, event impact, assumptions.
- **Transfer planner**: Squad, budget, free transfers, targets, projections.
- **Team/chip simulator**: Pitch, formation, captain, bench, chips.
- **Fixtures**: Club ticker, attack/defence difficulty breakdown.
- **Manager trends**: Top manager transfers, captain picks, chip trends.
- **Notifications**: Feed, preferences, mute, quiet hours.
- **Settings**: Timezone, quiet hours, privacy, data controls.

---

## 10. Data and technical architecture
- **Mobile client**: Flutter / Dart (cross-platform iOS & Android).
- **Backend API**: Python + FastAPI.
- **Database**: PostgreSQL (Supabase compatible).
- **Background workers**: Python workers for scheduled FPL polling, change detection, and push dispatch.
- **Push**: Firebase Cloud Messaging (FCM).
- **Rank impact formula**: `Relative impact ≈ (user multiplier − cohort effective ownership) × player points`.

---

## 11. MVP build order (from Section 21)
1. **Spike & API Validation**: Ingest FPL endpoints (`bootstrap-static`, `fixtures`, `entry/{id}`, `entry/{id}/event/{gw}/picks`, `event/{gw}/live`).
2. **Read-only Team Importer & Squad Screen**: Manager ID import, starting XI, bench, captain/vice-captain.
3. **Watchlist & Player Detail**: Search players, inspect metrics, manage watchlist.
4. **Backend Event Ingestion & Live Points Calculator**: Live polling, provisional bonus detection, event timeline.
5. **Push Notifications & User Preferences**: FCM integration, alert filtering, quiet hours.
6. **Rank Impact & Mini-League Engine**: Effective ownership and relative delta calculations.
7. **Transfer Planner & Chip Simulator**: Multi-gameweek planner, budget constraints, chip rules.
8. **Fixture Difficulty (FDR) & News/Trends**: Attack/defence ratings, availability feeds, cohort trends.
