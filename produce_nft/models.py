import enum
from datetime import datetime
from typing import Any, Dict

from sqlalchemy import TIMESTAMP, Boolean, String, func, text
from sqlalchemy import Enum as PgEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class ImageQuality(str, enum.Enum):
    standard = "standard"
    medium = "medium"
    hd = "hd"
    high = "high"
    low = "low"


class Nft(Base):
    __tablename__ = "nfts"
    id: Mapped[int] = mapped_column(primary_key=True)
    timestamp: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True),  # stores TZ info
        server_default=func.now(),  # DB sets value
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(String(1000), nullable=False)
    owner: Mapped[str] = mapped_column(
        String(300),
        nullable=False,
        info={
            "description": "<chain>:<address> | email:<addr>:<chain> "
            "| userId:<id>:<chain> | twitter:<handle>:<chain>"
        },
    )
    ipfs_cid: Mapped[str] = mapped_column(String(200), nullable=False)
    contract_address: Mapped[str] = mapped_column(String(200), nullable=False)
    token_id: Mapped[str] = mapped_column(String(200), nullable=True)
    chain_name: Mapped[str] = mapped_column(String(200), nullable=False)
    image_idea_llm: Mapped[str] = mapped_column(String(100), nullable=False)
    image_title_llm: Mapped[str] = mapped_column(String(100), nullable=False)
    image_gen_model: Mapped[str] = mapped_column(String(100), nullable=False)
    image_idea_prompt: Mapped[Dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default="{}"
    )
    image_title_prompt: Mapped[Dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default="{}"
    )  # TODO
    image_gen_prompt: Mapped[Dict[str, Any]] = mapped_column(
        JSONB,
        nullable=False,
        server_default=text("'{}'::jsonb"),
    )
    image_size: Mapped[str] = mapped_column(String(50), nullable=False)
    image_quality: Mapped[ImageQuality] = mapped_column(
        PgEnum(ImageQuality), nullable=False
    )
    s3_object_name: Mapped[str] = mapped_column(String(100), nullable=False)
    s3_bucket_name: Mapped[str] = mapped_column(String(100), nullable=False)
    available_for_sale: Mapped[bool] = mapped_column(
        Boolean(), nullable=False, server_default="1", default=True
    )


class FulfillmentStatusEnum(str, enum.Enum):
    processing = "processing"
    fulfilled = "fulfilled"


class CheckoutFulfillment(Base):
    """
    One row per Stripe Checkout Session you *attempt* to fulfill.
    `session_id` is the idempotency key.
    """

    __tablename__ = "checkout_fulfillments"

    session_id: Mapped[str] = mapped_column(String(100), primary_key=True)

    fulfillment_status: Mapped[FulfillmentStatusEnum] = mapped_column(
        PgEnum(FulfillmentStatusEnum, name="fulfillment_status_enum"),
        default=FulfillmentStatusEnum.processing,
        server_default=text("'processing'"),
        nullable=False,
    )

    fulfilled_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=True,
    )
