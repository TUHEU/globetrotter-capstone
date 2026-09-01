from fastapi import APIRouter, Depends
from .. import storage
from ..routers.auth import get_current_user

router = APIRouter(prefix="/notifications", tags=["notifications"])

@router.get("")
def list_notifications(current=Depends(get_current_user)):
    items = storage.get_notifications(current["id"])
    items.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return {
        "results": items[:100],
        "unread": sum(1 for x in items if not x.get("read", False)),
    }

@router.post("/{notification_id}/read")
def read_notification(notification_id: str, current=Depends(get_current_user)):
    return {"ok": storage.mark_notification_read(notification_id, current["id"])}

@router.post("/read-all")
def read_all(current=Depends(get_current_user)):
    return {"ok": storage.mark_all_notifications_read(current["id"])}
