from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app

engine = create_engine(
    "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
)
TestingSession = sessionmaker(bind=engine, expire_on_commit=False)
Base.metadata.create_all(engine)


def override_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_db
client = TestClient(app)  # no context manager -> lifespan (MySQL wait) is skipped


def test_live():
    assert client.get("/health/live").status_code == 200


def test_item_crud():
    r = client.post("/items", json={"name": "demo", "description": "hello"})
    assert r.status_code == 201
    item_id = r.json()["id"]
    assert client.get(f"/items/{item_id}").json()["name"] == "demo"
    assert client.delete(f"/items/{item_id}").status_code == 204
    assert client.get(f"/items/{item_id}").status_code == 404
