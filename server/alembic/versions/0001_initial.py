"""Baseline schema.

Revision ID: 0001_initial
Revises:
Create Date: 2026-10-31

The baseline is created from the SQLAlchemy metadata so it can never drift from
the models shipped in the same commit. Later revisions should be produced with
``alembic revision --autogenerate -m "..."`` after a model change.
"""

from __future__ import annotations

from alembic import op

from app import models  # noqa: F401
from app.db import Base

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    Base.metadata.create_all(bind=op.get_bind())


def downgrade() -> None:
    Base.metadata.drop_all(bind=op.get_bind())
