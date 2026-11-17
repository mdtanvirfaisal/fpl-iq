from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class PlayerSummary(BaseModel):
    id: int
    web_name: str
    first_name: str
    second_name: str
    team_id: int
    element_type: int  # 1: GKP, 2: DEF, 3: MID, 4: FWD
    position_name: str  # GKP, DEF, MID, FWD
    now_cost: float     # In millions e.g. 10.5
    cost_raw: int       # In tenths e.g. 105
    status: str         # 'a', 'd', 'i', 's', 'u'
    chance_of_playing_next_round: Optional[int] = None
    news: Optional[str] = None
    news_added: Optional[str] = None
    total_points: int
    selected_by_percent: float
    form: float
    event_points: int = 0


class TeamSummary(BaseModel):
    id: int
    name: str
    short_name: str
    strength: Optional[int] = 3
    strength_overall_home: Optional[int] = None
    strength_overall_away: Optional[int] = None
    strength_attack_home: Optional[int] = None
    strength_attack_away: Optional[int] = None
    strength_defence_home: Optional[int] = None
    strength_defence_away: Optional[int] = None


class GameweekEvent(BaseModel):
    id: int
    name: str
    deadline_time: str
    is_current: bool
    is_next: bool
    finished: bool


class ManagerProfile(BaseModel):
    id: int
    player_name: str
    team_name: str
    region: Optional[str] = None
    overall_points: Optional[int] = None
    overall_rank: Optional[int] = None
    last_deadline_bank: Optional[float] = None
    last_deadline_value: Optional[float] = None
    last_deadline_total_transfers: Optional[int] = None


class SquadPick(BaseModel):
    element_id: int
    position: int  # 1-15
    multiplier: int  # 0: bench, 1: starter, 2: captain, 3: triple captain
    is_captain: bool
    is_vice_captain: bool


class EnrichedSquadPlayer(BaseModel):
    player: PlayerSummary
    team: TeamSummary
    pick: SquadPick
    live_points: int = 0
    is_starter: bool = True


class SquadResponse(BaseModel):
    manager: ManagerProfile
    gameweek: int
    active_chip: Optional[str] = None
    starting_xi: List[EnrichedSquadPlayer]
    bench: List[EnrichedSquadPlayer]
    gameweek_points: int = 0
    is_live: bool = False
    data_freshness_ts: str


class RankImpactRequest(BaseModel):
    player_id: int
    player_name: str
    points: int
    user_multiplier: int = 1
    cohort_effective_ownership: float = Field(..., description="EO as percentage e.g. 135.5% or 45.0%")
    cohort_name: str = "Overall Top 100k"
    rival_name: Optional[str] = None
    rival_multiplier: Optional[int] = None


class RankImpactResult(BaseModel):
    player_id: int
    player_name: str
    points: int
    user_effective_ownership: float
    cohort_effective_ownership: float
    net_exposure: float
    relative_points_swing: float
    impact_category: str  # "significantly_positive", "positive", "neutral", "negative", "significantly_negative"
    summary_text: str
    provisional: bool = False
    confidence_level: str = "Estimated"


class MatchEvent(BaseModel):
    event_type: str  # goal, assist, own_goal, yellow_card, red_card, penalty_saved, penalty_missed
    element_id: int
    player_name: str
    team_short_name: str
    is_home: bool
    count: int = 1


class BonusSummary(BaseModel):
    element_id: int
    player_name: str
    bps: int
    bonus_points: int
    is_provisional: bool
    is_home: bool


class FixtureMatch(BaseModel):
    id: int
    gameweek: int
    kickoff_time: str
    started: bool
    finished: bool
    finished_provisional: bool
    minutes: int
    home_team: TeamSummary
    away_team: TeamSummary
    home_score: Optional[int] = None
    away_score: Optional[int] = None
    events: List[MatchEvent] = []
    bonus_candidates: List[BonusSummary] = []
    status_display: str


class LiveMatchCenterResponse(BaseModel):
    gameweek: int
    matches: List[FixtureMatch]
    data_freshness_ts: str


class WatchlistPlayerItem(BaseModel):
    player: PlayerSummary
    team: TeamSummary
    added_at: str


class ClassicLeagueSummary(BaseModel):
    id: int
    name: str
    entry_rank: Optional[int] = None
    entry_last_rank: Optional[int] = None
    league_type: str = "x"  # 's' broad/general, 'x' private mini-league


class LeagueStandingEntry(BaseModel):
    entry_id: int
    entry_name: str
    player_name: str
    rank: int
    last_rank: Optional[int] = None
    event_total: int
    total: int


class LeagueStandingsResponse(BaseModel):
    league_id: int
    league_name: str
    standings: List[LeagueStandingEntry]


class HeadToHeadComparison(BaseModel):
    user_manager_id: int
    user_team_name: str
    user_player_name: str
    rival_manager_id: int
    rival_team_name: str
    rival_player_name: str
    gameweek: int
    overall_points_gap: int  # user - rival
    gameweek_points_gap: int  # user - rival
    user_captain_name: str
    user_captain_multiplier: int
    user_captain_pts: int
    rival_captain_name: str
    rival_captain_multiplier: int
    rival_captain_pts: int
    captain_points_delta: int  # (user_captain * mult) - (rival_captain * mult)
    user_differentials: List[EnrichedSquadPlayer]
    rival_differentials: List[EnrichedSquadPlayer]
    shared_players: List[EnrichedSquadPlayer]
    summary_verdict: str
