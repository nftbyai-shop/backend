import base64
import datetime
import json
import logging
import os
import sys
import time
import uuid
from typing import Any
import boto3
import json_logging
import requests
from openai import OpenAI
from openai.types.chat.chat_completion import ChatCompletion
from openai.types.images_response import ImagesResponse
from shared.models import Nft
from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_random_exponential,
)
import urllib.parse


def lambda_handler(event, context):
    aws_session_token = os.environ.get('AWS_SESSION_TOKEN')
    response = requests.get('http://localhost:2773/systemsmanager/parameters/get?name=db_password', headers={'X-Aws-Parameters-Secrets-Token':aws_session_token})
    resp_js= response.json()
    print("ssm response is: ", resp_js)
    config = urllib.request.urlopen(req).read()
    ssm = boto3.client("ssm",config=boto3.session.Config(connect_timeout=10, read_timeout=10,retries = { "max_attempts": 4 }))
    DB_USER: str = os.environ["DB_USER"]
    DB_HOST: str = os.environ["DB_HOST"]
    DB_NAME: str = os.environ["DB_NAME"]
    DB_PORT = 5432
    REGION: str = os.environ["REGION"]
    rds = boto3.client('rds', region_name=REGION)
    auth_token = rds.generate_db_auth_token(DB_HOST, DB_PORT, DB_USER)
    engine: Engine = create_engine(
        f"postgresql+pg8000://{DB_USER}:{urllib.parse.quote_plus(auth_token)}@{DB_HOST}/{DB_NAME}"
    )
    CROSSMINT_API_KEY_SSM_PATH: str = os.environ["CROSSMINT_API_KEY_SSM_PATH"]
    CROSSMINT_API_KEY: str = ssm.get_parameter(
        Name=CROSSMINT_API_KEY_SSM_PATH, WithDecryption=True
    )d
    OPENAI_API_KEY_SSM_PATH: str = os.environ["OPENAI_API_KEY_SSM_PATH"]
    OPENAI_API_KEY: str = ssm.get_parameter(
        Name=OPENAI_API_KEY_SSM_PATH, WithDecryption=True
    )
    COLLECTION_ID: str = os.environ["COLLECTION_ID"]
    NFT_RECIPIENT: str = os.environ["NFT_RECIPIENT"]
    GPT_MODEL_1: str = os.environ["GPT_MODEL_1"]
    IMAGE_GEN_MODEL: str = os.environ["IMAGE_GEN_MODEL"]
    S3_BUCKET: str = os.environ["S3_BUCKET"]
    LOG_LEVEL: str = os.environ["LOG_LEVEL"]
    IMAGE_SIZE: str = os.environ["IMAGE_SIZE"]
    IMAGE_QUALITY: str = os.environ["IMAGE_QUALITY"]

    json_logging.init_non_web(enable_json=True)
    logger: logging.Logger = logging.getLogger("nft-producer-service")
    logger.setLevel(LOG_LEVEL)
    logger.addHandler(logging.StreamHandler(sys.stdout))

    try:
        # Generate idea
        client = OpenAI(api_key=OPENAI_API_KEY)
        image_idea_prompt: Any = [
            {
                "role": "developer",
                "content": "Don't provide any follow-up suggestions. Just clear response.",
            },
            {
                "role": "user",
                "content": "Give me a sick, random and truly unique idea for an image.",
            },
        ]
        completion: ChatCompletion = client.chat.completions.create(
            model=GPT_MODEL_1,
            messages=image_idea_prompt,
            temperature=1.50,
        )
        image_idea: str | None = completion.choices[0].message.content
        if not image_idea:
            raise RuntimeError("Failed to generate image idea text")

        # Generate short title for idea
        title_prompt: Any = [
            {
                "role": "user",
                "content": f"Generate 1-5 word catchy and provocative title for this image description: {image_idea}",
            }
        ]
        completion2: ChatCompletion = client.chat.completions.create(
            model=GPT_MODEL_1,
            messages=title_prompt,
        )
        image_title: str | None = completion2.choices[0].message.content
        logger.debug(f"image idea: {image_idea}")
        logger.debug(f"image title: {image_title}")

        result: ImagesResponse = client.images.generate(
            model=IMAGE_GEN_MODEL,
            prompt=image_idea,
            size=IMAGE_SIZE,
            quality=image_quality,
            response_format="b64_json",
            n=1,
        )
        image_base64 = result.data[0].b64_json
        image_bytes: bytes = base64.b64decode(image_base64)

        # Write image to s3
        image_s3_key = uuid.uuid4()
        s3 = boto3.client("s3")
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=str(image_s3_key),
            Body=image_bytes,
            ContentType="image/jpeg",
        )

        # Create url for s3 image
        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": str(image_s3_key)},
            ExpiresIn=3600,
        )
        logger.debug(f"Image url: {url}")

        # Mint image into nft
        payload: dict[str, Any] = {
            "metadata": {
                "name": image_title,
                "image": url,
                "description": image_idea,
            },
            "recipient": NFT_RECIPIENT,
            "sendNotification": True,
            "locale": "en-US",
            "reuploadLinkedFiles": True,
            "compressed": True,
        }
        headers: dict[str, str] = {
            "X-API-KEY": CROSSMINT_API_KEY,
            "Content-Type": "application/json",
        }

        crossmint_mint_url: str = f"https://staging.crossmint.com/api/2022-06-09/collections/{COLLECTION_ID}/nfts"
        response: requests.Response = fetch(
            "POST", crossmint_mint_url, json=payload, headers=headers
        )
        logger.debug("\n\nMint response:")
        pretty_print_response(response)
        response_json: Any = response.json()
        chain_name: str = response_json["onChain"]["chain"]
        contract_address: str = response_json["onChain"]["contractAddress"]
        crossmint_id: str = response_json["id"]

        # Get mint status
        retry = 8
        delay = 30  # seconds
        crossmint_mint_status_url = f"https://staging.crossmint.com/api/2022-06-09/collections/{COLLECTION_ID}/nfts/{crossmint_id}"
        cid = None
        attempt = 0
        while not cid and attempt < 6:
            try:
                response: requests.Response = fetch(
                    "GET",
                    crossmint_mint_status_url,
                    headers={"X-API-KEY": CROSSMINT_API_KEY},
                )
                logger.debug("\n\nMint status")
                pretty_print_response(response)

                json_response = response.json()
                cid = json_response["metadata"]["image"].strip("ipfs://")
            except Exception:
                time.sleep(30)
                attempt += 1
        if not cid:
            raise RuntimeError("Couldn't get nft cid.")

        nft = Nft(
            timestamp=datetime.datetime.now(),
            name=image_title,
            description=image_idea,
            owner=NFT_RECIPIENT,
            ipfs_cid=cid,
            contract_address=contract_address,
            chain_name=chain_name,
            image_idea_llm=GPT_MODEL_1,
            image_title_llm=GPT_MODEL_1,
            image_gen_model=IMAGE_GEN_MODEL,
            image_idea_prompt=image_idea_prompt,
            image_title_prompt=title_prompt,
            image_gen_prompt=image_idea,
            image_size=IMAGE_SIZE,
            image_quality=IMAGE_QUALITY,
            s3_object_name=image_s3_key,
            s3_bucket_name=S3_BUCKET,
        )

        with Session(engine) as session:
            session.add(nft)
            session.commit()

        return {"Total": "Success"}
    except Exception:
        logger.exception("Error in nft-producer-service")
        sys.exit(1)


def pretty_print_response(response: requests.Response) -> None:
    logger.debug(f"Status: {response.status_code} {response.reason}")
    logger.debug("Headers:")
    for k, v in response.headers.items():
        logger.debug(f"  {k}: {v}")

    logger.debug("\nBody:")
    content_type = response.headers.get("Content-Type", "")
    if "application/json" in content_type:
        try:
            logger.debug(json.dumps(response.json(), indent=2))
        except ValueError:
            logger.debug("  [Invalid JSON]")
    else:
        logger.debug(response.text)


@retry(
    wait=wait_random_exponential(
        max=60,
    ),
    stop=stop_after_attempt(7),
    retry=retry_if_exception_type(requests.exceptions.RequestException),
    reraise=True,
)
def fetch(method: str, url: str, **kwargs: Any) -> requests.Response:
    kwargs.setdefault("timeout", 10)
    response = requests.request(
        method,
        url,
        **kwargs,
    )
    response.raise_for_status()
    return response
