import asyncio
import smtplib
from email.message import EmailMessage

from backend.core.config import Settings
from backend.domain.auth.exceptions import EmailDeliveryFailedError, EmailDeliveryNotConfiguredError


def _build_verification_message(settings: Settings, to_email: str, code: str) -> EmailMessage:
    message = EmailMessage()
    message["Subject"] = f"{settings.app_name} email verification"
    message["From"] = settings.email_from_address
    message["To"] = to_email
    verify_instructions = (
        f"Open {settings.app_base_url} and enter this code to finish verifying your email."
        if settings.app_base_url
        else "Open the app and enter this code to finish verifying your email."
    )
    message.set_content(
        "\n".join(
            [
                f"Your {settings.app_name} verification code is: {code}",
                "",
                verify_instructions,
                "",
                f"This code expires in {settings.email_verification_code_ttl_seconds // 60} minutes.",
                "",
                "If you did not request this, you can ignore this email.",
            ]
        )
    )
    return message


def _send_message(settings: Settings, message: EmailMessage) -> None:
    if not settings.smtp_host or not settings.email_from_address:
        raise EmailDeliveryNotConfiguredError("SMTP email delivery is not configured")

    try:
        if settings.smtp_use_ssl:
            with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=20) as smtp:
                if settings.smtp_username:
                    smtp.login(settings.smtp_username, settings.smtp_password.get_secret_value())
                smtp.send_message(message)
            return

        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as smtp:
            if settings.smtp_use_tls:
                smtp.starttls()
            if settings.smtp_username:
                smtp.login(settings.smtp_username, settings.smtp_password.get_secret_value())
            smtp.send_message(message)
    except EmailDeliveryNotConfiguredError:
        raise
    except Exception as exc:  # pragma: no cover
        raise EmailDeliveryFailedError("Could not send verification email") from exc


async def send_verification_email(settings: Settings, *, to_email: str, code: str) -> None:
    message = _build_verification_message(settings, to_email, code)
    await asyncio.to_thread(_send_message, settings, message)
