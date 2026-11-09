from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = None


class ItemOut(ItemCreate):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
