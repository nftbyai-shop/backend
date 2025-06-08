from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict


# Your enum
class ImageQuality(str, Enum):
    standard = "standard"
    hd = "hd"
    high = "high"
    low = "low"


class NftModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    timestamp: datetime
    name: str
    description: str
    # owner: str
    ipfs_cid: str
    contract_address: str
    chain_name: str
    image_idea_llm: str
    image_title_llm: str
    image_gen_model: str
    image_idea_prompt: list[dict[str, str]]
    image_title_prompt: list[dict[str, str]]
    image_gen_prompt: str | list[dict[str, str]]
    image_size: str
    image_quality: ImageQuality
    image_url: str
    # s3_object_name: str
    # s3_bucket_name: str
