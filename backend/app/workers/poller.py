"""
Background Live Matchday Event Poller & Notification Ingestion Worker.
Implements Section 7.2 and Section 7.9 of the PRD:
- Monitors live matches and scorelines
- Detects goals, assists, red cards, and provisional bonus movements
- Dispatches deduplicated push-ready alerts to NotificationStore
"""
import asyncio
import logging
from typing import Set, Dict, Any, Optional
from app.services.fpl.client import fpl_client
from app.services.fpl.notification_store import notification_store

logger = logging.getLogger("FPLIQ-Poller")


class MatchEventPoller:
    def __init__(self, poll_interval_seconds: int = 30):
        self.poll_interval = poll_interval_seconds
        self.is_running = False
        self._seen_event_keys: Set[str] = set()

    def _generate_event_key(self, match_id: int, event_type: str, element_id: int, count: int) -> str:
        return f"{match_id}:{event_type}:{element_id}:{count}"

    async def poll_once(self) -> int:
        """
        Executes one polling cycle. Returns number of newly detected events.
        """
        try:
            live_resp = await fpl_client.get_live_match_center()
            new_events_count = 0

            for match in live_resp.matches:
                if not match.started:
                    continue

                for event in match.events:
                    key = self._generate_event_key(match.id, event.event_type, event.element_id, event.count)
                    if key not in self._seen_event_keys:
                        self._seen_event_keys.add(key)
                        new_events_count += 1

                        # Determine priority and copy based on event type (Appendix A)
                        if event.event_type == "goal":
                            priority = "high"
                            title = f"GOAL! {event.player_name} ({event.team_short_name})"
                            body = f"{event.player_name} scored in {match.home_team.short_name} vs {match.away_team.short_name} (live {match.status_display})."
                        elif event.event_type == "red_card":
                            priority = "critical"
                            title = f"RED CARD! {event.player_name} ({event.team_short_name})"
                            body = f"{event.player_name} was sent off in {match.home_team.short_name} vs {match.away_team.short_name}."
                        elif event.event_type == "assist":
                            priority = "normal"
                            title = f"Assist: {event.player_name} ({event.team_short_name})"
                            body = f"{event.player_name} recorded an assist in {match.home_team.short_name} vs {match.away_team.short_name}."
                        else:
                            priority = "normal"
                            title = f"Match Event: {event.player_name}"
                            body = f"{event.event_type.replace('_', ' ').capitalize()} recorded for {event.player_name}."

                        notification_store.add_notification(
                            priority=priority,
                            category="player_events",
                            title=title,
                            body=body,
                            deep_link="/live"
                        )

            return new_events_count
        except Exception as e:
            logger.error(f"Error during polling cycle: {e}")
            return 0

    async def run_daemon(self):
        self.is_running = True
        logger.info("MatchEventPoller daemon started.")
        while self.is_running:
            await self.poll_once()
            await asyncio.sleep(self.poll_interval)

    def stop(self):
        self.is_running = False


poller = MatchEventPoller()
