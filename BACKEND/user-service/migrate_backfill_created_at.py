"""One-time migration: backfill `created_at` for accounts created before
this field existed.

Why this exists
----------------
`create_user()` has set `created_at` on every NEW account for a while now,
but the accounts that already existed in production BEFORE that change have
no such field. `/users/stats/public` (used by the public website for the
"registered explorers" counter and the community-growth chart) skips any
user without `created_at` when building `weekly_growth` - by design, so the
chart never shows invented dates. The unintended side effect: on a database
where EVERY user predates the field, `weekly_growth` comes back completely
empty and the "Comptes créés" line sits flat at 0 forever, even though
`total_users` (which doesn't depend on `created_at`) is correct.

This script is a one-time fix for the affected accounts, not a workaround
in the API itself - the site's own comments are explicit that the chart
should never show fabricated historical dates, so we don't try to guess
when someone actually signed up. Instead we stamp affected accounts with
"now" (the migration's run time), which is the most honest true statement
available: it is genuinely when we started tracking them. Past growth
before that point is simply unrecoverable - it was never recorded.

Usage (on the server, from backend/user-service/):
    python3 migrate_backfill_created_at.py            # dry run, prints what would change
    python3 migrate_backfill_created_at.py --apply     # actually writes the change

Safe to run more than once: users that already have `created_at` (including
ones this script already fixed) are left untouched.
"""
import sys
from datetime import datetime, timezone

from app import storage
from app.config import USERS_FILE


def main():
    apply = "--apply" in sys.argv
    users = storage.get_users()
    missing = [u for u in users if not u.get("created_at")]

    if not missing:
        print("Nothing to do - every user already has created_at.")
        return

    print(f"{len(missing)} of {len(users)} users have no created_at:")
    for u in missing:
        print(f"  - {u.get('id')}  {u.get('full_name')}  <{u.get('email')}>")

    if not apply:
        print("\nDry run only - re-run with --apply to write this change.")
        return

    now = datetime.now(timezone.utc).isoformat()
    for u in missing:
        u["created_at"] = now

    storage._write(USERS_FILE, users)
    print(f"\nDone - stamped {len(missing)} users with created_at = {now}.")
    print("They'll now count towards this week in the community-growth chart.")


if __name__ == "__main__":
    main()
