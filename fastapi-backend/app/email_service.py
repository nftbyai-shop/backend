import asyncio
import smtplib
import ssl
from email.message import EmailMessage

from dotenv import load_dotenv

from app.settings import get_settings

load_dotenv()

settings = get_settings()


async def async_send_email(
    from_address: str,
    to_addres: str,
    subject: str,
    content: str,
):
    await asyncio.to_thread(_send_email, from_address, to_addres, subject, content)


def _send_email(
    from_address: str,
    to_addres: str,
    subject: str,
    content: str,
):
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = from_address
    msg["To"] = to_addres
    msg.set_content(content)
    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(
        settings.SMTP_HOST, 465, context=context, timeout=30
    ) as server:
        # server.set_debuglevel(1)
        if from_address == settings.SMTP_USER:
            server.login(settings.SMTP_USER, settings.SMTP_PASS)
        else:
            server.login(settings.SMTP_NFTBYAI_USER, settings.SMTP_NFTBYAI_PASS)
        server.send_message(msg)


async def send_confirmation_email_text(
    crossmint_user_wallet_sign_in_url: str,
    user_email: str,
    support_email: str = settings.SMTP_NFTBYAI_USER,
):
    """
    Build and send a plain-text confirmation email via your existing async_send_email.
    """

    body = (
        "==============================\n"
        + "      PURCHASE RECEIPT       \n"
        + "==============================\n\n"
        + "Thank you for your purchase!\n\n"
        + f"You can access your NFT here:\n{crossmint_user_wallet_sign_in_url}\n\n"
        + f"Please log in with: {user_email}\n"
        + "If you don’t see your NFT within 30 minutes,\n"
        + "try refreshing your collection or contact support.\n\n"
        + f"Support: {support_email}\n"
    )
    subject = "Your NFT Purchase Confirmation"

    await async_send_email(
        from_address=settings.SMTP_NFTBYAI_USER,
        to_addres=user_email,
        content=body,
        subject=subject,
    )
