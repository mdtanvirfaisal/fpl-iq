from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    APP_NAME: str = "FPL IQ Backend"
    APP_VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = False

    # FPL API Settings
    FPL_BASE_URL: str = "https://fantasy.premierleague.com/api"
    FPL_USER_AGENT: str = "FPL-IQ-Engine/1.0 (https://fpliq.app)"
    FPL_TIMEOUT_SECONDS: float = 12.0
    FPL_MAX_RETRIES: int = 3
    FPL_BACKOFF_FACTOR: float = 1.5

    # Cache TTLs (in seconds)
    CACHE_BOOTSTRAP_TTL: int = 300  # 5 minutes for general players/teams
    CACHE_LIVE_TTL: int = 20        # 20 seconds for live gameweek stats
    CACHE_PICKS_TTL: int = 60       # 1 minute for manager gameweek picks
    CACHE_MANAGER_TTL: int = 300    # 5 minutes for manager profile

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
