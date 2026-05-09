#!/usr/bin/env python3
"""Send the EPUB (or any file) as a Gmail attachment via SMTP.

Requires:
    GMAIL_USER             Gmail address used as sender
    GMAIL_APP_PASSWORD     16-char app password from Google account
                           (https://myaccount.google.com/apppasswords)

Optional:
    A `.env` file in the repo root or scripts/ — KEY=VALUE per line.

Usage:
    python scripts/send_epub.py \
        --to gzonelee@gmail.com \
        --subject "Swift/SwiftUI 심화 가이드 EPUB" \
        --attach swift-swiftui-심화가이드.epub
"""

from __future__ import annotations

import argparse
import mimetypes
import os
import smtplib
import ssl
import sys
from email.message import EmailMessage
from pathlib import Path


SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 465  # SSL


def load_dotenv(paths: list[Path]) -> None:
    """Minimal .env loader — only sets vars that aren't already set."""
    for path in paths:
        if not path.is_file():
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value


def build_message(
    sender: str,
    recipients: list[str],
    subject: str,
    body: str,
    attachments: list[Path],
) -> EmailMessage:
    msg = EmailMessage()
    msg["From"] = sender
    msg["To"] = ", ".join(recipients)
    msg["Subject"] = subject
    msg.set_content(body)

    for path in attachments:
        if not path.is_file():
            raise FileNotFoundError(f"Attachment not found: {path}")
        ctype, encoding = mimetypes.guess_type(path.name)
        if ctype is None or encoding is not None:
            ctype = "application/octet-stream"
        maintype, subtype = ctype.split("/", 1)
        msg.add_attachment(
            path.read_bytes(),
            maintype=maintype,
            subtype=subtype,
            filename=path.name,
        )
    return msg


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    load_dotenv([repo_root / ".env", repo_root / "scripts" / ".env"])

    parser = argparse.ArgumentParser(description="Send EPUB via Gmail SMTP")
    parser.add_argument("--to", action="append", required=True,
                        help="Recipient (repeat for multiple)")
    parser.add_argument("--subject", required=True)
    parser.add_argument("--body", default="첨부 파일을 확인해주세요.",
                        help="Plain-text body")
    parser.add_argument("--attach", action="append", default=[],
                        help="Path to attachment (repeat for multiple)")
    args = parser.parse_args()

    user = os.environ.get("GMAIL_USER")
    password = os.environ.get("GMAIL_APP_PASSWORD")
    if not user or not password:
        print("ERROR: GMAIL_USER / GMAIL_APP_PASSWORD must be set "
              "(via env or .env file).", file=sys.stderr)
        return 2

    attachments = [Path(p).expanduser().resolve() for p in args.attach]
    msg = build_message(
        sender=user,
        recipients=args.to,
        subject=args.subject,
        body=args.body,
        attachments=attachments,
    )

    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=context) as smtp:
        smtp.login(user, password)
        smtp.send_message(msg)

    total_bytes = sum(p.stat().st_size for p in attachments)
    print(f"Sent to {', '.join(args.to)} — "
          f"{len(attachments)} attachment(s), {total_bytes:,} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
