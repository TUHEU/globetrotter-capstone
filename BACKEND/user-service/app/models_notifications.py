from pydantic import BaseModel

class Notification(BaseModel):
    id: str
    user_id: str
    type: str
    title: str
    body: str
    actor_id: str | None = None
    actor_name: str | None = None
    created_at: str
    read: bool = False
