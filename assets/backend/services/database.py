"""
Database Service — async SQLite via SQLAlchemy.
All models, sessions, graph nodes, etc.
"""
import json
import uuid
from datetime import datetime
from contextlib import asynccontextmanager
from typing import AsyncIterator

from sqlalchemy.ext.asyncio import (
    create_async_engine, AsyncSession, async_sessionmaker
)
from sqlalchemy import (
    Column, String, Text, Float, Integer,
    DateTime, JSON, select, text
)
from sqlalchemy.orm import DeclarativeBase
import structlog

from config.settings import settings

log = structlog.get_logger(__name__)

engine = create_async_engine(
    settings.db_url,
    echo=False,
    connect_args={"check_same_thread": False},
)

AsyncSessionLocal = async_sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)


class Base(DeclarativeBase):
    pass


# ─── ORM Models ────────────────────────────────────────────────────────────────

class ChatSessionORM(Base):
    __tablename__ = "chat_sessions"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, nullable=False, index=True)
    title = Column(String, default="New Chat")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    messages = Column(JSON, default=list)

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "title": self.title,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "messages": self.messages or [],
        }


class GraphNodeORM(Base):
    __tablename__ = "graph_nodes"
    id = Column(String, primary_key=True)
    label = Column(String, nullable=False)
    content = Column(Text, default="")
    content_type = Column(String, default="text")
    source = Column(String, default="")
    chunk_index = Column(Integer, default=0)
    community = Column(Integer, default=0)
    degree = Column(Integer, default=0)
    embedding = Column(Text, default="[]")  # JSON-encoded list
    created_at = Column(DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "label": self.label,
            "content": self.content,
            "content_type": self.content_type,
            "source": self.source,
            "chunk_index": self.chunk_index,
            "community": self.community,
            "degree": self.degree,
            "embedding": json.loads(self.embedding or "[]"),
        }


class GraphEdgeORM(Base):
    __tablename__ = "graph_edges"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    source = Column(String, nullable=False, index=True)
    target = Column(String, nullable=False, index=True)
    edge_type = Column(String, default="direct")
    weight = Column(Float, default=1.0)

    def to_dict(self):
        return {
            "source": self.source,
            "target": self.target,
            "type": self.edge_type,
            "weight": self.weight,
        }


class GSDProjectORM(Base):
    __tablename__ = "gsd_projects"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    description = Column(Text, default="")
    current_phase = Column(String, default="plan")
    created_at = Column(DateTime, default=datetime.utcnow)
    tasks = Column(JSON, default=list)

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "name": self.name,
            "description": self.description,
            "current_phase": self.current_phase,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "tasks": self.tasks or [],
        }


# ─── Async Database Helpers ────────────────────────────────────────────────────

@asynccontextmanager
async def get_db() -> AsyncIterator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def init_db():
    """Create all tables and optimize SQLite."""
    # Import Company OS models to register them with Base.metadata
    # This must happen before create_all so all tables are created
    import services.company_os.models  # noqa: F401

    async with engine.begin() as conn:
        # Optimization for speed and concurrency
        await conn.execute(text("PRAGMA journal_mode=WAL;"))
        await conn.execute(text("PRAGMA synchronous=NORMAL;"))
        await conn.run_sync(Base.metadata.create_all)
    log.info("Database initialized with WAL mode optimization")


# ─── Repository Classes ────────────────────────────────────────────────────────

class ChatSession:
    @staticmethod
    async def get_by_user(db: AsyncSession, user_id: str) -> list[ChatSessionORM]:
        result = await db.execute(
            select(ChatSessionORM)
            .where(ChatSessionORM.user_id == user_id)
            .order_by(ChatSessionORM.updated_at.desc())
        )
        return result.scalars().all()

    @staticmethod
    async def create(db: AsyncSession, user_id: str, title: str) -> ChatSessionORM:
        session = ChatSessionORM(
            id=str(uuid.uuid4()),
            user_id=user_id,
            title=title,
            messages=[],
        )
        db.add(session)
        await db.flush()
        return session

    @staticmethod
    async def get(db: AsyncSession, session_id: str) -> ChatSessionORM | None:
        result = await db.get(ChatSessionORM, session_id)
        return result


class GraphNodeDB:
    @staticmethod
    async def get_all(db: AsyncSession) -> list[dict]:
        result = await db.execute(select(GraphNodeORM))
        return [n.to_dict() for n in result.scalars().all()]

    @staticmethod
    async def create(db: AsyncSession, node: dict):
        orm = GraphNodeORM(
            id=node["id"],
            label=node["label"],
            content=node.get("content", ""),
            content_type=node.get("content_type", "text"),
            source=node.get("source", ""),
            chunk_index=node.get("chunk_index", 0),
            community=node.get("community", 0),
            degree=node.get("degree", 0),
            embedding=json.dumps(node.get("embedding", [])),
        )
        try:
            db.add(orm)
            await db.flush()
        except Exception:
            await db.rollback()
            # Already exists or other error, ignore for now
            pass

    @staticmethod
    async def delete_all(db: AsyncSession):
        from sqlalchemy import delete
        await db.execute(delete(GraphNodeORM))


class GraphEdgeDB:
    @staticmethod
    async def get_all(db: AsyncSession) -> list[dict]:
        result = await db.execute(select(GraphEdgeORM))
        return [e.to_dict() for e in result.scalars().all()]

    @staticmethod
    async def create(db: AsyncSession, edge: dict):
        orm = GraphEdgeORM(
            source=edge["source"],
            target=edge["target"],
            edge_type=edge.get("type", "direct"),
            weight=edge.get("weight", 1.0),
        )
        try:
            db.add(orm)
            await db.flush()
        except Exception:
            await db.rollback()
            pass

    @staticmethod
    async def delete_all(db: AsyncSession):
        from sqlalchemy import delete
        await db.execute(delete(GraphEdgeORM))


class GSDProjectDB:
    @staticmethod
    async def get_by_user(db: AsyncSession, user_id: str) -> list[GSDProjectORM]:
        result = await db.execute(
            select(GSDProjectORM).where(GSDProjectORM.user_id == user_id)
        )
        return result.scalars().all()

    @staticmethod
    async def create(db: AsyncSession, user_id: str,
                     name: str, description: str) -> GSDProjectORM:
        proj = GSDProjectORM(
            id=str(uuid.uuid4()),
            user_id=user_id,
            name=name,
            description=description,
        )
        db.add(proj)
        await db.flush()
        return proj

    @staticmethod
    async def get(db: AsyncSession, project_id: str) -> GSDProjectORM | None:
        return await db.get(GSDProjectORM, project_id)
