import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import Base, engine, wait_for_db
from app.routers import health, items

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(_: FastAPI):
    wait_for_db()
    Base.metadata.create_all(bind=engine)  # use Alembic migrations for real projects
    yield


app = FastAPI(title="Python + MySQL API", lifespan=lifespan)
app.include_router(health.router)
app.include_router(items.router)


@app.get("/")
def root():
    return {"message": "API is running", "docs": "/docs"}
