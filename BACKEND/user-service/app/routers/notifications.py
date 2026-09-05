from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from .. import storage
from ..routers.auth import get_current_user

router = APIRouter(prefix="/notifications", tags=["notifications"])


class MentionRequest(BaseModel):
    user_id: str
    context: str = Field(description="Where the mention happened, e.g. 'Chat Global' or a destination name")
    preview: str = Field(default="", max_length=200)


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


@router.post("/mention", status_code=201)
def mention(body: MentionRequest, current=Depends(get_current_user)):
    """Called by Chat Service and Recommendation Service (forwarding the
    tagging user's own bearer token, same token-propagation pattern as
    every other cross-service call in this project) whenever someone
    @-mentions another user in the Global chat or in a destination review.
    Deliberately does not check any follow/friend relationship - being
    mentioned by a stranger in a public chat or public review thread is
    normal, unlike being DMed by one (which the /messages endpoints do
    restrict).
    """
    if body.user_id == current["id"]:
        return {"ok": True}  # tagging yourself doesn't need a notification
    storage.add_notification(
        user_id=body.user_id,
        type_="mention",
        title=f"{current.get('full_name', 'Quelqu\u2019un')} vous a mentionné",
        body=f"{body.context} : {body.preview}" if body.preview else body.context,
        actor_id=current["id"],
        actor_name=current.get("full_name"),
    )
    return {"ok": True}
