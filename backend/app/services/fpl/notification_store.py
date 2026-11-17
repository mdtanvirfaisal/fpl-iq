import json
import os
import time
import uuid
from typing import List, Dict, Any, Optional
from app.models.fpl import NotificationItem, NotificationSettings

NOTIF_FILE = os.path.join(os.path.dirname(__file__), "..", "..", "..", "data", "notifications.json")
SETTINGS_FILE = os.path.join(os.path.dirname(__file__), "..", "..", "..", "data", "notification_settings.json")


class NotificationStore:
    def __init__(self):
        self._notifications: List[Dict[str, Any]] = []
        self._settings = NotificationSettings()
        self._load()

    def _load(self):
        try:
            if os.path.exists(SETTINGS_FILE):
                with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                    self._settings = NotificationSettings.model_validate_json(f.read())
        except Exception:
            self._settings = NotificationSettings()

        try:
            if os.path.exists(NOTIF_FILE):
                with open(NOTIF_FILE, "r", encoding="utf-8") as f:
                    self._notifications = json.load(f)
            else:
                self._seed_default_notifications()
        except Exception:
            self._seed_default_notifications()

    def _seed_default_notifications(self):
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        self._notifications = [
            {
                "id": str(uuid.uuid4())[:8],
                "priority": "critical",
                "category": "deadline",
                "title": "Gameweek Deadline Approaching",
                "body": "The next Premier League deadline locks soon. Review your active XI and captaincy choice.",
                "timestamp": now,
                "read": False,
                "deep_link": "/planner"
            },
            {
                "id": str(uuid.uuid4())[:8],
                "priority": "high",
                "category": "rank_impact",
                "title": "Differential Haul Detected",
                "body": "Your starter returned double digits, delivering an estimated +9.2 pts swing vs Top 100k cohort.",
                "timestamp": now,
                "read": False,
                "deep_link": "/squad"
            },
            {
                "id": str(uuid.uuid4())[:8],
                "priority": "normal",
                "category": "injuries",
                "title": "Availability Alert: Squad Doubt",
                "body": "Bukayo Saka is flagged with a 75% chance of playing due to a knock. Tap to inspect details.",
                "timestamp": now,
                "read": True,
                "deep_link": "/squad"
            }
        ]
        self._save_notifs()

    def _save_notifs(self):
        try:
            os.makedirs(os.path.dirname(NOTIF_FILE), exist_ok=True)
            with open(NOTIF_FILE, "w", encoding="utf-8") as f:
                json.dump(self._notifications, f, indent=2)
        except Exception:
            pass

    def _save_settings(self):
        try:
            os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)
            with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
                f.write(self._settings.model_dump_json(indent=2))
        except Exception:
            pass

    def get_notifications(self) -> List[NotificationItem]:
        return [NotificationItem(**n) for n in self._notifications]

    def add_notification(
        self,
        priority: str,
        category: str,
        title: str,
        body: str,
        deep_link: Optional[str] = None
    ) -> NotificationItem:
        notif = {
            "id": str(uuid.uuid4())[:8],
            "priority": priority,
            "category": category,
            "title": title,
            "body": body,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "read": False,
            "deep_link": deep_link
        }
        self._notifications.insert(0, notif)
        self._save_notifs()
        return NotificationItem(**notif)

    def mark_as_read(self, notif_id: str) -> bool:
        for n in self._notifications:
            if n["id"] == notif_id:
                n["read"] = True
                self._save_notifs()
                return True
        return False

    def get_settings(self) -> NotificationSettings:
        return self._settings

    def update_settings(self, settings: NotificationSettings) -> NotificationSettings:
        self._settings = settings
        self._save_settings()
        return self._settings


notification_store = NotificationStore()
