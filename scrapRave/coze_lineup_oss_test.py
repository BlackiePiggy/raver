#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import mimetypes
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from email.utils import formatdate
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import quote
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from uuid import uuid4


DEFAULT_COZE_URL = "https://dxy8zryvs2.coze.site/run"
DEFAULT_BUCKET = "wen-jasonlee"
DEFAULT_ENDPOINT = "wen-jasonlee.oss-cn-shanghai.aliyuncs.com"
DEFAULT_PREFIX = "temp/"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".avif", ".tif", ".tiff", ".svg"}


def normalize_endpoint(endpoint: str, bucket: str) -> Dict[str, str]:
    ep = str(endpoint or "").strip().replace("https://", "").replace("http://", "").strip("/")
    if not ep:
        raise RuntimeError("ALIYUN_OSS_ENDPOINT is empty")
    if ep.startswith(f"{bucket}."):
        host = ep
    else:
        host = f"{bucket}.{ep}"
    return {"host": host}


def sign_oss(method: str, content_type: str, date_text: str, canonicalized_resource: str, key_id: str, key_secret: str) -> str:
    string_to_sign = f"{method}\n\n{content_type}\n{date_text}\n{canonicalized_resource}"
    digest = hmac.new(
        key_secret.encode("utf-8"),
        string_to_sign.encode("utf-8"),
        hashlib.sha1,
    ).digest()
    sig = base64.b64encode(digest).decode("utf-8")
    return f"OSS {key_id}:{sig}"


def put_oss_object(key: str, content_type: str, data: bytes, key_id: str, key_secret: str, bucket: str, endpoint: str) -> str:
    host = normalize_endpoint(endpoint, bucket)["host"]
    encoded_key = quote(key, safe="/-_.~")
    url = f"https://{host}/{encoded_key}"
    date_text = formatdate(timeval=None, localtime=False, usegmt=True)
    canonicalized_resource = f"/{bucket}/{key}"
    auth = sign_oss("PUT", content_type, date_text, canonicalized_resource, key_id, key_secret)
    req = Request(
        url,
        data=data,
        headers={
            "Date": date_text,
            "Content-Type": content_type,
            "Authorization": auth,
            "User-Agent": "Mozilla/5.0",
        },
        method="PUT",
    )
    with urlopen(req, timeout=60) as resp:
        _ = resp.read()
    return url


def build_temp_key(prefix: str, purpose: str, ext: str) -> str:
    p = str(prefix or "").strip() or DEFAULT_PREFIX
    if not p.endswith("/"):
        p += "/"
    date_seg = datetime.now(timezone.utc).strftime("%Y%m%d")
    clean_ext = (ext or "jpg").lower().lstrip(".")
    return f"{p}{date_seg}/{purpose}-{uuid4().hex}.{clean_ext}"


def list_images(search_dir: Path) -> List[Path]:
    files: List[Path] = []
    for p in search_dir.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix.lower() in IMAGE_EXTS:
            files.append(p)
    files.sort(key=lambda x: str(x))
    return files


def choose_image_interactive(search_dir: Path) -> Path:
    imgs = list_images(search_dir)
    if not imgs:
        raise RuntimeError(f"no image found under: {search_dir}")
    print(f"\nFound {len(imgs)} images under: {search_dir}\n")
    for i, p in enumerate(imgs, start=1):
        size_kb = p.stat().st_size / 1024.0
        print(f"{i:>3}. {p} ({size_kb:.1f} KB)")
    print("")
    while True:
        raw = input("Choose one image index: ").strip()
        if not raw.isdigit():
            print("Please input a number.")
            continue
        idx = int(raw)
        if 1 <= idx <= len(imgs):
            return imgs[idx - 1]
        print("Out of range, please retry.")


