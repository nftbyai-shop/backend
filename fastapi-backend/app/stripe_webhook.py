import asyncio
import logging
import traceback

import stripe
from eth_abi.abi import encode
from eth_utils.abi import function_signature_to_4byte_selector
from fastapi import FastAPI, Header, HTTPException, Request
from hexbytes import HexBytes
from httpx import Response
from pg8000 import IntegrityError
from sqlalchemy import select

from app.db_connection import get_async_sessionmaker
from app.email_service import async_send_email, send_confirmation_email_text
from app.helper import async_fetch_with_retry
from app.models import CheckoutFulfillment, Nft
from app.settings import get_settings

# Sub-app without CORS
webhook_app = FastAPI()

endpoint_secret: str = get_settings().STRIPE_WEBHOOK_SIGNING_SECRET

logger = logging.getLogger()


@webhook_app.post("/")
async def stripe_webhook(
    request: Request, stripe_signature: str = Header()
) -> dict[str, str]:
    payload: bytes = await request.body()
    sig_header: str = stripe_signature
    try:
        event: stripe.Event = await asyncio.to_thread(
            stripe.Webhook.construct_event, payload, sig_header, endpoint_secret
        )
        print(event)

    except (ValueError, stripe.error.SignatureVerificationError):
        raise HTTPException(status_code=400)
    if (
        event["type"] == "checkout.session.completed"
        or event["type"] == "checkout.session.async_payment_succeeded"
    ) and event["data"]["object"]["payment_status"] == "paid":
        try:
            await fulfill_checkout(
                event["data"]["object"]["id"], event["data"]["object"]["customer_email"]
            )
        except Exception as e:
            logger.exception(
                f"Couldn't fulfill the order, session_id: {event['data']['object']['id']}",
            )
            email_content = f"Couldn't fulfill the order, session_id: {event['data']['object']['id']}\n"
            email_content += "Event object: \n" + str(event) + "\n\n"
            email_content += "Traceback: \n" + traceback.format_exc()
            await async_send_email(
                from_address=get_settings().SMTP_USER,
                to_addres=get_settings().REPORT_TO_EMAIL,
                content=email_content,
                subject=f"From {get_settings().environment} fastapi-backend",
            )
            raise e
        return {"status": "fulfilled", "status_code": "200"}
    return {"status_code": "200"}


async def fulfill_checkout(session_id: str, user_email: str) -> None:
    session_maker = get_async_sessionmaker()

    async with session_maker() as db_session:
        db_session.add(CheckoutFulfillment(session_id=session_id))

        try:
            await db_session.commit()
        except IntegrityError:
            print(
                "The fulfill_checkout() has already been invoked for session_id: ",
                session_id,
            )
            return None

    response: stripe.ListObject[stripe.LineItem] = (
        stripe.checkout.Session.list_line_items(session_id)
    )

    product_id: str = response.data[0]["price"]["product"]

    s3_product_id: str = product_id.replace("prod_", "")

    async with session_maker() as db_session:
        product_nft: Nft | None = await db_session.scalar(
            select(Nft).where(Nft.s3_object_name == s3_product_id)
        )
        if not product_nft:
            raise RuntimeError(
                "Couldn't find an nft in the database with s3_object_name = "
                + s3_product_id
            )
        if not product_nft.available_for_sale:
            raise RuntimeError(
                f"CRITICAL ERROR, NFT THAT IS NOT AVAILABLE IS REQUESTED IN FULLFILL_CHECKOUT FUNCTION!!!! NFT_DB_ID:{product_nft.id} NFT_S3_ID:{product_nft.s3_object_name}"
            )

        product_nft.available_for_sale = False
        await db_session.commit()

        settings = get_settings()
        data = {
            "type": "evm-smart-wallet",
            "linkedUser": f"email:{user_email}",
        }
        if settings.environment == "production":
            wallets_url = "https://www.crossmint.com/api/2022-06-09/wallets"
        else:
            wallets_url = "https://staging.crossmint.com/api/2022-06-09/wallets"

        create_wallet_response: Response = await async_fetch_with_retry(
            method="POST",
            url=wallets_url,
            headers={
                "X-API-KEY": settings.CROSSMINT_SECRET_KEY,
                "Content-Type": "application/json",
                "x-idempotency-key": f"{session_id}",
            },
            json=data,
        )

        user_wallet_address: str = create_wallet_response.json().get("address", "")

        if not user_wallet_address:
            raise RuntimeError("Couldn't create/get crossmint user-wallet")

        from_address = settings.NFTBYAI_WALLET_ADDRESS
        print("from_address: ", from_address)
        to_address = f"{user_wallet_address}"
        print("to_address: ", to_address)
        token_id = int(product_nft.token_id)
        print("token_id: ", token_id)
        print("nft_contract_address: ", product_nft.contract_address)
        selector = function_signature_to_4byte_selector(
            "transferFrom(address,address,uint256)"
        )
        encoded_params = encode(
            ["address", "address", "uint256"], [from_address, to_address, token_id]
        )
        data = selector + encoded_params
        print(f"0x{HexBytes(data).hex()}")
        # send transaction
        if settings.environment == "production":
            transfer_nft_url = f"https://www.crossmint.com/api/2022-06-09/wallets/{settings.NFTBYAI_WALLET_ADDRESS}/transactions"
        else:
            transfer_nft_url = f"https://staging.crossmint.com/api/2022-06-09/wallets/{settings.NFTBYAI_WALLET_ADDRESS}/transactions"

        headers = {
            "Content-Type": "application/json",
            "X-API-KEY": settings.CROSSMINT_SECRET_KEY,
            "x-idempotency-key": session_id,
        }

        if get_settings().environment == "production":
            chain = "polygon"
        else:
            chain = "polygon-amoy"
            
        data = {
            "params": {
                "call": {
                    "to": product_nft.contract_address,
                    "data": "0x" + data.hex(),
                },
                "chain": chain,
            }
        }
        transfer_nft_response = await async_fetch_with_retry(
            method="POST", url=transfer_nft_url, headers=headers, json=data
        )
        print("transfer_nft_response:\n")
        print(transfer_nft_response.content)
        transfer_nft_response.raise_for_status()
        product_nft.owner = "email:" + user_email + ":polygon"
        await db_session.commit()

        if settings.environment == "production":
            crossmint_user_wallet_sign_in_url = (
                "https://www.crossmint.com/user/collection"
            )
        else:
            crossmint_user_wallet_sign_in_url = (
                "https://staging.crossmint.com/user/collection"
            )
        await send_confirmation_email_text(
            crossmint_user_wallet_sign_in_url, user_email=user_email
        )
