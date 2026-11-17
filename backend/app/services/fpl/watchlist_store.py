import json
import os
import time
from typing import Set, List, Dict, Any

WATCHLIST_FILE = os.path.join(os.path.dirname(__file__), "..", "..", "..", "data", "watchlist.json")


class WatchlistStore:
    def __init__(self):
        self._watchlist: Dict[int, Dict[str, Any]] = {}
        self._load()

    def _load(self):
        try:
            if os.path.exists(WATCHLIST_FILE):
                with open(WATCHLIST_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self._watchlist = {int(k): v for k, v in data.items()}
        except Exception:
            self._watchlist = {}

    def _save(self):
        try:
            os.makedirs(os.path.dirname(WATCHLIST_FILE), exist_ok=True)
            with open(WATCHLIST_FILE, "w", encoding="utf-8") as f:
                json.dump(self._watchlist, f, indent=2)
        except Exception:
            pass

    def get_all(self) -> List[Dict[str, Any]]:
        return list(self._watchlist.values())

    def get_player_ids(self) -> Set[int]:
        return set(self._watchlist.keys())

    def add(self, player_id: int) -> bool:
        if player_id not in self._watchlist:
            self._watchlist[player_id] = {
                "player_id": player_id,
                "added_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            }
            self._save()
            return True
        return False

    def remove(self, player_id: int) -> bool:
        if player_id in self._watchlist:
            del self._watchlist[player_id]
            self._save()
            return True
        return False


watchlist_store = WatchlistStore()
