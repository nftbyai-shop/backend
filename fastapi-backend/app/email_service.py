import asyncio
import smtplib
import ssl
from email.message import EmailMessage

from dotenv import load_dotenv

from app.settings import get_settings

load_dotenv()

settings = get_settings()


async def async_send_email(
    content: str, subject: str = f"From {settings.environment} fastapi-backend", to=settings.REPORT_TO_EMAIL
):
    await asyncio.to_thread(_send_email, content, subject, to)


def _send_email(
    content: str,
    subject: str = "From fastapi-backend",
    to: str = settings.REPORT_TO_EMAIL,
):
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = settings.SMTP_USER
    msg["To"] = to
    msg.set_content(content)
    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(
        settings.SMTP_HOST, 465, context=context, timeout=30
    ) as server:
        # server.set_debuglevel(1)
        server.login(settings.SMTP_USER, settings.SMTP_PASS)
        server.send_message(msg)