def head_url(url: str, timeout: int = 15) -> Dict[str, str]:
    req = Request(url, method="HEAD", headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urlopen(req, timeout=timeout) as resp:
            return {
                "ok": "true",
                "status": str(getattr(resp, "status", 200)),
                "content_type": resp.headers.get("Content-Type", ""),
                "content_length": resp.headers.get("Content-Length", ""),
            }
    except HTTPError as e:
        return {
            "ok": "false",
            "status": str(e.code),
            "error": f"HTTPError: {e.reason}",
        }
    except URLError as e:
        return {
            "ok": "false",
            "status": "0",
            "error": f"URLError: {e.reason}",
        }
    except Exception as e:
        return {
            "ok": "false",
            "status": "0",
            "error": repr(e),
        }


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(
        description="Local test: choose image -> upload OSS -> call Coze lineup workflow by curl"
    )
    ap.add_argument("--dir", default=".", help="image search directory when --image not provided")
    ap.add_argument("--image", default="", help="single local image path")
    ap.add_argument("--coze-url", default=os.getenv("COZE_RUN_URL", DEFAULT_COZE_URL), help="Coze /run URL")
    ap.add_argument("--token", default=os.getenv("COZE_TOKEN", ""), help="Coze bearer token")
    ap.add_argument("--bucket", default=os.getenv("ALIYUN_OSS_BUCKET", DEFAULT_BUCKET), help="OSS bucket")
    ap.add_argument("--endpoint", default=os.getenv("ALIYUN_OSS_ENDPOINT", DEFAULT_ENDPOINT), help="OSS endpoint/host")
    ap.add_argument("--prefix", default=os.getenv("ALIYUN_OSS_PREFIX", DEFAULT_PREFIX), help="OSS key prefix")
    ap.add_argument("--access-key-id", default=os.getenv("ALIYUN_OSS_ACCESS_KEY_ID", ""), help="OSS AccessKey ID")
    ap.add_argument("--access-key-secret", default=os.getenv("ALIYUN_OSS_ACCESS_KEY_SECRET", ""), help="OSS AccessKey Secret")
    ap.add_argument("--purpose", default="lineup-test", help="OSS object key prefix purpose")
    ap.add_argument("--max-time", type=int, default=300, help="curl max time seconds")
    ap.add_argument("--connect-timeout", type=int, default=10, help="curl connect timeout seconds")
    ap.add_argument("--include-file-type", action="store_true", help="add file_type=image in festival_image object")
    ap.add_argument("--response-out", default="", help="save raw response file path")
    ap.add_argument("--verbose-curl", action="store_true", help="use curl --verbose for debugging")
    ap.add_argument("--head-check-timeout", type=int, default=15, help="HEAD check timeout seconds")
    return ap.parse_args()


def check_required_bin() -> None:
    if not shutil.which("curl"):
        raise RuntimeError("curl not found in PATH")


def run_curl(
    coze_url: str,
    token: str,
    payload: Dict,
    max_time: int,
    response_out: Path,
    connect_timeout: int = 10,
    verbose: bool = False,
) -> Dict[str, str]:
    payload_text = json.dumps(payload, ensure_ascii=False)
    cmd = [
        "curl",
        "--verbose" if verbose else "--silent",
        "--show-error",
        "--location",
        "--request",
        "POST",
        coze_url,
        "--header",
        f"Authorization: Bearer {token}",
        "--header",
        "Content-Type: application/json",
        "--data",
        payload_text,
        "--connect-timeout",
        str(connect_timeout),
        "--output",
        str(response_out),
        "--write-out",
        "%{http_code}",
    ]
    if max_time > 0:
        cmd.extend(["--max-time", str(max_time)])

    safe_cmd = " ".join(
        [x if not x.startswith("Authorization: Bearer ") else "Authorization: Bearer ***" for x in cmd]
    )
    print("\nRunning curl command:")
    print(safe_cmd)
    print("")

    started = datetime.now()
    proc = subprocess.run(cmd, capture_output=True, text=True)
    ended = datetime.now()

    if proc.returncode != 0:
        raise RuntimeError(f"curl failed (exit={proc.returncode}): {proc.stderr.strip()}")

    http_code = (proc.stdout or "").strip()
    return {
        "http_code": http_code,
        "started_at": started.isoformat(timespec="seconds"),
        "ended_at": ended.isoformat(timespec="seconds"),
        "stderr": (proc.stderr or "").strip(),
        "elapsed_sec": str((ended - started).total_seconds()),
    }


def main() -> int:
    args = parse_args()
    try:
        check_required_bin()

        token = str(args.token or "").strip()
        if not token:
            raise RuntimeError("missing token: set COZE_TOKEN or pass --token")

        key_id = str(args.access_key_id or "").strip()
        key_secret = str(args.access_key_secret or "").strip()
        if not key_id or not key_secret:
            raise RuntimeError("missing OSS keys: set ALIYUN_OSS_ACCESS_KEY_ID and ALIYUN_OSS_ACCESS_KEY_SECRET")

        image_path: Optional[Path] = None
        if args.image:
            image_path = Path(args.image).expanduser().resolve()
            if not image_path.exists() or not image_path.is_file():
                raise RuntimeError(f"image not found: {image_path}")
        else:
            image_path = choose_image_interactive(Path(args.dir).expanduser().resolve())

        mime = mimetypes.guess_type(str(image_path))[0] or "application/octet-stream"
        ext = image_path.suffix.lower().lstrip(".") or "jpg"
        data = image_path.read_bytes()
        key = build_temp_key(args.prefix, args.purpose, ext)

        print(f"\nSelected image: {image_path}")
        print(f"Mime type: {mime}")
        print(f"Uploading to OSS key: {key}")

        oss_url = put_oss_object(
            key=key,
            content_type=mime,
            data=data,
            key_id=key_id,
            key_secret=key_secret,
            bucket=args.bucket,
            endpoint=args.endpoint,
        )
        print(f"OSS upload ok: {oss_url}")

        head_result = head_url(oss_url, timeout=args.head_check_timeout)
        print("\nOSS HEAD check:")
        print(json.dumps(head_result, ensure_ascii=False, indent=2))

        if head_result.get("ok") != "true" or head_result.get("status") != "200":
            raise RuntimeError(
                f"uploaded OSS URL is not publicly readable: "
                f"status={head_result.get('status')} error={head_result.get('error', '')}"
            )

        image_obj: Dict[str, str] = {"url": oss_url}
        if args.include_file_type:
            image_obj["file_type"] = "image"
        payload = {"festival_image": image_obj}

        response_out = (
            Path(args.response_out).expanduser().resolve()
            if args.response_out
            else Path.cwd() / f"coze_lineup_response_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        result = run_curl(
            args.coze_url,
            token,
            payload,
            args.max_time,
            response_out,
            connect_timeout=args.connect_timeout,
            verbose=args.verbose_curl,
        )

        print("Coze request finished.")
        print(f"HTTP code: {result['http_code']}")
        print(f"Started: {result['started_at']}")
        print(f"Ended:   {result['ended_at']}")
        print(f"Elapsed: {result['elapsed_sec']}s")
        print(f"Raw response saved: {response_out}")
        print(f"OSS key kept: {key}")
        print(f"OSS URL kept: {oss_url}")

        if result["stderr"]:
            print(f"curl stderr: {result['stderr']}")

        preview = response_out.read_text(encoding="utf-8", errors="replace")[:1200]
        print("\nResponse preview:")
        print(preview)

        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"\nERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())