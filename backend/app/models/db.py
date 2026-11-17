import time
from sqlalchemy import Column, Integer, String, Float, Boolean, Text, ForeignKey
from app.core.database import Base


class UserDB(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String(120), unique=True, index=True, nullable=True)
    timezone = Column(String(50), default="UTC")
    created_at = Column(String(50), default=lambda: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))


class FplManagerDB(Base):
    __tablename__ = "fpl_managers"

    id = Column(Integer, primary_key=True, index=True)  # FPL Manager ID
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    display_name = Column(String(100), default="FPL Team")
    player_name = Column(String(100), default="")
    overall_points = Column(Integer, default=0)
    overall_rank = Column(Integer, nullable=True)
    last_synced_at = Column(String(50), default=lambda: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))


class SquadSnapshotDB(Base):
    __tablename__ = "squad_snapshots"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    manager_id = Column(Integer, index=True)
    gameweek = Column(Integer, index=True)
    player_id = Column(Integer, index=True)
    position = Column(Integer)  # 1 to 15
    multiplier = Column(Integer, default=1)
    is_captain = Column(Boolean, default=False)
    is_vice_captain = Column(Boolean, default=False)
    points = Column(Integer, default=0)


class WatchlistDB(Base):
    __tablename__ = "watchlist"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, default=1)
    player_id = Column(Integer, index=True)
    added_at = Column(String(50), default=lambda: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    alert_preferences = Column(Text, nullable=True)


class ScenarioDB(Base):
    __tablename__ = "saved_scenarios"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    manager_id = Column(Integer, index=True)
    name = Column(String(100))
    target_gameweek = Column(Integer)
    squad_plan_json = Column(Text)
    chip_plan = Column(String(50), nullable=True)
    created_at = Column(String(50), default=lambda: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))


class NotificationDB(Base):
    __tablename__ = "notifications"

    id = Column(String(50), primary_key=True, index=True)
    priority = Column(String(20), default="normal")
    category = Column(String(50), default="player_events")
    title = Column(String(150))
    body = Column(Text)
    timestamp = Column(String(50))
    read = Column(Boolean, default=False)
    deep_link = Column(String(100), nullable=True)
