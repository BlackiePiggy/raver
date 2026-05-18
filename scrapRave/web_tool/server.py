#!/usr/bin/env python3
from __future__ import annotations

import json
import mimetypes
import os
import re
import socket
import subprocess
import sys
import threading
import time
import base64
import hashlib
import hmac
from email.utils import formatdate
from dataclasses import dataclass
from datetime import datetime, timezone
from html import unescape
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, quote, unquote_to_bytes, urljoin, urlparse, urlencode
from urllib.request import Request, urlopen
from uuid import uuid4
import xml.etree.ElementTree as ET

BASE_URL = "https://festtimetable.com"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)
WEB_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = WEB_DIR.parent


def _load_local_env_file(path: Path) -> None:
    if not path.exists() or not path.is_file():
        return
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return
    for raw in lines:
        line = str(raw or "").strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env_key = str(key or "").strip()
        if not env_key:
            continue
        env_val = str(value or "").strip().strip('"').strip("'")
        if env_key not in os.environ:
            os.environ[env_key] = env_val


_load_local_env_file(PROJECT_ROOT / ".env.local")
BRANDS_ROOT = Path(os.getenv("BRANDS_ROOT", str(PROJECT_ROOT / "brands"))).resolve()
JOBS: Dict[str, Dict] = {}
JOBS_LOCK = threading.Lock()
COZE_RUN_URL = os.getenv("COZE_RUN_URL", "https://dxy8zryvs2.coze.site/run")
COZE_POSTER_RUN_URL = os.getenv("COZE_POSTER_RUN_URL", "https://wcc33b5z3k.coze.site/run")
COZE_TRANSLATE_RUN_URL = os.getenv("COZE_TRANSLATE_RUN_URL", "https://wp9jp3r4yx.coze.site/run").strip()
COZE_LINEUP_TIMEOUT_SEC = int(os.getenv("COZE_LINEUP_TIMEOUT_SEC", "0"))
COZE_LINEUP_RETRIES = int(os.getenv("COZE_LINEUP_RETRIES", "1"))
COZE_POSTER_TIMEOUT_SEC = int(os.getenv("COZE_POSTER_TIMEOUT_SEC", "0"))
COZE_POSTER_RETRIES = int(os.getenv("COZE_POSTER_RETRIES", "1"))
COZE_TRANSLATE_TIMEOUT_SEC = int(os.getenv("COZE_TRANSLATE_TIMEOUT_SEC", "0"))
COZE_TRANSLATE_RETRIES = int(os.getenv("COZE_TRANSLATE_RETRIES", "1"))
COZE_DJ_TRANS_RUN_URL = os.getenv("COZE_DJ_TRANS_RUN_URL", "https://txm2m87fgf.coze.site/run").strip()
COZE_DJ_TRANS_TIMEOUT_SEC = int(os.getenv("COZE_DJ_TRANS_TIMEOUT_SEC", "90"))
COZE_DJ_TRANS_RETRIES = int(os.getenv("COZE_DJ_TRANS_RETRIES", "4"))
COZE_LOCATION_NORMALIZE_RUN_URL = os.getenv("COZE_LOCATION_NORMALIZE_RUN_URL", "").strip()
COZE_LOCATION_NORMALIZE_TIMEOUT_SEC = int(os.getenv("COZE_LOCATION_NORMALIZE_TIMEOUT_SEC", "90"))
COZE_LOCATION_NORMALIZE_RETRIES = int(os.getenv("COZE_LOCATION_NORMALIZE_RETRIES", "3"))
RAVER_BFF_BASE = os.getenv("RAVER_BFF_BASE", "http://127.0.0.1:3001").strip().rstrip("/")
AMAP_JS_API_KEY = os.getenv("AMAP_JS_API_KEY", "").strip()
AMAP_SECURITY_JS_CODE = os.getenv("AMAP_SECURITY_JS_CODE", "").strip()
MAPKIT_JS_TOKEN = os.getenv("MAPKIT_JS_TOKEN", "").strip()
MAPBOX_ACCESS_TOKEN = os.getenv("MAPBOX_ACCESS_TOKEN", "").strip()
GEOAPIFY_API_KEY = os.getenv("GEOAPIFY_API_KEY", "").strip()
ALIYUN_OSS_ACCESS_KEY_ID = os.getenv("ALIYUN_OSS_ACCESS_KEY_ID", "").strip()
ALIYUN_OSS_ACCESS_KEY_SECRET = os.getenv("ALIYUN_OSS_ACCESS_KEY_SECRET", "").strip()
ALIYUN_OSS_BUCKET = os.getenv("ALIYUN_OSS_BUCKET", "wen-jasonlee").strip()
ALIYUN_OSS_ENDPOINT = os.getenv("ALIYUN_OSS_ENDPOINT", "wen-jasonlee.oss-cn-shanghai.aliyuncs.com").strip()
ALIYUN_OSS_PREFIX = os.getenv("ALIYUN_OSS_PREFIX", "temp/").strip() or "temp/"
ALIYUN_OSS_CLEANUP_DELAY_SEC = int(os.getenv("ALIYUN_OSS_CLEANUP_DELAY_SEC", "1800"))
COZE_TOKEN_TIMETABLE = os.getenv(
    "COZE_TOKEN_TIMETABLE",
    "eyJhbGciOiJSUzI1NiIsImtpZCI6IjA2YTlmNGMyLWVhYjQtNDU0Ny05YWEzLTBmMjljZmE0NjkxYSJ9.eyJpc3MiOiJodHRwczovL2FwaS5jb3plLmNuIiwiYXVkIjpbInBRV3N5R3VIaXFwekIxanJiaEZOcGoyWVJWT1JIaUdiIl0sImV4cCI6ODIxMDI2Njg3Njc5OSwiaWF0IjoxNzc0ODg2NjY5LCJzdWIiOiJzcGlmZmU6Ly9hcGkuY296ZS5jbi93b3JrbG9hZF9pZGVudGl0eS9pZDo3NjIwNjIyNDA3Mjg3NDM5NDEyIiwic3JjIjoiaW5ib3VuZF9hdXRoX2FjY2Vzc190b2tlbl9pZDo3NjIzMDgwMTk4NDUxMjMyNzc3In0.IcjAopHkEG922ZVby_aG1wnvnlpssrFg72V-v_emRs7kb2jCqLKsKRvyktJDjdlBTLQEdesmYv2Qs5a2RkdqkUFw74SD7-7B-C-sUj30L3cQjniBlBXyvkEuOPxMdWsL5O-tCBEvlPTzOJieZVlwA4BQMSCK3izXHHovOqMUz21en0TBhnI_6hbvlaJkh4SO65XhZPUBlyAfWoirX9_oT4S1Ufpraaqa7FDvCIaE2pxeoLKiW-P7PtCwu4iXZkzNguCVoFIT6q3qR9zkKGmO6A2Vc3A2zGIa2wv2LWsAmK1PYLjSEb2cSU9ilkeS84I0Tva4Lkcu9bn3yexu4tGOOg",
)
COZE_TOKEN_LINEUP = os.getenv(
    "COZE_TOKEN_LINEUP",
    "eyJhbGciOiJSUzI1NiIsImtpZCI6IjhiNmUwZWIwLTU2MGItNDFjMi1hODY4LTlmMzI4Y2FhZjAzNSJ9.eyJpc3MiOiJodHRwczovL2FwaS5jb3plLmNuIiwiYXVkIjpbIlF4QUE0eXFudlJ0OXpYUWtaTlF4SDhDbTBySzJha0xLIl0sImV4cCI6ODIxMDI2Njg3Njc5OSwiaWF0IjoxNzc0OTE2OTk1LCJzdWIiOiJzcGlmZmU6Ly9hcGkuY296ZS5jbi93b3JrbG9hZF9pZGVudGl0eS9pZDo3NjIyOTA1MjM3OTMzNjU0MDY3Iiwic3JjIjoiaW5ib3VuZF9hdXRoX2FjY2Vzc190b2tlbl9pZDo3NjIzMjEwNDUwMDk5ODk2MzM1In0.dooZx7P6sLEm0r-KWpB6r_ltf56x_g2TQqQt4bkaPL6EwqXtO4JpDLMSqH790TwjeCGhAO3ebbtadMpX1iJqSyFHY_br75tdUE_dxL2IL42SmWIAAUKu1wOJ9J5pgDzj2tFUy5HiS5IeAB4R9b7iraGqL4PHlxVoMwmIWnQvvv8yaQiBsjE_MOH2fvZFUvSElEpJK0oS4LisnfXKtp-l_Lc0ndDCK9Au-kFtchRfkMYaxQoBeN2JRDl76k-Wkwuxqx3f-YGvWAA45IWXxFP39_93RozwTH6F4cTsHF9ZYUsmMfxc417uEPeukjkVY8vNuDUx4QNCbUMvu49uSks2sw"
)
COZE_TOKEN_TRANSLATE = os.getenv(
    "COZE_TOKEN_TRANSLATE", 
    "eyJhbGciOiJSUzI1NiIsImtpZCI6IjhiNmUwZWIwLTU2MGItNDFjMi1hODY4LTlmMzI4Y2FhZjAzNSJ9.eyJpc3MiOiJodHRwczovL2FwaS5jb3plLmNuIiwiYXVkIjpbIkZLOU9Wb3NxMFhGY1o2RW1xeUkwN29qOTllb0EyeWRJIl0sImV4cCI6ODIxMDI2Njg3Njc5OSwiaWF0IjoxNzc0OTI1ODQyLCJzdWIiOiJzcGlmZmU6Ly9hcGkuY296ZS5jbi93b3JrbG9hZF9pZGVudGl0eS9pZDo3NjIzMjQzMDI4NTI5OTM4NDQyIiwic3JjIjoiaW5ib3VuZF9hdXRoX2FjY2Vzc190b2tlbl9pZDo3NjIzMjQ4NDQ4MjU0Mzc4MDIyIn0.Y6p5E2lr7LA2gD1ZztiF2IbeIDh1AFzWpD0ov1ZL6tqB0fEPLrGDyYmaQ3y0NAhUIpOzHK7pw8tGcNMLO3dsBTjS0d_M39F9I1u136c5gjpylkdMzqZl0RpOGNXozCbVneQ4JFOxZOJfL5bwLrR-fSLMr8EijbBuT7kjH-HQy8_Tonm2ZK5RFtDxmRQ6K_HlwKdlE3akwbasrqYSLP9uvy7cFlulMNeEVJWtyBVKZNoyT4r3iEdXmlnTD0J10rqg1dBf4qJXfv9UGYiwhB2ow4XX8REG5WRw-k2WxTb42ffjR6HoedXcWSMMnDHSUFqTva5Ji7eYzdKwdgHCB7SL4w"
)
COZE_TOKEN_DJ_TRANS = os.getenv(
    "COZE_TOKEN_DJ_TRANS", 
    "eyJhbGciOiJSUzI1NiIsImtpZCI6IjgwMjFiZTE3LTM4MDMtNDEwOS1hODkxLTZlOTNmZTAwOTA0ZiJ9.eyJpc3MiOiJodHRwczovL2FwaS5jb3plLmNuIiwiYXVkIjpbImNUS0ZrSG53UFJMUUVRdW95YlREb2NKWXQ0Y0xXQXhTIl0sImV4cCI6ODIxMDI2Njg3Njc5OSwiaWF0IjoxNzc1MTI2MTEyLCJzdWIiOiJzcGlmZmU6Ly9hcGkuY296ZS5jbi93b3JrbG9hZF9pZGVudGl0eS9pZDo3NjI0MDkxNzc2ODI2OTk4ODMwIiwic3JjIjoiaW5ib3VuZF9hdXRoX2FjY2Vzc190b2tlbl9pZDo3NjI0MTA4NTk3NjA5MjM0NDgzIn0.ZSocsrFaBBCwIH1geVIVFVwiOW2ikWXD8Wj_mRjht3iiycF1Ovj7OSBP19S7vbE1pkk-jaBygAqEiqOVAivDVtdPDFitUL2ut16Tob7xK8fKCsxC1WnNmg5Q4ntv7SB80sThZ93mvMRzUkKuIZp40FKGkj4VXhHUJQ_65oGbkjTbYausCfEH0hA47kUuSsSR_dlkfYluygSt1MxYOT4KDSP5UX46fgPs1HPGlm2Os1b29DlsYs1tOBOkiM7oU__Z8InuX3uk6QCehMsH-peKF24j6REzIIVIspTqR3Gai0CyBFihQU5OtYAgs6RjgyPNYmUVLv93T8XM0Je7JXr5UA"
)
COZE_TOKEN_LOCATION_NORMALIZE = os.getenv(
    "COZE_TOKEN_LOCATION_NORMALIZE",
    "",
)

OSS_CLEANUP_QUEUE: List[Dict[str, Any]] = []
OSS_CLEANUP_LOCK = threading.Lock()
OSS_CLEANUP_DAEMON_STARTED = False
DJ_SOURCE_CACHE_ROOT = Path(
    os.getenv("DJ_SOURCE_CACHE_ROOT", str(WEB_DIR / ".cache" / "dj_source_cache"))
).resolve()
DJ_SOURCE_CACHE_QUERY_DIR = DJ_SOURCE_CACHE_ROOT / "queries"
DJ_SOURCE_CACHE_AVATAR_DIR = DJ_SOURCE_CACHE_ROOT / "avatars"
DJ_SOURCE_CACHE_LOG_FILE = DJ_SOURCE_CACHE_ROOT / "logs.ndjson"
DJ_SOURCE_CACHE_LOCK = threading.Lock()
DJ_SOURCE_CACHE_LAST_PRUNE_AT = 0.0
DJ_SOURCE_CACHE_PRUNE_INTERVAL_SEC = 60


def _parse_size_bytes(raw: str, default: int) -> int:
    text = str(raw or "").strip().lower()
    if not text:
        return default
    matched = re.match(r"^(\d+(?:\.\d+)?)\s*([kmgt]?i?b?|b)?$", text)
    if not matched:
        try:
            return int(float(text))
        except Exception:
            return default
    value = float(matched.group(1))
    unit = (matched.group(2) or "b").lower()
    multipliers = {
        "": 1,
        "b": 1,
        "k": 1024,
        "kb": 1024,
        "kib": 1024,
        "m": 1024 ** 2,
        "mb": 1024 ** 2,
        "mib": 1024 ** 2,
        "g": 1024 ** 3,
        "gb": 1024 ** 3,
        "gib": 1024 ** 3,
        "t": 1024 ** 4,
        "tb": 1024 ** 4,
        "tib": 1024 ** 4,
    }
    return max(0, int(value * multipliers.get(unit, 1)))


DJ_SOURCE_CACHE_MAX_BYTES = _parse_size_bytes(
    os.getenv("DJ_SOURCE_CACHE_MAX_BYTES", "0"),
    0,
)
try:
    DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE = max(
        1, int(os.getenv("DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE", "3"))
    )
except ValueError:
    DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE = 3


@dataclass
class FetchResult:
    url: str
    text: str


def fetch_text(url: str, timeout: int = 30, retries: int = 3) -> FetchResult:
    last_exc: Optional[Exception] = None
    for i in range(retries):
        try:
            req = Request(url, headers={"User-Agent": USER_AGENT})
            with urlopen(req, timeout=timeout) as resp:
                data = resp.read().decode("utf-8", errors="replace")
            return FetchResult(url=url, text=data)
        except (HTTPError, URLError, TimeoutError) as exc:
            last_exc = exc
            time.sleep(0.5 * (i + 1))
    raise RuntimeError(f"Fetch failed: {url} ({last_exc})")


WECHAT_ARTICLE_HOST_RE = re.compile(r"(^|\.)mp\.weixin\.qq\.com$", flags=re.I)


def _normalize_remote_url(raw_url: str) -> str:
    text = unescape(str(raw_url or "").strip())
    if not text:
        return ""
    if text.startswith("//"):
        return f"https:{text}"
    return text


def _extract_attr_from_tag(tag_html: str, attr_name: str) -> str:
    safe_attr = re.escape(str(attr_name or "").strip())
    if not safe_attr:
        return ""
    pattern = re.compile(
        rf"""\b{safe_attr}\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))""",
        flags=re.I,
    )
    matched = pattern.search(str(tag_html or ""))
    if not matched:
        return ""
    value = matched.group(1) or matched.group(2) or matched.group(3) or ""
    return _normalize_remote_url(value)


def _strip_html_tags(raw_html: str) -> str:
    return re.sub(r"<[^>]+>", "", str(raw_html or ""), flags=re.S)


def _normalize_text_spaces(raw_text: str) -> str:
    text = unescape(str(raw_text or ""))
    text = text.replace("\xa0", " ")
    text = re.sub(r"\s+", " ", text, flags=re.S).strip()
    return text


def _extract_balanced_div_inner_html(full_html: str, start_tag_match: re.Match[str]) -> str:
    start = int(start_tag_match.end())
    depth = 1
    token_re = re.compile(r"</?div\b[^>]*>", flags=re.I)
    for token in token_re.finditer(full_html, start):
        token_text = token.group(0).lower()
        if token_text.startswith("</div"):
            depth -= 1
        else:
            depth += 1
        if depth == 0:
            return full_html[start:token.start()]
    return full_html[start:]


def _extract_wechat_content_html(page_html: str) -> str:
    html_src = str(page_html or "")
    if not html_src:
        return ""
    div_re = re.compile(r"<div\b[^>]*>", flags=re.I)
    for matched in div_re.finditer(html_src):
        start_tag = matched.group(0)
        div_id = _extract_attr_from_tag(start_tag, "id").lower()
        div_class = _extract_attr_from_tag(start_tag, "class").lower()
        if div_id == "js_content" or "rich_media_content" in div_class:
            return _extract_balanced_div_inner_html(html_src, matched).strip()
    return ""


def _extract_wechat_title(page_html: str) -> str:
    html_src = str(page_html or "")
    title_match = re.search(
        r"""<h1[^>]*class=(?:"[^"]*rich_media_title[^"]*"|'[^']*rich_media_title[^']*')[^>]*>(.*?)</h1>""",
        html_src,
        flags=re.I | re.S,
    )
    if title_match:
        title = _normalize_text_spaces(_strip_html_tags(title_match.group(1)))
        if title:
            return title
    meta_match = re.search(
        r"""<meta[^>]*property=(?:"og:title"|'og:title')[^>]*content=(?:"([^"]*)"|'([^']*)')[^>]*>""",
        html_src,
        flags=re.I | re.S,
    )
    if meta_match:
        return _normalize_text_spaces(meta_match.group(1) or meta_match.group(2) or "")
    return ""


def _extract_wechat_publish_time(page_html: str) -> str:
    html_src = str(page_html or "")
    publish_match = re.search(
        r"""<[^>]*id=(?:"publish_time"|'publish_time')[^>]*>(.*?)</[^>]+>""",
        html_src,
        flags=re.I | re.S,
    )
    if publish_match:
        value = _normalize_text_spaces(_strip_html_tags(publish_match.group(1)))
        if value:
            return value
    meta_match = re.search(
        r"""<meta[^>]*property=(?:"article:published_time"|'article:published_time')[^>]*content=(?:"([^"]*)"|'([^']*)')[^>]*>""",
        html_src,
        flags=re.I | re.S,
    )
    if meta_match:
        value = _normalize_text_spaces(meta_match.group(1) or meta_match.group(2) or "")
        if value:
            return value

    script_patterns = [
        r"""(?:var\s+ct|["']ct["'])\s*[:=]\s*["']?(\d{10,13})["']?""",
        r"""ori_create_time\s*:\s*["']?(\d{10,13})["']?\s*\*\s*1""",
        r"""publish_time\s*:\s*(\d{10,13})""",
        r"""create_time\s*:\s*JsDecode\(\s*["']([^"']{4,64})["']\s*\)""",
        r"""["'](?:publish_time|publishTime|publishedAt|published_at|create_time|createTime|publish_date|publishDate)["']\s*:\s*["']([^"']{4,64})["']""",
        r"""(?:publish_time|publishTime|publishedAt|published_at|create_time|createTime|publish_date|publishDate)\s*[:=]\s*["']([^"']{4,64})["']""",
    ]
    for pattern in script_patterns:
        script_match = re.search(pattern, html_src, flags=re.I | re.S)
        if script_match:
            value = _normalize_text_spaces(script_match.group(1) or "")
            if value:
                return value
    return ""


def _extract_wechat_author(page_html: str) -> str:
    html_src = str(page_html or "")
    for author_id in ("js_name", "profileBt", "js_profile_qrcode"):
        match = re.search(
            rf"""<[^>]*id=(?:"{re.escape(author_id)}"|'{re.escape(author_id)}')[^>]*>(.*?)</[^>]+>""",
            html_src,
            flags=re.I | re.S,
        )
        if match:
            val = _normalize_text_spaces(_strip_html_tags(match.group(1)))
            if val:
                return val

    meta_patterns = [
        r"""<meta[^>]*name=(?:"author"|'author')[^>]*content=(?:"([^"]*)"|'([^']*)')[^>]*>""",
        r"""<meta[^>]*property=(?:"profile:username"|'profile:username')[^>]*content=(?:"([^"]*)"|'([^']*)')[^>]*>""",
    ]
    for pattern in meta_patterns:
        meta_match = re.search(pattern, html_src, flags=re.I | re.S)
        if meta_match:
            val = _normalize_text_spaces(meta_match.group(1) or meta_match.group(2) or "")
            if val:
                return val

    script_patterns = [
        r"""["'](?:nickname|user_name|author|biz_nickname)["']\s*:\s*["']([^"']{1,120})["']""",
        r"""(?:nickname|user_name|author|biz_nickname)\s*[:=]\s*["']([^"']{1,120})["']""",
    ]
    for pattern in script_patterns:
        script_match = re.search(pattern, html_src, flags=re.I | re.S)
        if script_match:
            val = _normalize_text_spaces(script_match.group(1) or "")
            if val:
                return val
    return ""


def _extract_wechat_image_data(content_html: str) -> List[Dict[str, str]]:
    html_src = str(content_html or "")
    if not html_src:
        return []
    images: List[Dict[str, str]] = []
    seen: set[str] = set()
    for matched in re.finditer(r"<img\b[^>]*>", html_src, flags=re.I):
        tag = matched.group(0)
        img_url = (
            _extract_attr_from_tag(tag, "data-src")
            or _extract_attr_from_tag(tag, "data-original")
            or _extract_attr_from_tag(tag, "src")
        )
        img_url = _normalize_remote_url(img_url)
        if not img_url:
            continue
        if img_url in seen:
            continue
        seen.add(img_url)
        alt_text = _extract_attr_from_tag(tag, "alt")
        images.append({"url": img_url, "alt": _normalize_text_spaces(alt_text) or "image"})
    return images


def _markdown_escape(raw_text: str) -> str:
    text = str(raw_text or "")
    return text.replace("\\", "\\\\").replace("`", "\\`").strip()


def _wechat_html_to_markdown(content_html: str) -> str:
    html_src = str(content_html or "")
    if not html_src:
        return ""

    body = re.sub(r"<script\b[^>]*>[\s\S]*?</script>", "", html_src, flags=re.I)
    body = re.sub(r"<style\b[^>]*>[\s\S]*?</style>", "", body, flags=re.I)
    body = re.sub(r"<!--[\s\S]*?-->", "", body, flags=re.S)
    body = re.sub(r"<br\s*/?>", "\n", body, flags=re.I)

    def _img_to_md(matched: re.Match[str]) -> str:
        tag = matched.group(0)
        img_url = (
            _extract_attr_from_tag(tag, "data-src")
            or _extract_attr_from_tag(tag, "data-original")
            or _extract_attr_from_tag(tag, "src")
        )
        img_url = _normalize_remote_url(img_url)
        if not img_url:
            return ""
        alt = _normalize_text_spaces(_extract_attr_from_tag(tag, "alt")) or "image"
        return f"\n\n![{_markdown_escape(alt)}]({img_url})\n\n"

    body = re.sub(r"<img\b[^>]*>", _img_to_md, body, flags=re.I)

    def _heading_to_md(level: int, matched: re.Match[str]) -> str:
        text = _normalize_text_spaces(_strip_html_tags(matched.group(1)))
        if not text:
            return ""
        return f"\n\n{'#' * level} {text}\n\n"

    for heading_level in range(1, 7):
        body = re.sub(
            rf"<h{heading_level}\b[^>]*>([\s\S]*?)</h{heading_level}>",
            lambda m, level=heading_level: _heading_to_md(level, m),
            body,
            flags=re.I,
        )

    body = re.sub(
        r"<a\b[^>]*href=(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))[^>]*>([\s\S]*?)</a>",
        lambda m: (
            f"[{_normalize_text_spaces(_strip_html_tags(m.group(4) or 'link'))}]"
            f"({_normalize_remote_url(m.group(1) or m.group(2) or m.group(3) or '')})"
        ),
        body,
        flags=re.I,
    )

    body = re.sub(
        r"<li\b[^>]*>([\s\S]*?)</li>",
        lambda m: f"- {_normalize_text_spaces(_strip_html_tags(m.group(1)))}\n",
        body,
        flags=re.I,
    )
    body = re.sub(r"</?(?:ul|ol)\b[^>]*>", "\n", body, flags=re.I)
    body = re.sub(
        r"<blockquote\b[^>]*>([\s\S]*?)</blockquote>",
        lambda m: f"\n\n> {_normalize_text_spaces(_strip_html_tags(m.group(1)))}\n\n",
        body,
        flags=re.I,
    )

    body = re.sub(r"</?(?:strong|b)\b[^>]*>", "**", body, flags=re.I)
    body = re.sub(r"</?(?:em|i)\b[^>]*>", "*", body, flags=re.I)
    body = re.sub(r"</?code\b[^>]*>", "`", body, flags=re.I)

    body = re.sub(r"</?(?:p|div|section|article|figure|figcaption)\b[^>]*>", "\n\n", body, flags=re.I)
    body = re.sub(r"<[^>]+>", "", body, flags=re.S)

    body = unescape(body).replace("\xa0", " ")
    body = body.replace("\r\n", "\n").replace("\r", "\n")
    body = re.sub(r"\n{3,}", "\n\n", body)
    body = "\n".join(line.rstrip() for line in body.split("\n"))
    return body.strip()


def _sanitize_wechat_article_url(raw_url: str) -> str:
    text = str(raw_url or "").strip()
    if not text:
        return ""
    parsed = urlparse(text)
    if parsed.scheme not in ("http", "https"):
        return ""
    hostname = str(parsed.hostname or "").strip().lower()
    if not WECHAT_ARTICLE_HOST_RE.search(hostname):
        return ""
    return text


def _import_wechat_article_payload(article_url: str) -> Dict[str, Any]:
    safe_url = _sanitize_wechat_article_url(article_url)
    if not safe_url:
        raise ValueError("仅支持 mp.weixin.qq.com 的公众号文章链接")

    fetched = fetch_text(safe_url, timeout=30, retries=2)
    page_html = fetched.text
    content_html = _extract_wechat_content_html(page_html)
    if not content_html:
        raise RuntimeError("未识别到公众号正文内容，请确认链接为可公开访问的文章页")

    title = _extract_wechat_title(page_html) or "未命名文章"
    publish_time = _extract_wechat_publish_time(page_html)
    author = _extract_wechat_author(page_html)
    images = _extract_wechat_image_data(content_html)
    markdown = _wechat_html_to_markdown(content_html)

    plain_summary = re.sub(r"!\[[^\]]*\]\([^)]+\)", "", markdown)
    plain_summary = re.sub(r"[#>*`_\-\[\]\(\)]", " ", plain_summary)
    plain_summary = re.sub(r"\s+", " ", plain_summary).strip()

    return {
        "sourceUrl": safe_url,
        "title": title,
        "author": author,
        "publishTime": publish_time,
        "markdown": markdown,
        "imageUrls": [item.get("url", "") for item in images if item.get("url")],
        "imageCount": len(images),
        "summary": plain_summary[:220],
    }


def _ensure_dj_source_cache_dirs() -> None:
    DJ_SOURCE_CACHE_QUERY_DIR.mkdir(parents=True, exist_ok=True)
    DJ_SOURCE_CACHE_AVATAR_DIR.mkdir(parents=True, exist_ok=True)
    DJ_SOURCE_CACHE_ROOT.mkdir(parents=True, exist_ok=True)


def _prune_dj_source_cache_if_needed(force: bool = False) -> None:
    global DJ_SOURCE_CACHE_LAST_PRUNE_AT

    if DJ_SOURCE_CACHE_MAX_BYTES <= 0:
        return

    now = time.time()
    if not force and (now - DJ_SOURCE_CACHE_LAST_PRUNE_AT) < DJ_SOURCE_CACHE_PRUNE_INTERVAL_SEC:
        return

    _ensure_dj_source_cache_dirs()
    prune_log_detail: Optional[Dict[str, Any]] = None
    with DJ_SOURCE_CACHE_LOCK:
        DJ_SOURCE_CACHE_LAST_PRUNE_AT = now
        files: List[Tuple[float, int, Path]] = []
        total_bytes = 0
        for root in (DJ_SOURCE_CACHE_QUERY_DIR, DJ_SOURCE_CACHE_AVATAR_DIR):
            if not root.exists():
                continue
            for path in root.rglob("*"):
                if not path.is_file():
                    continue
                try:
                    stat = path.stat()
                except OSError:
                    continue
                size = int(stat.st_size or 0)
                total_bytes += size
                files.append((float(stat.st_mtime or 0), size, path))

        if total_bytes <= DJ_SOURCE_CACHE_MAX_BYTES:
            return

        files.sort(key=lambda item: item[0])
        removed_files = 0
        removed_bytes = 0
        target_bytes = int(DJ_SOURCE_CACHE_MAX_BYTES * 0.9)
        for _, size, path in files:
            if total_bytes <= target_bytes:
                break
            try:
                path.unlink(missing_ok=True)
            except Exception:
                continue
            total_bytes -= size
            removed_bytes += size
            removed_files += 1

        if removed_files > 0:
            prune_log_detail = {
                "removedFiles": removed_files,
                "removedBytes": removed_bytes,
                "remainingBytes": total_bytes,
                "maxBytes": DJ_SOURCE_CACHE_MAX_BYTES,
            }

    if prune_log_detail:
        _append_dj_cache_log(
            level="info",
            action="cache_prune",
            message=f"pruned {prune_log_detail['removedFiles']} files",
            detail=prune_log_detail,
        )


def _normalize_dj_cache_query(query: str) -> str:
    return " ".join(str(query or "").strip().lower().split())


def _dj_cache_query_key(normalized_query: str) -> str:
    return hashlib.sha1(normalized_query.encode("utf-8")).hexdigest()


def _dj_cache_query_file(normalized_query: str) -> Path:
    return DJ_SOURCE_CACHE_QUERY_DIR / f"{_dj_cache_query_key(normalized_query)}.json"


def _write_json_atomic(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    temp_path.replace(path)


def _read_json_file(path: Path) -> Optional[Dict[str, Any]]:
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    except Exception:
        return None
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def _append_dj_cache_log(
    level: str,
    action: str,
    query: str = "",
    source: str = "",
    message: str = "",
    detail: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    _ensure_dj_source_cache_dirs()
    now_ms = int(time.time() * 1000)
    entry = {
        "id": f"log-{now_ms}-{uuid4().hex[:8]}",
        "at": now_ms,
        "level": str(level or "info").strip() or "info",
        "action": str(action or "").strip(),
        "query": str(query or "").strip(),
        "source": str(source or "").strip(),
        "message": str(message or "").strip(),
        "detail": detail if isinstance(detail, dict) else None,
    }
    line = json.dumps(entry, ensure_ascii=False)
    with DJ_SOURCE_CACHE_LOCK:
        with DJ_SOURCE_CACHE_LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    return entry


def _read_recent_dj_cache_logs(limit: int = 50) -> List[Dict[str, Any]]:
    _ensure_dj_source_cache_dirs()
    size = max(1, min(1000, int(limit or 50)))
    if not DJ_SOURCE_CACHE_LOG_FILE.exists():
        return []
    try:
        lines = DJ_SOURCE_CACHE_LOG_FILE.read_text(encoding="utf-8").splitlines()
    except Exception:
        return []
    out: List[Dict[str, Any]] = []
    for raw in reversed(lines):
        if not raw.strip():
            continue
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict):
            out.append(row)
        if len(out) >= size:
            break
    return out


def _replace_soundcloud_avatar_variant(url: str, variant: str) -> str:
    base = str(url or "").strip()
    if not base:
        return ""
    if "sndcdn.com/avatars-" not in base.lower():
        return ""
    try:
        parsed = urlparse(base)
        replaced_path = re.sub(
            r"-(?:tiny|small|large|t\d+x\d+|crop|original)\.(jpe?g|png|webp)$",
            rf"-{variant}.\1",
            parsed.path or "",
            flags=re.I,
        )
        if not replaced_path or replaced_path == (parsed.path or ""):
            return ""
        return parsed._replace(path=replaced_path).geturl()
    except Exception:
        return ""


def _build_avatar_fetch_candidates(url: str) -> List[str]:
    base = str(url or "").strip()
    if not base:
        return []
    candidates: List[str] = []
    for variant in ("original", "t500x500"):
        vurl = _replace_soundcloud_avatar_variant(base, variant)
        if vurl:
            candidates.append(vurl)
    candidates.append(base)
    dedup: List[str] = []
    seen = set()
    for u in candidates:
        if u in seen:
            continue
        seen.add(u)
        dedup.append(u)
    return dedup


def _guess_ext(content_type: str, url: str) -> str:
    ctype = str(content_type or "").lower()
    if "png" in ctype:
        return "png"
    if "webp" in ctype:
        return "webp"
    if "jpeg" in ctype or "jpg" in ctype:
        return "jpg"
    guessed, _ = mimetypes.guess_type(url)
    guessed = (guessed or "").lower()
    if "png" in guessed:
        return "png"
    if "webp" in guessed:
        return "webp"
    if "jpeg" in guessed or "jpg" in guessed:
        return "jpg"
    return "jpg"


def _avatar_hash(url: str) -> str:
    return hashlib.sha1(str(url or "").strip().encode("utf-8")).hexdigest()


def _find_cached_avatar_local_url(url: str) -> str:
    _ensure_dj_source_cache_dirs()
    _prune_dj_source_cache_if_needed()
    digest = _avatar_hash(url)
    for path in sorted(DJ_SOURCE_CACHE_AVATAR_DIR.glob(f"{digest}.*")):
        if not path.is_file():
            continue
        try:
            path.touch()
        except Exception:
            pass
        return f"/api/dj-source-cache/avatar/{quote(path.name)}"
    return ""


def _cache_avatar_and_get_local_url(url: str, query: str = "", source: str = "") -> str:
    raw_url = str(url or "").strip()
    if not raw_url:
        return ""
    _ensure_dj_source_cache_dirs()
    cached = _find_cached_avatar_local_url(raw_url)
    if cached:
        return cached

    digest = _avatar_hash(raw_url)
    last_error: Optional[Exception] = None
    for candidate in _build_avatar_fetch_candidates(raw_url):
        try:
            req = Request(candidate, headers={"User-Agent": USER_AGENT})
            with urlopen(req, timeout=40) as resp:
                data = resp.read()
                ctype = resp.headers.get("Content-Type", "")
            if not data:
                raise RuntimeError("empty image body")
            ext = _guess_ext(ctype, candidate)
            file_name = f"{digest}.{ext}"
            target = DJ_SOURCE_CACHE_AVATAR_DIR / file_name
            target.write_bytes(data)
            _prune_dj_source_cache_if_needed()
            return f"/api/dj-source-cache/avatar/{quote(file_name)}"
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            continue

    raise RuntimeError(f"avatar cache failed: {last_error}")


def _sanitize_cache_sources(
    query: str,
    sources: Dict[str, Any],
    cache_avatars: bool = True,
) -> Dict[str, Any]:
    safe_sources: Dict[str, Any] = {}
    for source_key in ("spotify", "discogs", "soundcloud"):
        group = sources.get(source_key)
        if not isinstance(group, dict):
            group = {}
        status = str(group.get("status", "idle") or "idle")
        message = str(group.get("message", "") or "")
        fetched_at = int(group.get("fetchedAt") or 0)
        raw_items = group.get("items")
        raw_selected_index = group.get("selectedIndex")
        items: List[Dict[str, Any]] = []
        if isinstance(raw_items, list):
            for raw_item in raw_items[:DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE]:
                if not isinstance(raw_item, dict):
                    continue
                item = json.loads(json.dumps(raw_item, ensure_ascii=False))
                avatar_url = str(item.get("avatarUrl", "") or "").strip()
                if avatar_url:
                    local_avatar = ""
                    try:
                        local_avatar = _find_cached_avatar_local_url(avatar_url)
                        if not local_avatar and cache_avatars:
                            local_avatar = _cache_avatar_and_get_local_url(
                                avatar_url,
                                query=query,
                                source=source_key,
                            )
                    except Exception as exc:  # noqa: BLE001
                        _append_dj_cache_log(
                            level="warn",
                            action="avatar_cache",
                            query=query,
                            source=source_key,
                            message=str(exc),
                            detail={"avatarUrl": avatar_url},
                        )
                        local_avatar = ""
                    if local_avatar:
                        item["avatarDisplayUrl"] = local_avatar
                items.append(item)
        selected_index = -1
        try:
            selected_index = int(raw_selected_index)
        except Exception:
            selected_index = -1
        if items:
            selected_index = max(0, min(selected_index if selected_index >= 0 else 0, len(items) - 1))
        else:
            selected_index = -1
        safe_sources[source_key] = {
            "status": status,
            "message": message,
            "fetchedAt": fetched_at,
            "items": items,
            "selectedIndex": selected_index,
        }
    return safe_sources


def _load_dj_source_cache_record(query: str) -> Optional[Dict[str, Any]]:
    normalized_query = _normalize_dj_cache_query(query)
    if not normalized_query:
        return None
    path = _dj_cache_query_file(normalized_query)
    with DJ_SOURCE_CACHE_LOCK:
        record = _read_json_file(path)
    if not record:
        return None

    sources = record.get("sources")
    if isinstance(sources, dict):
        changed = False
        for source_key in ("spotify", "discogs", "soundcloud"):
            group = sources.get(source_key)
            if not isinstance(group, dict):
                continue
            items = group.get("items")
            if not isinstance(items, list):
                continue
            if len(items) > DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE:
                items = items[:DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE]
                group["items"] = items
                changed = True
            raw_selected_index = group.get("selectedIndex")
            try:
                selected_index = int(raw_selected_index)
            except Exception:
                selected_index = -1
            normalized_selected_index = -1
            if items:
                normalized_selected_index = max(
                    0,
                    min(selected_index if selected_index >= 0 else 0, len(items) - 1),
                )
            if raw_selected_index != normalized_selected_index:
                group["selectedIndex"] = normalized_selected_index
                changed = True
            for item in items:
                if not isinstance(item, dict):
                    continue
                avatar_url = str(item.get("avatarUrl", "") or "").strip()
                avatar_display = str(item.get("avatarDisplayUrl", "") or "").strip()
                if avatar_url and not avatar_display:
                    local_avatar = _find_cached_avatar_local_url(avatar_url)
                    if local_avatar:
                        item["avatarDisplayUrl"] = local_avatar
                        changed = True
        if changed:
            with DJ_SOURCE_CACHE_LOCK:
                _write_json_atomic(path, record)
    return record

def strip_tags(html: str) -> str:
    html = re.sub(r"<br\s*/?>", " ", html, flags=re.I)
    text = re.sub(r"<[^>]+>", "", html)
    return " ".join(unescape(text).split())


def parse_attrs(tag_open: str) -> Dict[str, str]:
    attrs: Dict[str, str] = {}
    for key, v1, v2 in re.findall(r'([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|\'([^\']*)\')', tag_open):
        attrs[key] = unescape(v1 if v1 else v2)
    return attrs


def find_balanced_div(html: str, start_idx: int) -> Optional[str]:
    tag_re = re.compile(r"</?div\b[^>]*>", re.I)
    depth = 0
    begin = None
    for m in tag_re.finditer(html, start_idx):
        tag = m.group(0)
        if tag.startswith("<div"):
            if begin is None:
                begin = m.start()
            depth += 1
        else:
            depth -= 1
            if depth == 0 and begin is not None:
                return html[begin:m.end()]
    return None


def extract_section_by_id(html: str, section_id: str) -> str:
    m = re.search(rf'<div[^>]*\bid="{re.escape(section_id)}"[^>]*>', html)
    if not m:
        return ""
    return find_balanced_div(html, m.start()) or ""


def find_div_blocks_by_class(html: str, class_snippet: str) -> List[str]:
    out: List[str] = []
    pattern = re.compile(rf'<div[^>]*class="[^"]*{re.escape(class_snippet)}[^"]*"[^>]*>', re.I)
    for m in pattern.finditer(html):
        block = find_balanced_div(html, m.start())
        if block:
            out.append(block)
    return out


def find_anchor_blocks(html: str) -> List[str]:
    out: List[str] = []
    for m in re.finditer(r"<a\b[^>]*>", html, flags=re.I):
        end = html.find("</a>", m.end())
        if end != -1:
            out.append(html[m.start() : end + 4])
    return out


def anchor_open_tag(anchor_html: str) -> str:
    end = anchor_html.find(">")
    return anchor_html[: end + 1] if end != -1 else anchor_html


def discover_event_urls(locale: str, keyword: str) -> List[Dict[str, str]]:
    sitemap = fetch_text(f"{BASE_URL}/sitemap.xml").text
    root = ET.fromstring(sitemap)
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    event_root_re = re.compile(r"^/([a-z]{2}-[A-Z]{2})/events/([^/]+)$")

    slugs: List[str] = []
    for loc in root.findall(".//sm:loc", ns):
        if not loc.text:
            continue
        url = loc.text.strip()
        m = event_root_re.match(urlparse(url).path)
        if not m:
            continue
        slug = m.group(2).strip()
        if keyword.lower() in slug.lower():
            slugs.append(slug)

    seen = set()
    results = []
    for slug in slugs:
        if slug in seen:
            continue
        seen.add(slug)
        url = f"{BASE_URL}/{locale}/events/{slug}"
        label = slug.replace("-", " ").title()
        results.append({"slug": slug, "url": url, "label": label})
    return results


def parse_jsonld(html: str) -> List[Dict]:
    data = []
    for m in re.finditer(r'<script\s+type="application/ld\+json">(.*?)</script>', html, flags=re.S):
        raw = m.group(1).strip()
        if not raw:
            continue
        try:
            parsed = json.loads(raw)
            data.append(parsed)
        except json.JSONDecodeError:
            pass
    return data


def parse_event_page(html: str, event_url: str) -> Dict:
    event: Dict = {
        "event_url": event_url,
        "slug": urlparse(event_url).path.rstrip("/").split("/")[-1],
        "title": None,
        "start_datetime": None,
        "end_datetime": None,
        "date_text_start": None,
        "date_text_end": None,
        "venue": None,
        "description": None,
        "banner_image": None,
        "social_links": [],
        "stream_platforms": [],
        "quick_links": [],
        "timetable": [],
        "lineup": [],
        "photos": [],
        "jsonld": parse_jsonld(html),
    }

    title_m = re.search(r'<h2\s+class="event-information__title">(.*?)</h2>', html, flags=re.S)
    if title_m:
        event["title"] = strip_tags(title_m.group(1))

    desc_m = re.search(r'<p\s+class="event-information__description">(.*?)</p>', html, flags=re.S)
    if desc_m:
        event["description"] = strip_tags(desc_m.group(1))

    venue_m = re.search(r'<span\s+class="icon-text__label">([^<]+)</span>', html)
    if venue_m:
        event["venue"] = strip_tags(venue_m.group(1))

    banner_m = re.search(r'<img\s+src="([^"]+)"[^>]*event-area__banner__image', html)
    if banner_m:
        event["banner_image"] = urljoin(BASE_URL, banner_m.group(1))

    date_block_m = re.search(r'<div\s+class="event-information__date">(.*?)</div>', html, flags=re.S)
    if date_block_m:
        block = date_block_m.group(1)
        dt_vals = re.findall(r'<time[^>]*datetime="([^"]+)"', block)
        date_texts = re.findall(r'<span\s+class="datetime__date">([^<]+)</span>', block)
        if dt_vals:
            event["start_datetime"] = dt_vals[0]
            if len(dt_vals) > 1:
                event["end_datetime"] = dt_vals[1]
        if date_texts:
            event["date_text_start"] = strip_tags(date_texts[0])
            if len(date_texts) > 1:
                event["date_text_end"] = strip_tags(date_texts[1])

    for a_html in find_anchor_blocks(html):
        attrs = parse_attrs(anchor_open_tag(a_html))
        klass = attrs.get("class", "")
        href = attrs.get("href")
        if not href:
            continue
        if "tag-button--" in klass:
            event["social_links"].append(
                {
                    "type": attrs.get("aria-label"),
                    "url": href,
                    "text": strip_tags(a_html),
                }
            )

    stream_block_m = re.search(r'event-information__details-item--streams">(.*?)</li>', html, flags=re.S)
    if stream_block_m:
        for a in find_anchor_blocks(stream_block_m.group(1)):
            attrs = parse_attrs(anchor_open_tag(a))
            if attrs.get("href"):
                event["stream_platforms"].append({"name": strip_tags(a), "url": attrs["href"]})

    timetable_html = extract_section_by_id(html, "timetable")
    for a_html in find_anchor_blocks(timetable_html):
        attrs = parse_attrs(anchor_open_tag(a_html))
        if "action-card--timetable" not in attrs.get("class", ""):
            continue
        href = attrs.get("href")
        if not href:
            continue
        dt_m = re.search(r'<time[^>]*datetime="([^"]+)"', a_html)
        date_text_m = re.search(r'<span\s+class="datetime__date">([^<]+)</span>', a_html)
        time_text_m = re.search(r'<span\s+class="datetime__time">([^<]+)</span>', a_html)
        event["timetable"].append(
            {
                "name": attrs.get("aria-label"),
                "url": urljoin(BASE_URL, href),
                "start_datetime": dt_m.group(1) if dt_m else None,
                "date_text": strip_tags(date_text_m.group(1)) if date_text_m else None,
                "time_text": strip_tags(time_text_m.group(1)) if time_text_m else None,
            }
        )

    photos_html = extract_section_by_id(html, "photos")
    for a_html in find_anchor_blocks(photos_html):
        attrs = parse_attrs(anchor_open_tag(a_html))
        if "lightbox-link" not in attrs.get("class", ""):
            continue
        href = attrs.get("href")
        label_m = re.search(r'<span\s+class="icon-text__label">([^<]+)</span>', a_html)
        img_m = re.search(r'<img[^>]*src="([^"]+)"[^>]*alt="([^"]*)"', a_html)
        event["photos"].append(
            {
                "label": strip_tags(label_m.group(1)) if label_m else None,
                "image_url": urljoin(BASE_URL, href) if href else None,
                "thumbnail_url": urljoin(BASE_URL, img_m.group(1)) if img_m else None,
                "alt": strip_tags(img_m.group(2)) if img_m else None,
            }
        )

    lineup_html = extract_section_by_id(html, "lineup")
    for group in re.finditer(
        r'<span\s+class="tag\s+tag--outline"[^>]*>(.*?)</span>(.*?)</ul>',
        lineup_html,
        flags=re.S,
    ):
        day = strip_tags(group.group(1))
        artists = [strip_tags(x) for x in re.findall(r"<li>(.*?)</li>", group.group(2), flags=re.S)]
        event["lineup"].append({"group": day, "artists": artists})

    quick_links_m = re.search(r'<div class="quick-links[^>]*">(.*?)</div></div></div>', html, flags=re.S)
    if quick_links_m:
        for a in find_anchor_blocks(quick_links_m.group(1)):
            attrs = parse_attrs(anchor_open_tag(a))
            href = attrs.get("href")
            if href:
                event["quick_links"].append({"text": strip_tags(a), "url": urljoin(BASE_URL, href)})

    return event


def to_pascal_token(text: Optional[str]) -> str:
    src = str(text or "").strip()
    if not src:
        return ""
    cleaned = "".join(ch if ch.isalnum() else " " for ch in src)
    words = [w for w in cleaned.split() if w]
    return "".join((w[0].upper() + w[1:]) for w in words)


def date_token_from_start_datetime(start_datetime: Optional[str]) -> str:
    src = str(start_datetime or "").strip()
    if not src:
        return ""
    m = re.match(r"^(\d{4})-(\d{2})-(\d{2})", src)
    if not m:
        m = re.match(r"^(\d{4})[/.](\d{2})[/.](\d{2})", src)
    if m:
        return f"{m.group(1)}{m.group(2)}{m.group(3)}"
    digits = re.sub(r"\D", "", src)
    return digits[:8] if len(digits) >= 8 else ""


def _iter_event_nodes_from_jsonld(jsonld: List[Dict]) -> List[Dict]:
    out: List[Dict] = []
    for item in jsonld or []:
        if isinstance(item, dict):
            if item.get("@type") == "Event":
                out.append(item)
            graph = item.get("@graph")
            if isinstance(graph, list):
                for n in graph:
                    if isinstance(n, dict) and n.get("@type") == "Event":
                        out.append(n)
        elif isinstance(item, list):
            for n in item:
                if isinstance(n, dict) and n.get("@type") == "Event":
                    out.append(n)
    return out


def extract_country_from_event(event: Dict) -> str:
    nodes = _iter_event_nodes_from_jsonld(event.get("jsonld") or [])
    for node in nodes:
        location = node.get("location")
        address = {}
        if isinstance(location, dict):
            address = location.get("address") or {}
        if not isinstance(address, dict):
            address = {}
        from_country = str(address.get("addressCountry") or "").strip()
        if from_country:
            return from_country
        name = str(address.get("name") or "").strip()
        if name:
            parts = [p.strip() for p in name.split(",") if p.strip()]
            if parts:
                return parts[-1]
    return ""


def build_festival_id_from_event(event: Dict) -> str:
    date_part = date_token_from_start_datetime(event.get("start_datetime"))
    name_part = to_pascal_token(event.get("title") or event.get("slug"))
    country_part = to_pascal_token(extract_country_from_event(event))
    if not date_part or not name_part or not country_part:
        return ""
    return f"{date_part}-{name_part}-{country_part}"


def normalize_lineup_item(item: Dict[str, Any]) -> Dict[str, str]:
    musician = str(item.get("musician") or "").strip() or "未知"
    date = str(item.get("date") or "").strip() or "未知"
    time_text = normalize_time_text(str(item.get("time") or "").strip())
    stage = str(item.get("stage") or "").strip() or "未知"
    return {
        "musician": musician,
        "date": date,
        "time": time_text,
        "stage": stage,
    }


def _convert_ampm_to_24h(text: str) -> Optional[str]:
    src = str(text or "").strip()
    m = re.match(r"^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])$", src)
    if not m:
        return None
    hour = int(m.group(1))
    minute = int(m.group(2) or "0")
    ampm = m.group(3).lower()
    if hour < 1 or hour > 12 or minute < 0 or minute > 59:
        return None
    if ampm == "am":
        hour = 0 if hour == 12 else hour
    else:
        hour = 12 if hour == 12 else hour + 12
    return f"{hour:02d}:{minute:02d}"


def _normalize_single_time(text: str) -> str:
    src = str(text or "").strip()
    if not src:
        return ""
    src = src.replace(".", ":")
    ampm_24h = _convert_ampm_to_24h(src.replace(" ", ""))
    if ampm_24h:
        return ampm_24h
    m = re.match(r"^(\d{1,2})(?::(\d{2}))$", src)
    if m:
        hour = int(m.group(1))
        minute = int(m.group(2))
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            return f"{hour:02d}:{minute:02d}"
    return src


def normalize_time_text(text: str) -> str:
    src = str(text or "").strip()
    if not src:
        return "未知"
    src = re.sub(r"\s*[–—-]\s*", " - ", src)
    parts = [p.strip() for p in src.split(" - ")]
    if len(parts) == 2 and parts[0] and parts[1]:
        start = _normalize_single_time(parts[0])
        end = _normalize_single_time(parts[1])
        return f"{start}—{end}"
    single = _normalize_single_time(src)
    return single or "未知"


def _norm_key(key: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", str(key or "").strip().lower())


def _normalize_country_lookup_key(text: Any) -> str:
    return re.sub(r"[^A-Z0-9\u4e00-\u9fff]+", "", str(text or "").strip().upper())


def _load_country_i18n_reference() -> Dict[str, Dict[str, str]]:
    alpha3_to_en: Dict[str, str] = {}
    lookup: Dict[str, str] = {}
    source_path = PROJECT_ROOT / "country-codes-iso3166.json"
    try:
        raw = json.loads(source_path.read_text(encoding="utf-8"))
        rows = raw if isinstance(raw, list) else []
    except Exception:  # noqa: BLE001
        rows = []

    for row in rows:
        if not isinstance(row, dict):
            continue
        alpha2 = str(row.get("alpha2") or "").strip().upper()
        alpha3 = str(row.get("alpha3") or "").strip().upper()
        en = str(row.get("en") or "").strip()
        zh = str(row.get("zh") or "").strip()
        if alpha3 and en:
            alpha3_to_en[alpha3] = en
        for token in (alpha2, alpha3, en, zh):
            key = _normalize_country_lookup_key(token)
            if key and alpha3 and key not in lookup:
                lookup[key] = alpha3

    # Common aliases
    if "UK" not in lookup:
        lookup["UK"] = "GBR"
    if "PRC" not in lookup:
        lookup["PRC"] = "CHN"
    if "MACAU" not in lookup:
        lookup["MACAU"] = "MAC"

    return {
        "alpha3_to_en": alpha3_to_en,
        "lookup": lookup,
    }


_COUNTRY_I18N_REF = _load_country_i18n_reference()


def _resolve_country_alpha3(raw: Any) -> str:
    text = str(raw or "").strip()
    if not text:
        return ""
    key = _normalize_country_lookup_key(text)
    if not key:
        return ""
    lookup = _COUNTRY_I18N_REF.get("lookup", {})
    if key in lookup:
        return str(lookup.get(key) or "").strip().upper()
    if re.fullmatch(r"[A-Z]{3}", key):
        return key
    if key == "UK":
        return "GBR"
    return ""


def _resolve_country_en_full(country_i18n: Dict[str, Any]) -> str:
    if not isinstance(country_i18n, dict):
        return ""
    explicit = str(
        country_i18n.get("enFull")
        or country_i18n.get("en_full")
        or country_i18n.get("englishFull")
        or ""
    ).strip()
    if explicit:
        return explicit

    alpha3 = _resolve_country_alpha3(country_i18n.get("en"))
    if not alpha3:
        alpha3 = _resolve_country_alpha3(country_i18n.get("zh"))
    if not alpha3:
        alpha3 = _resolve_country_alpha3(country_i18n.get("country"))
    if alpha3:
        alpha3_map = _COUNTRY_I18N_REF.get("alpha3_to_en", {})
        if alpha3 in alpha3_map:
            return str(alpha3_map.get(alpha3) or "").strip()

    en_fallback = str(country_i18n.get("en") or "").strip()
    if en_fallback and not re.fullmatch(r"[A-Z]{3}", en_fallback.upper()):
        return en_fallback
    return ""


def _normalize_country_i18n(value: Any, fallback: Any = "") -> Dict[str, str]:
    out = {"en": "", "zh": "", "enFull": ""}
    if isinstance(value, dict):
        out["en"] = str(value.get("en") or value.get("EN") or value.get("english") or "").strip()
        out["zh"] = str(value.get("zh") or value.get("ZH") or value.get("cn") or value.get("chinese") or "").strip()
        out["enFull"] = str(
            value.get("enFull")
            or value.get("en_full")
            or value.get("englishFull")
            or value.get("country_en_full")
            or ""
        ).strip()
    else:
        text = str(value or "").strip()
        if text:
            out["en"] = text
            out["zh"] = text

    if not out["en"] and not out["zh"]:
        fb = str(fallback or "").strip()
        if fb:
            out["en"] = fb
            out["zh"] = fb
    if out["en"] and not out["zh"]:
        out["zh"] = out["en"]
    if out["zh"] and not out["en"]:
        out["en"] = out["zh"]

    alpha3 = _resolve_country_alpha3(out["en"])
    if not alpha3:
        alpha3 = _resolve_country_alpha3(out["zh"])
    if alpha3:
        out["en"] = alpha3

    if not out["enFull"]:
        out["enFull"] = _resolve_country_en_full(out)

    return out


def _parse_kv_text(text: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    src = str(text or "").strip()
    if not src:
        return out
    for raw_line in src.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        m = re.match(r"^\s*([A-Za-z0-9_\- \u4e00-\u9fff]+)\s*[:：]\s*(.+?)\s*$", line)
        if not m:
            continue
        out[m.group(1).strip()] = m.group(2).strip()
    return out


def _split_date_range_text(text: str) -> Optional[Dict[str, str]]:
    src = str(text or "").strip()
    if not src:
        return None
    m = re.match(r"^\s*(\d{4}[./-]\d{1,2}[./-]\d{1,2})\s*(?:~|—|–|to|TO|-)\s*(\d{4}[./-]\d{1,2}[./-]\d{1,2})\s*$", src)
    if not m:
        return None
    return {"start_date": m.group(1), "end_date": m.group(2)}


def _normalize_date_value(text: str) -> str:
    src = str(text or "").strip()
    if not src:
        return ""
    m = re.match(r"^\s*(\d{4})[./-](\d{1,2})[./-](\d{1,2})\s*$", src)
    if m:
        return f"{m.group(1)}-{int(m.group(2)):02d}-{int(m.group(3)):02d}"
    return src


def extract_event_info(payload: Any) -> Dict[str, Any]:
    out: Dict[str, Any] = {
        "start_date": "",
        "end_date": "",
        "nameI18n": {"en": "", "zh": ""},
        "cityI18n": {"en": "", "zh": ""},
        "detailAddressI18n": {"en": "", "zh": ""},
        "countryI18n": {"en": "", "zh": "", "enFull": ""},
    }
    date_key_map = {
        "startdate": "start_date",
        "start": "start_date",
        "begindate": "start_date",
        "datefrom": "start_date",
        "enddate": "end_date",
        "end": "end_date",
        "finishdate": "end_date",
        "dateto": "end_date",
    }
    scalar_bi_key_map = {
        "eventname": "nameI18n",
        "festivalname": "nameI18n",
        "name": "nameI18n",
        "title": "nameI18n",
        "city": "cityI18n",
        "country": "countryI18n",
        "countryname": "countryI18n",
        "detailaddress": "detailAddressI18n",
        "venue": "detailAddressI18n",
        "location": "detailAddressI18n",
        "place": "detailAddressI18n",
        "address": "detailAddressI18n",
    }
    lang_key_map = {
        "nameen": ("nameI18n", "en"),
        "namezh": ("nameI18n", "zh"),
        "festivalnameen": ("nameI18n", "en"),
        "festivalnamezh": ("nameI18n", "zh"),
        "eventnameen": ("nameI18n", "en"),
        "eventnamezh": ("nameI18n", "zh"),
        "titleen": ("nameI18n", "en"),
        "titlezh": ("nameI18n", "zh"),
        "cityen": ("cityI18n", "en"),
        "cityzh": ("cityI18n", "zh"),
        "detailaddressen": ("detailAddressI18n", "en"),
        "detailaddresszh": ("detailAddressI18n", "zh"),
        "venueen": ("detailAddressI18n", "en"),
        "venuezh": ("detailAddressI18n", "zh"),
        "locationen": ("detailAddressI18n", "en"),
        "locationzh": ("detailAddressI18n", "zh"),
        "countryen": ("countryI18n", "en"),
        "countryzh": ("countryI18n", "zh"),
        "countryenfull": ("countryI18n", "enFull"),
        "countryenglishfull": ("countryI18n", "enFull"),
        "countryfullnameen": ("countryI18n", "enFull"),
        "countryfullen": ("countryI18n", "enFull"),
    }
    object_alias = {
        "namei18n": "nameI18n",
        "festivalnamei18n": "nameI18n",
        "eventnamei18n": "nameI18n",
        "cityi18n": "cityI18n",
        "detailaddressi18n": "detailAddressI18n",
        "venuei18n": "detailAddressI18n",
        "locationi18n": "detailAddressI18n",
        "countryi18n": "countryI18n",
    }

    def set_date(field: str, value: Any) -> None:
        if field not in ("start_date", "end_date"):
            return
        text = str(value or "").strip()
        if not text:
            return
        if not out[field]:
            out[field] = text

    def set_bi(path_key: str, lang: str, value: Any) -> None:
        if path_key not in out:
            return
        if lang not in ("en", "zh", "enFull"):
            return
        text = str(value or "").strip()
        if not text:
            return
        current = out.get(path_key)
        if not isinstance(current, dict):
            return
        if not str(current.get(lang) or "").strip():
            current[lang] = text

    def set_bi_scalar(path_key: str, value: Any) -> None:
        text = str(value or "").strip()
        if not text:
            return
        set_bi(path_key, "en", text)
        set_bi(path_key, "zh", text)

    def set_bi_from_obj(path_key: str, obj: Dict[str, Any]) -> None:
        set_bi(path_key, "en", obj.get("en") or obj.get("english") or obj.get("name_en"))
        set_bi(path_key, "zh", obj.get("zh") or obj.get("chinese") or obj.get("name_zh") or obj.get("cn"))
        set_bi(
            path_key,
            "enFull",
            obj.get("enFull")
            or obj.get("en_full")
            or obj.get("englishFull")
            or obj.get("country_en_full"),
        )

    def walk(node: Any):
        if isinstance(node, dict):
            for k, v in node.items():
                nk = _norm_key(k)

                mapped_date = date_key_map.get(nk)
                if mapped_date and not isinstance(v, (dict, list)):
                    set_date(mapped_date, v)

                mapped_lang = lang_key_map.get(nk)
                if mapped_lang and not isinstance(v, (dict, list)):
                    set_bi(mapped_lang[0], mapped_lang[1], v)

                mapped_scalar = scalar_bi_key_map.get(nk)
                if mapped_scalar and not isinstance(v, (dict, list)):
                    set_bi_scalar(mapped_scalar, v)

                if nk in ("daterange", "date", "time", "eventdate") and not isinstance(v, (dict, list)):
                    split = _split_date_range_text(str(v))
                    if split:
                        set_date("start_date", split.get("start_date"))
                        set_date("end_date", split.get("end_date"))
                    else:
                        set_date("start_date", v)
                        set_date("end_date", v)

                if isinstance(v, dict):
                    path_key = object_alias.get(nk)
                    if path_key:
                        set_bi_from_obj(path_key, v)
                    if nk in ("manuallocation", "manuallocationi18n"):
                        detail_obj = v.get("detailAddressI18n") or v.get("detail_address_i18n")
                        if isinstance(detail_obj, dict):
                            set_bi_from_obj("detailAddressI18n", detail_obj)
                        elif detail_obj is not None:
                            set_bi_scalar("detailAddressI18n", detail_obj)
                    walk(v)
                    continue

                if isinstance(v, list):
                    walk(v)
                    continue

                if isinstance(v, str):
                    parsed = _extract_json_fragment(v)
                    if parsed is not None:
                        walk(parsed)
                    else:
                        kv = _parse_kv_text(v)
                        if kv:
                            walk(kv)
        elif isinstance(node, list):
            for x in node:
                walk(x)
        elif isinstance(node, str):
            parsed = _extract_json_fragment(node)
            if parsed is not None:
                walk(parsed)
            else:
                kv = _parse_kv_text(node)
                if kv:
                    walk(kv)

    walk(payload)

    translated = extract_translation_info(payload)
    for field_key in ("nameI18n", "cityI18n", "detailAddressI18n", "countryI18n"):
        current = out.get(field_key) if isinstance(out.get(field_key), dict) else {}
        trans = translated.get(field_key) if isinstance(translated.get(field_key), dict) else {}
        if not str(current.get("en") or "").strip() and str(trans.get("en") or "").strip():
            current["en"] = str(trans.get("en")).strip()
        if not str(current.get("zh") or "").strip() and str(trans.get("zh") or "").strip():
            current["zh"] = str(trans.get("zh")).strip()
        if field_key == "countryI18n":
            if not str(current.get("enFull") or "").strip() and str(trans.get("enFull") or "").strip():
                current["enFull"] = str(trans.get("enFull")).strip()
        out[field_key] = current

    out["start_date"] = _normalize_date_value(out.get("start_date"))
    out["end_date"] = _normalize_date_value(out.get("end_date"))
    if out["start_date"] and not out["end_date"]:
        out["end_date"] = out["start_date"]
    if out["end_date"] and not out["start_date"]:
        out["start_date"] = out["end_date"]

    for field_key in ("nameI18n", "cityI18n", "detailAddressI18n", "countryI18n"):
        node = out.get(field_key)
        if not isinstance(node, dict):
            out[field_key] = {"en": "", "zh": "", "enFull": ""} if field_key == "countryI18n" else {"en": "", "zh": ""}
            continue
        en = str(node.get("en") or "").strip()
        zh = str(node.get("zh") or "").strip()
        if en and not zh:
            node["zh"] = en
        elif zh and not en:
            node["en"] = zh
        if field_key == "countryI18n":
            out[field_key] = _normalize_country_i18n(node)
        else:
            out[field_key] = {"en": str(node.get("en") or "").strip(), "zh": str(node.get("zh") or "").strip()}

    return out


def _extract_json_fragment(text: str) -> Optional[Any]:
    src = str(text or "").strip()
    if not src:
        return None
    try:
        return json.loads(src)
    except Exception:  # noqa: BLE001
        pass

    src = re.sub(r"^```(?:json)?\s*", "", src, flags=re.I)
    src = re.sub(r"\s*```$", "", src)
    try:
        return json.loads(src)
    except Exception:  # noqa: BLE001
        pass

    m = re.search(r"(\{[\s\S]*\}|\[[\s\S]*\])", src)
    if m:
        chunk = m.group(1)
        try:
            return json.loads(chunk)
        except Exception:  # noqa: BLE001
            return None
    return None


def parse_lineup_from_plaintext(text: str) -> List[Dict[str, str]]:
    out: List[Dict[str, str]] = []
    src = str(text or "").strip()
    if not src:
        return out
    for raw_line in src.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        m = re.match(r"^\s*(.+?)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*(.+?)\s*$", line)
        if not m:
            continue
        out.append(
            normalize_lineup_item(
                {
                    "musician": m.group(1),
                    "date": m.group(2),
                    "time": m.group(3),
                    "stage": m.group(4),
                }
            )
        )
    return out


def extract_lineup_info(payload: Any) -> List[Dict[str, str]]:
    results: List[Dict[str, str]] = []

    def walk(node: Any):
        if isinstance(node, dict):
            lineup = node.get("lineup_info")
            if isinstance(lineup, list):
                for x in lineup:
                    if isinstance(x, dict):
                        results.append(normalize_lineup_item(x))
            for k, v in node.items():
                if isinstance(v, (dict, list)):
                    walk(v)
                elif isinstance(v, str) and k.lower() in ("formatted_output", "output", "result", "content", "text", "message", "data"):
                    parsed = _extract_json_fragment(v)
                    if parsed is not None:
                        walk(parsed)
                    else:
                        results.extend(parse_lineup_from_plaintext(v))
        elif isinstance(node, list):
            for x in node:
                walk(x)

    walk(payload)
    dedup: Dict[str, Dict[str, str]] = {}
    for item in results:
        key = f"{item['musician']}|{item['date']}|{item['time']}|{item['stage']}"
        dedup[key] = item
    return list(dedup.values())


def extract_translation_info(payload: Any) -> Dict[str, Dict[str, str]]:
    out: Dict[str, Dict[str, str]] = {
        "nameI18n": {"en": "", "zh": ""},
        "cityI18n": {"en": "", "zh": ""},
        "detailAddressI18n": {"en": "", "zh": ""},
        "countryI18n": {"en": "", "zh": "", "enFull": ""},
    }
    key_map = {
        "nameen": ("nameI18n", "en"),
        "namezh": ("nameI18n", "zh"),
        "festivalnameen": ("nameI18n", "en"),
        "festivalnamezh": ("nameI18n", "zh"),
        "eventnameen": ("nameI18n", "en"),
        "eventnamezh": ("nameI18n", "zh"),
        "titleen": ("nameI18n", "en"),
        "titlezh": ("nameI18n", "zh"),
        "cityen": ("cityI18n", "en"),
        "cityzh": ("cityI18n", "zh"),
        "detailaddressen": ("detailAddressI18n", "en"),
        "detailaddresszh": ("detailAddressI18n", "zh"),
        "countryen": ("countryI18n", "en"),
        "countryzh": ("countryI18n", "zh"),
        "countryenfull": ("countryI18n", "enFull"),
        "countryenglishfull": ("countryI18n", "enFull"),
        "countryfullnameen": ("countryI18n", "enFull"),
        "countryfullen": ("countryI18n", "enFull"),
    }
    object_alias = {
        "namei18n": "nameI18n",
        "festivalnamei18n": "nameI18n",
        "eventnamei18n": "nameI18n",
        "name": "nameI18n",
        "title": "nameI18n",
        "cityi18n": "cityI18n",
        "city": "cityI18n",
        "detailaddressi18n": "detailAddressI18n",
        "detailaddress": "detailAddressI18n",
        "countryi18n": "countryI18n",
        "country": "countryI18n",
    }

    def set_field(path_key: str, lang: str, value: Any) -> None:
        text = str(value or "").strip()
        if not text:
            return
        if path_key not in out or lang not in out[path_key]:
            return
        if not out[path_key][lang]:
            out[path_key][lang] = text

    def try_fill_from_obj(alias_key: str, obj: Dict[str, Any]) -> None:
        path_key = object_alias.get(alias_key, "")
        if not path_key:
            return
        set_field(path_key, "en", obj.get("en") or obj.get("english") or obj.get("name_en"))
        set_field(path_key, "zh", obj.get("zh") or obj.get("chinese") or obj.get("name_zh") or obj.get("cn"))
        if path_key == "countryI18n":
            set_field(
                path_key,
                "enFull",
                obj.get("enFull")
                or obj.get("en_full")
                or obj.get("englishFull")
                or obj.get("country_en_full"),
            )

    def walk(node: Any):
        if isinstance(node, dict):
            for k, v in node.items():
                nk = _norm_key(k)
                if isinstance(v, dict):
                    if nk in ("manuallocation", "manuallocationi18n"):
                        detail_obj = v.get("detailAddressI18n") or v.get("detail_address_i18n")
                        if isinstance(detail_obj, dict):
                            try_fill_from_obj("detailaddressi18n", detail_obj)
                        elif detail_obj is not None:
                            set_field("detailAddressI18n", "en", detail_obj)
                            set_field("detailAddressI18n", "zh", detail_obj)
                    try_fill_from_obj(nk, v)
                    walk(v)
                    continue
                mapped = key_map.get(nk)
                if mapped:
                    set_field(mapped[0], mapped[1], v)
                if isinstance(v, list):
                    walk(v)
                elif isinstance(v, str):
                    parsed = _extract_json_fragment(v)
                    if parsed is not None:
                        walk(parsed)
                    else:
                        kv = _parse_kv_text(v)
                        if kv:
                            walk(kv)
        elif isinstance(node, list):
            for x in node:
                walk(x)
        elif isinstance(node, str):
            parsed = _extract_json_fragment(node)
            if parsed is not None:
                walk(parsed)
            else:
                kv = _parse_kv_text(node)
                if kv:
                    walk(kv)

    walk(payload)
    for field_key in ("nameI18n", "cityI18n", "detailAddressI18n", "countryI18n"):
        en = str(out.get(field_key, {}).get("en") or "").strip()
        zh = str(out.get(field_key, {}).get("zh") or "").strip()
        if en and not zh:
            out[field_key]["zh"] = en
        elif zh and not en:
            out[field_key]["en"] = zh
        if field_key == "countryI18n":
            out[field_key] = _normalize_country_i18n(out.get(field_key) or {})
    return out


def _normalize_location_bi_text(value: Any, fallback: Any = "") -> Dict[str, str]:
    out = {"en": "", "zh": ""}
    if isinstance(value, dict):
        out["en"] = str(
            value.get("en")
            or value.get("EN")
            or value.get("english")
            or value.get("name_en")
            or value.get("address_en")
            or ""
        ).strip()
        out["zh"] = str(
            value.get("zh")
            or value.get("ZH")
            or value.get("cn")
            or value.get("chinese")
            or value.get("name_zh")
            or value.get("address_zh")
            or ""
        ).strip()
    else:
        text = str(value or "").strip()
        if text:
            out["en"] = text
            out["zh"] = text
    if not out["en"] and not out["zh"]:
        fb = str(fallback or "").strip()
        if fb:
            out["en"] = fb
            out["zh"] = fb
    if out["en"] and not out["zh"]:
        out["zh"] = out["en"]
    if out["zh"] and not out["en"]:
        out["en"] = out["zh"]
    return out


def _location_parse_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        val = float(value)
        return val if val == val and val not in (float("inf"), float("-inf")) else None
    text = str(value or "").strip()
    if not text:
        return None
    try:
        val = float(text)
    except Exception:  # noqa: BLE001
        return None
    if val != val or val in (float("inf"), float("-inf")):
        return None
    return val


def _location_parse_types(value: Any) -> List[str]:
    if isinstance(value, list):
        return [str(item or "").strip() for item in value if str(item or "").strip()][:20]
    if isinstance(value, str):
        return [part.strip() for part in value.split(",") if part.strip()][:20]
    return []


def _location_extract_candidate(payload: Any) -> Dict[str, Any]:
    candidates: List[Dict[str, Any]] = []

    def score_node(node: Dict[str, Any]) -> int:
        keys = {_norm_key(k) for k in node.keys()}
        score = 0
        if "location" in keys:
            score += 5
        if "lng" in keys or "longitude" in keys:
            score += 3
        if "lat" in keys or "latitude" in keys:
            score += 3
        for token in (
            "namei18n",
            "addressi18n",
            "formattedaddressi18n",
            "countrycode",
            "city",
            "providerplaceid",
            "provider",
            "providermeta",
        ):
            if token in keys:
                score += 1
        return score

    def push(node: Any, bonus: int = 0) -> None:
        if not isinstance(node, dict):
            return
        score = score_node(node) + max(0, bonus)
        if score <= 0:
            return
        candidates.append({"score": score, "node": node})

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            push(node)
            for key, value in node.items():
                nk = _norm_key(key)
                if isinstance(value, dict):
                    if nk in (
                        "locationpoint",
                        "location",
                        "normalized",
                        "normalizedlocation",
                        "normalizedlocationpoint",
                        "result",
                        "output",
                        "data",
                    ):
                        push(value, bonus=4)
                    walk(value)
                    continue
                if isinstance(value, list):
                    walk(value)
                    continue
                if isinstance(value, str):
                    parsed = _extract_json_fragment(value)
                    if parsed is not None:
                        walk(parsed)
        elif isinstance(node, list):
            for item in node:
                walk(item)
        elif isinstance(node, str):
            parsed = _extract_json_fragment(node)
            if parsed is not None:
                walk(parsed)

    walk(payload)
    if not candidates:
        return {}
    ranked = sorted(candidates, key=lambda item: item.get("score", 0), reverse=True)
    top = ranked[0].get("node")
    return top if isinstance(top, dict) else {}


def extract_location_normalization_info(payload: Any) -> Dict[str, Any]:
    src = _location_extract_candidate(payload)
    if not isinstance(src, dict):
        src = {}

    loc = src.get("location") if isinstance(src.get("location"), dict) else {}
    lng = _location_parse_float(src.get("lng"))
    if lng is None:
        lng = _location_parse_float(src.get("longitude"))
    if lng is None:
        lng = _location_parse_float(loc.get("lng"))
    if lng is None:
        lng = _location_parse_float(loc.get("longitude"))

    lat = _location_parse_float(src.get("lat"))
    if lat is None:
        lat = _location_parse_float(src.get("latitude"))
    if lat is None:
        lat = _location_parse_float(loc.get("lat"))
    if lat is None:
        lat = _location_parse_float(loc.get("latitude"))

    provider_meta_raw = src.get("providerMeta")
    if not isinstance(provider_meta_raw, dict):
        provider_meta_raw = src.get("provider_meta") if isinstance(src.get("provider_meta"), dict) else {}

    amap_meta = provider_meta_raw.get("amap") if isinstance(provider_meta_raw.get("amap"), dict) else {}
    mapkit_meta = provider_meta_raw.get("mapkit") if isinstance(provider_meta_raw.get("mapkit"), dict) else {}
    mapbox_meta = provider_meta_raw.get("mapbox") if isinstance(provider_meta_raw.get("mapbox"), dict) else {}
    geoapify_meta = provider_meta_raw.get("geoapify") if isinstance(provider_meta_raw.get("geoapify"), dict) else {}
    google_meta = provider_meta_raw.get("google") if isinstance(provider_meta_raw.get("google"), dict) else {}

    poi_id = str(src.get("poiId") or src.get("poi_id") or amap_meta.get("poiId") or "").strip()
    adcode = str(src.get("adcode") or amap_meta.get("adcode") or "").strip()
    mapkit_id = str(
        src.get("mapkitMapItemIdentifier")
        or src.get("mapItemIdentifier")
        or mapkit_meta.get("mapItemIdentifier")
        or ""
    ).strip()
    mapbox_place_id = str(src.get("mapboxPlaceId") or mapbox_meta.get("placeId") or "").strip()
    mapbox_feature_type = str(src.get("mapboxFeatureType") or mapbox_meta.get("featureType") or "").strip()
    geoapify_place_id = str(src.get("geoapifyPlaceId") or geoapify_meta.get("placeId") or "").strip()
    geoapify_feature_type = str(src.get("geoapifyFeatureType") or geoapify_meta.get("featureType") or "").strip()
    google_place_id = str(src.get("googlePlaceId") or google_meta.get("placeId") or "").strip()
    google_types = _location_parse_types(src.get("googleTypes") or google_meta.get("types"))

    provider_place_id = str(
        src.get("providerPlaceId")
        or src.get("provider_place_id")
        or poi_id
        or mapkit_id
        or mapbox_place_id
        or geoapify_place_id
        or google_place_id
        or ""
    ).strip()

    country_code_raw = str(src.get("countryCode") or src.get("country_code") or "").strip()
    country_code = _resolve_country_alpha3(country_code_raw) or country_code_raw.upper()

    out: Dict[str, Any] = {
        "provider": str(src.get("provider") or "").strip(),
        "sourceMode": str(src.get("sourceMode") or src.get("source_mode") or "").strip(),
        "providerPlaceId": provider_place_id,
        "poiId": poi_id,
        "adcode": adcode,
        "location": {"lng": lng, "lat": lat} if lng is not None and lat is not None else {},
        "nameI18n": _normalize_location_bi_text(src.get("nameI18n") or src.get("name_i18n") or src.get("name") or ""),
        "addressI18n": _normalize_location_bi_text(src.get("addressI18n") or src.get("address_i18n") or src.get("address") or ""),
        "formattedAddressI18n": _normalize_location_bi_text(
            src.get("formattedAddressI18n") or src.get("formatted_address_i18n") or src.get("formattedAddress") or ""
        ),
        "countryCode": country_code,
        "city": str(src.get("city") or "").strip(),
        "district": str(src.get("district") or "").strip(),
        "province": str(src.get("province") or "").strip(),
        "providerMeta": {
            "amap": {"poiId": poi_id, "adcode": adcode},
            "mapkit": {"mapItemIdentifier": mapkit_id},
            "mapbox": {"placeId": mapbox_place_id, "featureType": mapbox_feature_type},
            "geoapify": {"placeId": geoapify_place_id, "featureType": geoapify_feature_type},
            "google": {"placeId": google_place_id, "types": google_types},
        },
    }
    return out


def extract_location_normalization_issues(payload: Any) -> List[str]:
    rows: List[str] = []
    seen: set[str] = set()

    def push(value: Any) -> None:
        text = str(value or "").strip()
        if not text:
            return
        text = " ".join(text.split())
        if len(text) > 240:
            text = text[:237] + "..."
        key = text.lower()
        if key in seen:
            return
        seen.add(key)
        rows.append(text)

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                nk = _norm_key(key)
                if nk in ("issues", "warnings", "warning", "errors", "error", "problems", "problem", "notes", "messages"):
                    if isinstance(value, list):
                        for item in value:
                            if isinstance(item, dict):
                                push(item.get("message") or item.get("text") or item.get("issue"))
                            else:
                                push(item)
                    elif isinstance(value, dict):
                        push(value.get("message") or value.get("text") or value.get("issue"))
                    else:
                        push(value)
                if isinstance(value, (dict, list)):
                    walk(value)
                elif isinstance(value, str):
                    parsed = _extract_json_fragment(value)
                    if parsed is not None:
                        walk(parsed)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    walk(payload)
    return rows[:20]


def extract_dj_translation_info(payload: Any) -> Dict[str, Dict[str, str]]:
    out: Dict[str, Dict[str, str]] = {
        "fields_cn": {"country": "", "bio": ""},
        "fields_en": {"country": "", "bio": ""},
    }

    def set_field(lang_key: str, field_key: str, value: Any) -> None:
        text = str(value or "").strip()
        if not text:
            return
        if lang_key not in out:
            return
        if field_key not in out[lang_key]:
            return
        if not out[lang_key][field_key]:
            out[lang_key][field_key] = text

    def fill_lang_fields(lang_key: str, obj: Dict[str, Any]) -> None:
        set_field(
            lang_key,
            "country",
            obj.get("country")
            or obj.get("countryName")
            or obj.get("nation")
            or obj.get("country_cn")
            or obj.get("country_en"),
        )
        set_field(
            lang_key,
            "bio",
            obj.get("bio")
            or obj.get("profile")
            or obj.get("description")
            or obj.get("intro")
            or obj.get("biography"),
        )

    def maybe_fill_by_dict_key(key: str, value: Dict[str, Any]) -> bool:
        nk = _norm_key(key)
        if nk in ("fieldscn", "fieldzh", "zhfields", "chinesefields", "cnfields"):
            fill_lang_fields("fields_cn", value)
            return True
        if nk in ("fieldsen", "fieldeng", "enfields", "englishfields"):
            fill_lang_fields("fields_en", value)
            return True
        if nk in ("countryi18n", "bioi18n", "fieldsi18n", "i18n"):
            zh_obj = value.get("zh")
            en_obj = value.get("en")
            if isinstance(zh_obj, dict):
                fill_lang_fields("fields_cn", zh_obj)
            if isinstance(en_obj, dict):
                fill_lang_fields("fields_en", en_obj)
            if isinstance(value.get("cn"), dict):
                fill_lang_fields("fields_cn", value.get("cn"))
            return True
        return False

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                nk = _norm_key(key)

                if isinstance(value, dict):
                    handled = maybe_fill_by_dict_key(key, value)
                    if not handled:
                        if nk in ("fieldscncountry", "countrycn", "cncountry", "zhcountry"):
                            set_field("fields_cn", "country", value.get("value") if isinstance(value, dict) else "")
                        if nk in ("fieldscnbio", "biocn", "cnbio", "zhbio"):
                            set_field("fields_cn", "bio", value.get("value") if isinstance(value, dict) else "")
                        if nk in ("fieldsencountry", "countryen", "encountry"):
                            set_field("fields_en", "country", value.get("value") if isinstance(value, dict) else "")
                        if nk in ("fieldsenbio", "bioen", "enbio"):
                            set_field("fields_en", "bio", value.get("value") if isinstance(value, dict) else "")
                    walk(value)
                    continue

                if nk in ("fieldscncountry", "countrycn", "cncountry", "zhcountry"):
                    set_field("fields_cn", "country", value)
                elif nk in ("fieldscnbio", "biocn", "cnbio", "zhbio"):
                    set_field("fields_cn", "bio", value)
                elif nk in ("fieldsencountry", "countryen", "encountry"):
                    set_field("fields_en", "country", value)
                elif nk in ("fieldsenbio", "bioen", "enbio"):
                    set_field("fields_en", "bio", value)

                if isinstance(value, str):
                    parsed = _extract_json_fragment(value)
                    if parsed is not None:
                        walk(parsed)
                    else:
                        kv = _parse_kv_text(value)
                        if kv:
                            walk(kv)
                elif isinstance(value, list):
                    walk(value)
        elif isinstance(node, list):
            for item in node:
                walk(item)
        elif isinstance(node, str):
            parsed = _extract_json_fragment(node)
            if parsed is not None:
                walk(parsed)
            else:
                kv = _parse_kv_text(node)
                if kv:
                    walk(kv)

    walk(payload)
    return out


def _is_dj_translation_hint_text(value: str) -> bool:
    text = str(value or "").strip()
    if not text:
        return False
    lowered = text.lower()
    compact = re.sub(r"\s+", "", lowered)
    compact_zh = re.sub(r"\s+", "", text)

    hint_tokens = (
        "please provide",
        "missing",
        "not provided",
        "no input",
        "input required",
        "invalid input",
        "cannot translate",
        "暂无内容",
        "没有提供",
        "未提供",
        "未上传",
        "未填写",
        "请提供",
        "请上传",
        "请填写",
        "无法翻译",
        "缺少",
        "为空",
    )
    if any(token in lowered for token in hint_tokens):
        return True
    if any(token in compact_zh for token in ("没有提供", "未提供", "未上传", "请提供", "请上传", "请填写", "暂无内容", "无法翻译")):
        return True
    if compact in ("n/a", "na", "none", "null", "undefined"):
        return True
    return False


def _clean_dj_translation_text(value: Any, source_value: str) -> str:
    text = str(value or "").strip()
    source = str(source_value or "").strip()
    if not text:
        return ""
    if not source:
        # Source field is empty: never accept generated filler/explanations.
        return ""
    if _is_dj_translation_hint_text(text):
        return ""
    return text


def _post_json_with_retry(url: str, body_text: str, timeout: int, retries: int, label: str, auth_token: str) -> str:
    payload = str(body_text or "").encode("utf-8")
    token = str(auth_token or "").strip()
    if not token:
        raise RuntimeError(f"{label} token is empty")
    attempts = max(1, int(retries or 1))
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "User-Agent": USER_AGENT,
    }
    last_err: Optional[str] = None

    timeout_sec: Optional[float] = None if int(timeout) <= 0 else float(timeout)

    for i in range(attempts):
        req = Request(url, data=payload, headers=headers, method="POST")
        try:
            if timeout_sec is None:
                with urlopen(req) as resp:
                    return resp.read().decode("utf-8", errors="replace")
            with urlopen(req, timeout=timeout_sec) as resp:
                return resp.read().decode("utf-8", errors="replace")
        except HTTPError as exc:
            detail = ""
            try:
                detail = exc.read().decode("utf-8", errors="replace")
            except Exception:  # noqa: BLE001
                detail = ""
            msg = detail.strip() or str(exc)
            last_err = f"{label} HTTP {exc.code}: {msg[:500]}"
            retryable_http_status = {408, 425, 429, 500, 502, 503, 504}
            if exc.code in retryable_http_status and i < attempts - 1:
                retry_after_sec = 0.0
                retry_after_header = ""
                try:
                    retry_after_header = str(exc.headers.get("Retry-After") or "").strip()
                except Exception:  # noqa: BLE001
                    retry_after_header = ""
                if retry_after_header:
                    try:
                        retry_after_sec = float(retry_after_header)
                    except Exception:  # noqa: BLE001
                        retry_after_sec = 0.0
                delay_sec = retry_after_sec if retry_after_sec > 0 else 1.2 * (i + 1)
                print(
                    f"[http-retry] {label} status={exc.code} attempt={i + 1}/{attempts} "
                    f"sleep={delay_sec:.1f}s",
                    flush=True,
                )
                time.sleep(delay_sec)
                continue
            raise RuntimeError(last_err) from exc
        except (TimeoutError, socket.timeout) as exc:
            timeout_text = f"{int(timeout_sec)}s" if timeout_sec is not None else "no-timeout"
            last_err = f"{label} timeout after {timeout_text} (attempt {i + 1}/{attempts})"
            if i < attempts - 1:
                delay_sec = 1.2 * (i + 1)
                print(
                    f"[http-retry] {label} timeout attempt={i + 1}/{attempts} sleep={delay_sec:.1f}s",
                    flush=True,
                )
                time.sleep(delay_sec)
                continue
            raise RuntimeError(last_err) from exc
        except URLError as exc:
            reason = str(getattr(exc, "reason", exc))
            last_err = f"{label} network error: {reason} (attempt {i + 1}/{attempts})"
            if i < attempts - 1:
                delay_sec = 1.2 * (i + 1)
                print(
                    f"[http-retry] {label} network_error attempt={i + 1}/{attempts} sleep={delay_sec:.1f}s reason={reason}",
                    flush=True,
                )
                time.sleep(delay_sec)
                continue
            raise RuntimeError(last_err) from exc

    raise RuntimeError(last_err or f"{label} request failed")


def _oss_enabled() -> bool:
    return bool(
        ALIYUN_OSS_ACCESS_KEY_ID
        and ALIYUN_OSS_ACCESS_KEY_SECRET
        and ALIYUN_OSS_BUCKET
        and ALIYUN_OSS_ENDPOINT
    )


def _normalize_oss_endpoint(endpoint: str, bucket: str) -> Dict[str, Any]:
    ep = str(endpoint or "").strip()
    ep = re.sub(r"^https?://", "", ep, flags=re.I).strip("/")
    if not ep:
        raise RuntimeError("ALIYUN_OSS_ENDPOINT is empty")
    has_bucket = ep.startswith(f"{bucket}.")
    host = ep if has_bucket else f"{bucket}.{ep}"
    return {"host": host, "has_bucket": has_bucket}


def _parse_data_url(data_url: str) -> Dict[str, Any]:
    src = str(data_url or "")
    m = re.match(r"^data:([^;,]+)?(;base64)?,(.*)$", src, flags=re.I | re.S)
    if not m:
        raise RuntimeError("invalid data URL")
    mime = (m.group(1) or "application/octet-stream").strip().lower()
    payload = m.group(3) or ""
    if m.group(2):
        try:
            content = base64.b64decode(payload, validate=False)
        except Exception as exc:  # noqa: BLE001
            raise RuntimeError(f"invalid base64 data URL: {exc}") from exc
    else:
        content = unquote_to_bytes(payload)
    return {"mime": mime, "bytes": content}


def _ext_from_mime(mime: str) -> str:
    mt = str(mime or "").strip().lower()
    if mt in ("image/jpeg", "image/jpg"):
        return "jpg"
    if mt == "image/png":
        return "png"
    if mt == "image/webp":
        return "webp"
    if mt == "image/gif":
        return "gif"
    if mt == "image/avif":
        return "avif"
    if mt == "image/bmp":
        return "bmp"
    if mt in ("image/tif", "image/tiff"):
        return "tiff"
    if mt == "image/svg+xml":
        return "svg"
    guessed = mimetypes.guess_extension(mt) or ".bin"
    return guessed.lstrip(".")


def _oss_sign(method: str, content_type: str, date_text: str, canonicalized_resource: str) -> str:
    string_to_sign = f"{method}\n\n{content_type}\n{date_text}\n{canonicalized_resource}"
    digest = hmac.new(
        ALIYUN_OSS_ACCESS_KEY_SECRET.encode("utf-8"),
        string_to_sign.encode("utf-8"),
        hashlib.sha1,
    ).digest()
    sig = base64.b64encode(digest).decode("utf-8")
    return f"OSS {ALIYUN_OSS_ACCESS_KEY_ID}:{sig}"


def _oss_put_object(key: str, content_type: str, data: bytes) -> str:
    bucket = ALIYUN_OSS_BUCKET
    endpoint_info = _normalize_oss_endpoint(ALIYUN_OSS_ENDPOINT, bucket)
    host = endpoint_info["host"]

    encoded_key = quote(key, safe="/-_.~")
    url = f"https://{host}/{encoded_key}"
    date_text = formatdate(timeval=None, localtime=False, usegmt=True)
    canonicalized_resource = f"/{bucket}/{key}"
    auth = _oss_sign("PUT", content_type, date_text, canonicalized_resource)
    req = Request(
        url,
        data=data,
        headers={
            "Date": date_text,
            "Content-Type": content_type,
            "Authorization": auth,
            "User-Agent": USER_AGENT,
        },
        method="PUT",
    )
    with urlopen(req, timeout=60) as resp:
        _ = resp.read()
    return url


def _oss_delete_object(key: str) -> None:
    bucket = ALIYUN_OSS_BUCKET
    endpoint_info = _normalize_oss_endpoint(ALIYUN_OSS_ENDPOINT, bucket)
    host = endpoint_info["host"]
    encoded_key = quote(key, safe="/-_.~")
    url = f"https://{host}/{encoded_key}"
    date_text = formatdate(timeval=None, localtime=False, usegmt=True)
    canonicalized_resource = f"/{bucket}/{key}"
    auth = _oss_sign("DELETE", "", date_text, canonicalized_resource)
    req = Request(
        url,
        headers={
            "Date": date_text,
            "Authorization": auth,
            "User-Agent": USER_AGENT,
        },
        method="DELETE",
    )
    with urlopen(req, timeout=30) as resp:
        _ = resp.read()


def _queue_oss_cleanup(key: str, delay_sec: int = 0) -> None:
    if not key:
        return
    due = time.time() + max(0, delay_sec)
    with OSS_CLEANUP_LOCK:
        OSS_CLEANUP_QUEUE.append({"key": key, "due": due})


def _run_due_oss_cleanup(limit: int = 64) -> int:
    now = time.time()
    due_items: List[Dict[str, Any]] = []
    with OSS_CLEANUP_LOCK:
        keep: List[Dict[str, Any]] = []
        for item in OSS_CLEANUP_QUEUE:
            if item.get("due", 0) <= now and len(due_items) < limit:
                due_items.append(item)
            else:
                keep.append(item)
        OSS_CLEANUP_QUEUE[:] = keep

    deleted = 0
    for item in due_items:
        key = str(item.get("key") or "").strip()
        if not key:
            continue
        try:
            _oss_delete_object(key)
            deleted += 1
        except Exception:  # noqa: BLE001
            # Requeue failed cleanup with backoff to avoid dropping orphan keys.
            _queue_oss_cleanup(key, delay_sec=300)
    return deleted


def _start_oss_cleanup_daemon(interval_sec: int = 60) -> None:
    global OSS_CLEANUP_DAEMON_STARTED
    if OSS_CLEANUP_DAEMON_STARTED:
        return
    OSS_CLEANUP_DAEMON_STARTED = True

    def _loop() -> None:
        while True:
            try:
                _run_due_oss_cleanup()
            except Exception:
                pass
            time.sleep(max(15, int(interval_sec)))

    t = threading.Thread(target=_loop, name="oss-cleanup-daemon", daemon=True)
    t.start()


def _build_temp_oss_key(purpose: str, mime: str) -> str:
    prefix = ALIYUN_OSS_PREFIX.strip()
    if prefix and not prefix.endswith("/"):
        prefix += "/"
    date_seg = datetime.now(timezone.utc).strftime("%Y%m%d")
    ext = _ext_from_mime(mime)
    uid = uuid4().hex
    return f"{prefix}{date_seg}/{purpose}-{uid}.{ext}"


def _prepare_coze_image_url(image_value: str, purpose: str) -> Dict[str, Optional[str]]:
    _run_due_oss_cleanup()
    src = str(image_value or "").strip()
    if not src:
        raise RuntimeError("image input is empty")
    if not src.startswith("data:"):
        return {"url": src, "cleanup_key": None}
    if not _oss_enabled():
        # Fallback to old behavior when OSS env is missing.
        return {"url": src, "cleanup_key": None}

    parsed = _parse_data_url(src)
    key = _build_temp_oss_key(purpose, parsed["mime"])
    public_url = _oss_put_object(key, parsed["mime"], parsed["bytes"])
    return {"url": public_url, "cleanup_key": key}


def run_coze_recognition(festival_image: str) -> Dict[str, Any]:
    token = str(COZE_TOKEN_TIMETABLE or COZE_TOKEN_LINEUP or COZE_TOKEN).strip()
    if not token:
        raise RuntimeError("missing Coze lineup token: set COZE_TOKEN_TIMETABLE (or fallback COZE_TOKEN)")
    started_at = time.time()
    prep = _prepare_coze_image_url(festival_image, "lineup")
    cleanup_key = prep.get("cleanup_key")
    img_url = str(prep.get("url") or festival_image)
    print(
        f"[coze-lineup] start timeout={COZE_LINEUP_TIMEOUT_SEC}s retries={COZE_LINEUP_RETRIES} "
        f"image_url_head={img_url[:120]!r}",
        flush=True,
    )
    try:
        image_obj: Dict[str, str] = {"url": img_url}
        body = json.dumps({"festival_image": image_obj}, ensure_ascii=False)
        raw = _post_json_with_retry(
            url=COZE_RUN_URL,
            body_text=body,
            timeout=COZE_LINEUP_TIMEOUT_SEC,
            retries=max(1, COZE_LINEUP_RETRIES),
            label="Coze lineup",
            auth_token=token,
        )
    finally:
        if cleanup_key:
            _queue_oss_cleanup(cleanup_key, delay_sec=max(60, ALIYUN_OSS_CLEANUP_DELAY_SEC))
    print(f"[coze-lineup] done in {time.time() - started_at:.2f}s", flush=True)
    try:
        data = json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"Coze response is not JSON: {exc}") from exc
    lineup_info = extract_lineup_info(data)
    return {"raw": data, "lineup_info": lineup_info}


def run_coze_poster_recognition(poster_image_url: str, file_type: str = "") -> Dict[str, Any]:
    token = str(COZE_TOKEN_LINEUP or COZE_TOKEN_TIMETABLE or COZE_TOKEN).strip()
    if not token:
        raise RuntimeError("missing Coze poster token: set COZE_TOKEN_LINEUP (or fallback COZE_TOKEN)")
    started_at = time.time()
    prep = _prepare_coze_image_url(poster_image_url, "poster")
    cleanup_key = prep.get("cleanup_key")
    img_url = str(prep.get("url") or poster_image_url)
    print(
        f"[coze-poster] start timeout={COZE_POSTER_TIMEOUT_SEC}s retries={COZE_POSTER_RETRIES} "
        f"image_url_head={img_url[:120]!r}",
        flush=True,
    )
    try:
        poster_obj: Dict[str, str] = {
            "url": img_url,
            "file_type": str(file_type or "").strip(),
        }
        body = json.dumps({"poster_image": poster_obj}, ensure_ascii=False)
        raw = _post_json_with_retry(
            url=COZE_POSTER_RUN_URL,
            body_text=body,
            timeout=COZE_POSTER_TIMEOUT_SEC,
            retries=max(1, COZE_POSTER_RETRIES),
            label="Coze poster",
            auth_token=token,
        )
    finally:
        if cleanup_key:
            _queue_oss_cleanup(cleanup_key, delay_sec=max(60, ALIYUN_OSS_CLEANUP_DELAY_SEC))
    print(f"[coze-poster] done in {time.time() - started_at:.2f}s", flush=True)
    try:
        data = json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"Coze poster response is not JSON: {exc}") from exc
    event_info = extract_event_info(data)
    return {"raw": data, "event_info": event_info}


def run_coze_translate_festival(festival_info: Dict[str, Any]) -> Dict[str, Any]:
    token = str(COZE_TOKEN_TRANSLATE or COZE_TOKEN_TIMETABLE or COZE_TOKEN_LINEUP or COZE_TOKEN).strip()
    if not token:
        raise RuntimeError("missing Coze translate token: set COZE_TOKEN_TRANSLATE (or fallback COZE_TOKEN)")
    if not COZE_TRANSLATE_RUN_URL:
        raise RuntimeError("missing Coze translate run url: set COZE_TRANSLATE_RUN_URL")
    body = json.dumps({"festival": festival_info}, ensure_ascii=False)
    raw = _post_json_with_retry(
        url=COZE_TRANSLATE_RUN_URL,
        body_text=body,
        timeout=COZE_TRANSLATE_TIMEOUT_SEC,
        retries=max(1, COZE_TRANSLATE_RETRIES),
        label="Coze translate",
        auth_token=token,
    )
    try:
        data = json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"Coze translate response is not JSON: {exc}") from exc
    translated = extract_translation_info(data)
    return {"raw": data, "translated": translated}


def _build_coze_location_normalize_input(
    location_payload: Dict[str, Any],
    context_payload: Optional[Dict[str, Any]] = None,
    raw_payload: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    location_input = location_payload if isinstance(location_payload, dict) else {}
    context_input = context_payload if isinstance(context_payload, dict) else {}
    raw_input = raw_payload if isinstance(raw_payload, dict) else {}

    editable_raw = raw_input.get("editable")
    editable_node = editable_raw if isinstance(editable_raw, dict) else {}
    if not editable_node:
        editable_node = {
            "nameI18n": location_input.get("nameI18n") or {},
            "addressI18n": location_input.get("addressI18n") or {},
            "formattedAddressI18n": location_input.get("formattedAddressI18n") or {},
            "city": location_input.get("city") or "",
            "district": location_input.get("district") or "",
            "province": location_input.get("province") or "",
            "countryCode": location_input.get("countryCode") or "",
        }

    locked_raw = raw_input.get("locked")
    locked_node = locked_raw if isinstance(locked_raw, dict) else {}
    if not locked_node:
        loc = location_input.get("location") if isinstance(location_input.get("location"), dict) else {}
        lng = loc.get("lng")
        if lng is None:
            lng = location_input.get("lng")
        if lng is None:
            lng = location_input.get("longitude")
        lat = loc.get("lat")
        if lat is None:
            lat = location_input.get("lat")
        if lat is None:
            lat = location_input.get("latitude")
        locked_node = {
            "provider": location_input.get("provider") or "",
            "sourceMode": location_input.get("sourceMode") or "",
            "lng": lng,
            "lat": lat,
            "providerPlaceId": location_input.get("providerPlaceId") or "",
        }

    hints_raw = raw_input.get("hints")
    hints_node = hints_raw if isinstance(hints_raw, dict) else {}
    if not hints_node:
        event_country = context_input.get("eventCountryI18n")
        if not isinstance(event_country, dict):
            event_country = context_input.get("countryI18n")
        if not isinstance(event_country, dict):
            event_country = {}
        hints_node = {
            "eventCountryI18n": _normalize_country_i18n(event_country or {}),
        }

    editable_out = {
        "nameI18n": _normalize_location_bi_text(editable_node.get("nameI18n") or {}),
        "addressI18n": _normalize_location_bi_text(editable_node.get("addressI18n") or {}),
        "formattedAddressI18n": _normalize_location_bi_text(editable_node.get("formattedAddressI18n") or {}),
        "city": str(editable_node.get("city") or "").strip(),
        "district": str(editable_node.get("district") or "").strip(),
        "province": str(editable_node.get("province") or "").strip(),
        "countryCode": str(editable_node.get("countryCode") or "").strip().upper(),
    }
    locked_out = {
        "provider": str(locked_node.get("provider") or "").strip(),
        "sourceMode": str(locked_node.get("sourceMode") or "").strip(),
        "lng": _location_parse_float(locked_node.get("lng")),
        "lat": _location_parse_float(locked_node.get("lat")),
        "providerPlaceId": str(locked_node.get("providerPlaceId") or "").strip(),
    }
    event_country_out = hints_node.get("eventCountryI18n")
    if not isinstance(event_country_out, dict):
        event_country_out = {}
    hints_out = {
        "eventCountryI18n": _normalize_country_i18n(event_country_out or {}),
    }

    return {
        "editable": editable_out,
        "locked": locked_out,
        "hints": hints_out,
    }


def run_coze_normalize_event_location(
    location_payload: Dict[str, Any],
    context_payload: Optional[Dict[str, Any]] = None,
    raw_payload: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    token = str(
        COZE_TOKEN_LOCATION_NORMALIZE
        or COZE_TOKEN_TRANSLATE
        or COZE_TOKEN_TIMETABLE
        or COZE_TOKEN_LINEUP
        or COZE_TOKEN
    ).strip()
    if not token:
        raise RuntimeError(
            "missing Coze location normalize token: set COZE_TOKEN_LOCATION_NORMALIZE (or fallback token)"
        )
    if not COZE_LOCATION_NORMALIZE_RUN_URL:
        raise RuntimeError("missing Coze location normalize run url: set COZE_LOCATION_NORMALIZE_RUN_URL")

    coze_payload = _build_coze_location_normalize_input(
        location_payload=location_payload,
        context_payload=context_payload,
        raw_payload=raw_payload,
    )
    body = json.dumps(coze_payload, ensure_ascii=False)
    raw = _post_json_with_retry(
        url=COZE_LOCATION_NORMALIZE_RUN_URL,
        body_text=body,
        timeout=COZE_LOCATION_NORMALIZE_TIMEOUT_SEC,
        retries=max(1, COZE_LOCATION_NORMALIZE_RETRIES),
        label="Coze location normalize",
        auth_token=token,
    )
    try:
        data = json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"Coze location normalize response is not JSON: {exc}") from exc
    normalized = extract_location_normalization_info(data)
    issues = extract_location_normalization_issues(data)
    return {"raw": data, "normalized": normalized, "issues": issues}


def run_coze_translate_dj_fields(fields: Dict[str, Any]) -> Dict[str, Any]:
    token = str(COZE_TOKEN_DJ_TRANS or COZE_TOKEN_TRANSLATE or COZE_TOKEN_TIMETABLE or COZE_TOKEN_LINEUP or COZE_TOKEN).strip()
    if not token:
        raise RuntimeError("missing Coze dj translate token: set COZE_TOKEN_DJ_TRANS (or fallback token)")
    if not COZE_DJ_TRANS_RUN_URL:
        raise RuntimeError("missing Coze dj translate run url: set COZE_DJ_TRANS_RUN_URL")

    payload_fields_raw = fields if isinstance(fields, dict) else {}
    payload_fields = {
        "country": str(payload_fields_raw.get("country") or "").strip(),
        "bio": str(payload_fields_raw.get("bio") or "").strip(),
    }
    body = json.dumps(
        {
            "fields": payload_fields,
            "instruction": "如果 country 或 bio 为空，请在 fields_cn/fields_en 对应字段返回空字符串，不要返回解释文本。",
        },
        ensure_ascii=False,
    )
    raw = _post_json_with_retry(
        url=COZE_DJ_TRANS_RUN_URL,
        body_text=body,
        timeout=COZE_DJ_TRANS_TIMEOUT_SEC,
        retries=max(1, COZE_DJ_TRANS_RETRIES),
        label="Coze DJ translate",
        auth_token=token,
    )
    try:
        data = json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"Coze DJ translate response is not JSON: {exc}") from exc
    translated = extract_dj_translation_info(data)
    return {"raw": data, "translated": translated}


def _raver_json_request(
    method: str,
    upstream_path: str,
    payload: Optional[Dict[str, Any]] = None,
    auth_header: str = "",
) -> Dict[str, Any]:
    upstream_url = f"{RAVER_BFF_BASE}{upstream_path}"
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }
    auth = (auth_header or "").strip()
    if auth:
        headers["Authorization"] = auth

    req_data: Optional[bytes] = None
    if payload is not None:
        headers["Content-Type"] = "application/json; charset=utf-8"
        req_data = json.dumps(payload, ensure_ascii=False).encode("utf-8")

    req = Request(upstream_url, data=req_data, headers=headers, method=method.upper())
    try:
        with urlopen(req, timeout=50) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
        if not raw.strip():
            return {}
        parsed = json.loads(raw)
        if not isinstance(parsed, dict):
            raise RuntimeError("upstream response is not a JSON object")
        return parsed
    except HTTPError as exc:
        detail = ""
        try:
            detail = exc.read().decode("utf-8", errors="replace")
        except Exception:  # noqa: BLE001
            detail = ""
        message = detail.strip() or str(exc.reason or exc)
        raise RuntimeError(
            f"upstream {method.upper()} {upstream_path} failed with status {exc.code}: {message[:400]}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"upstream {method.upper()} {upstream_path} returned invalid JSON: {exc}") from exc
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"upstream {method.upper()} {upstream_path} failed: {exc}") from exc


def _safe_relative_path_under_root(relative_path: str, root_dir: Path) -> Path:
    rel = str(relative_path or "").strip().replace("\\", "/").strip("/")
    if not rel:
        raise RuntimeError("relative_path is required")
    if ".." in rel.split("/"):
        raise RuntimeError("invalid relative_path")
    target = (root_dir / rel).resolve()
    root = str(root_dir)
    t = str(target)
    if not (t == root or t.startswith(root + os.sep)):
        raise RuntimeError("path escapes allowed root")
    return target


def open_folder_in_os(relative_path: str, scope: str = "brands") -> Dict[str, str]:
    normalized_scope = str(scope or "brands").strip().lower()
    if normalized_scope == "brands":
        target = _safe_relative_path_under_root(relative_path, BRANDS_ROOT)
    elif normalized_scope == "project":
        target = _safe_relative_path_under_root(relative_path, PROJECT_ROOT)
    else:
        raise RuntimeError("invalid scope, expected brands/project")
    if not target.exists() or not target.is_dir():
        raise RuntimeError(f"folder not found: {target}")

    if sys.platform == "darwin":
        cmd = ["open", str(target)]
        subprocess.Popen(cmd)  # noqa: S603
    elif os.name == "nt":
        os.startfile(str(target))  # type: ignore[attr-defined]
        cmd = ["startfile", str(target)]
    else:
        cmd = ["xdg-open", str(target)]
        subprocess.Popen(cmd)  # noqa: S603

    return {"opened_path": str(target), "command": " ".join(cmd), "scope": normalized_scope}


def parse_timetable_detail_page(html: str, url: str) -> Dict:
    out: Dict = {
        "url": url,
        "event_title": None,
        "timetable_name": None,
        "date_text": None,
        "stages": [],
    }

    event_title_m = re.search(r'<h2\s+class="action-header__title[^\"]*">(.*?)</h2>', html, flags=re.S)
    if event_title_m:
        out["event_title"] = strip_tags(event_title_m.group(1))

    name_m = re.search(r'<div\s+class="action-header__subtitle-center">(.*?)</div>', html, flags=re.S)
    if name_m:
        center = name_m.group(1)
        h3_m = re.search(r"<h3>(.*?)</h3>", center, flags=re.S)
        date_m = re.search(r'<span\s+class="tag">([^<]+)</span>', center)
        out["timetable_name"] = strip_tags(h3_m.group(1)) if h3_m else None
        out["date_text"] = strip_tags(date_m.group(1)) if date_m else None

    stage_blocks = find_div_blocks_by_class(html, "action-subarea action-subarea--bystage")
    for block in stage_blocks:
        stage_name = None
        stage_m = re.search(
            r'<h4[^>]*action-subarea__title[^>]*>\s*(?:<a[^>]*>)?(.*?)(?:</a>)?\s*</h4>',
            block,
            flags=re.S,
        )
        if stage_m:
            stage_name = strip_tags(stage_m.group(1))

        sets = []
        for a_html in find_anchor_blocks(block):
            attrs = parse_attrs(anchor_open_tag(a_html))
            if "bystage-list__item" not in attrs.get("class", ""):
                continue

            dt_vals = re.findall(r'<time\s+class="datetime\s+datetime--(?:start|end)"\s+datetime="([^"]+)"', a_html)
            time_vals = re.findall(r'<span\s+class="datetime__time">([^<]+)</span>', a_html)
            artist_m = re.search(r'<span\s+class="show-title__name">(.*?)</span>', a_html, flags=re.S)
            badge_m = re.search(r'<span\s+class="badge\s+badge--secondary">([^<]+)</span>', a_html)
            img_m = re.search(r'<img\s+src="([^"]+)"\s+alt="([^"]*)"', a_html)

            sets.append(
                {
                    "start_datetime": dt_vals[0] if len(dt_vals) > 0 else None,
                    "end_datetime": dt_vals[1] if len(dt_vals) > 1 else None,
                    "start_time": strip_tags(time_vals[0]) if len(time_vals) > 0 else None,
                    "end_time": strip_tags(time_vals[1]) if len(time_vals) > 1 else None,
                    "artist": strip_tags(artist_m.group(1)) if artist_m else None,
                    "extra_artist_count": strip_tags(badge_m.group(1)) if badge_m else None,
                    "artist_image_url": urljoin(BASE_URL, img_m.group(1)) if img_m else None,
                }
            )

        out["stages"].append({"stage_name": stage_name, "sets": sets})

    return out


def scrape_one_event(event_url: str, progress_hook=None, skip_festival_ids=None) -> Dict:
    html = fetch_text(event_url).text
    event = parse_event_page(html, event_url)
    festival_id = build_festival_id_from_event(event)
    if festival_id:
        event["festival_id"] = festival_id

    skip_set = skip_festival_ids or set()
    if festival_id and festival_id in skip_set:
        event["skipped"] = True
        event["skip_reason"] = "duplicate_slug"
        event["timetable_details"] = []
        if progress_hook:
            progress_hook(
                "event_skipped",
                total_timetables=0,
                completed_timetables=0,
                message=f"slug 重复，已跳过 timetable 抓取：{festival_id}",
            )
        return event

    details: List[Dict] = []
    timetables = event.get("timetable", [])
    total_tt = len(timetables)
    if progress_hook:
        progress_hook("event_parsed", total_timetables=total_tt, completed_timetables=0, message="活动页已解析")

    for idx, t in enumerate(timetables, start=1):
        t_url = t.get("url")
        if not t_url:
            continue
        try:
            if progress_hook:
                progress_hook(
                    "timetable_running",
                    total_timetables=total_tt,
                    completed_timetables=idx - 1,
                    message=f"正在抓取 timetable {idx}/{total_tt}",
                )
            d_html = fetch_text(t_url).text
            details.append(parse_timetable_detail_page(d_html, t_url))
            time.sleep(0.15)
            if progress_hook:
                progress_hook(
                    "timetable_done",
                    total_timetables=total_tt,
                    completed_timetables=idx,
                    message=f"已完成 timetable {idx}/{total_tt}",
                )
        except Exception as exc:  # noqa: BLE001
            details.append({"url": t_url, "error": str(exc)})
            if progress_hook:
                progress_hook(
                    "timetable_error",
                    total_timetables=total_tt,
                    completed_timetables=idx,
                    message=f"timetable 抓取异常：{exc}",
                )
    event["timetable_details"] = details
    if progress_hook:
        progress_hook(
            "event_done",
            total_timetables=total_tt,
            completed_timetables=total_tt,
            message="活动抓取完成",
        )
    return event


def _set_job_progress(job_id: str, updater):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if not job:
            return
        updater(job)


def _run_scrape_job(job_id: str, event_urls: List[str], skip_festival_ids=None):
    try:
        started = time.time()
        events_result: List[Dict] = []
        skipped_result: List[Dict] = []
        errors: List[Dict] = []
        skip_set = {str(x).strip() for x in (skip_festival_ids or []) if str(x).strip()}

        def update_status_running(job):
            job["progress"]["status"] = "running"

        _set_job_progress(job_id, update_status_running)

        for idx, event_url in enumerate(event_urls):
            parsed = urlparse(event_url)
            slug = parsed.path.rstrip("/").split("/")[-1]

            def mark_event_running(job):
                p = job["progress"]
                p["current_event_index"] = idx
                e = p["events"][idx]
                e["slug"] = slug
                e["status"] = "running"
                e["message"] = "正在抓取活动页"

            _set_job_progress(job_id, mark_event_running)

            def hook(_phase, total_timetables=0, completed_timetables=0, message=""):
                def _update(job):
                    e = job["progress"]["events"][idx]
                    e["total_timetables"] = total_timetables
                    e["completed_timetables"] = completed_timetables
                    if message:
                        e["message"] = message

                _set_job_progress(job_id, _update)

            try:
                event_data = scrape_one_event(event_url, progress_hook=hook, skip_festival_ids=skip_set)
                if event_data.get("skipped"):
                    skipped_result.append(
                        {
                            "event_url": event_url,
                            "title": event_data.get("title"),
                            "festival_id": event_data.get("festival_id"),
                            "reason": event_data.get("skip_reason") or "duplicate_slug",
                        }
                    )

                    def mark_event_skipped(job):
                        p = job["progress"]
                        e = p["events"][idx]
                        e["title"] = event_data.get("title")
                        e["status"] = "skipped"
                        e["message"] = f"slug 重复，已跳过：{event_data.get('festival_id') or '-'}"
                        p["completed_events"] += 1
                        p["skipped_events"] = int(p.get("skipped_events", 0)) + 1

                    _set_job_progress(job_id, mark_event_skipped)
                    continue
                events_result.append(event_data)

                def mark_event_done(job):
                    p = job["progress"]
                    e = p["events"][idx]
                    e["title"] = event_data.get("title")
                    e["status"] = "done"
                    e["message"] = "活动抓取完成"
                    p["completed_events"] += 1
                    p.setdefault("completed_event_results", []).append(event_data)

                _set_job_progress(job_id, mark_event_done)
            except Exception as exc:  # noqa: BLE001
                errors.append({"url": event_url, "error": str(exc)})

                def mark_event_error(job):
                    p = job["progress"]
                    e = p["events"][idx]
                    e["status"] = "error"
                    e["message"] = f"活动抓取失败：{exc}"
                    p["completed_events"] += 1

                _set_job_progress(job_id, mark_event_error)

        elapsed_ms = int((time.time() - started) * 1000)
        result = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "count": len(events_result),
            "skipped_count": len(skipped_result),
            "skipped": skipped_result,
            "errors": errors,
            "elapsed_ms": elapsed_ms,
            "events": events_result,
        }

        def mark_done(job):
            job["status"] = "completed"
            job["result"] = result
            job["progress"]["status"] = "completed"

        _set_job_progress(job_id, mark_done)
    except Exception as exc:  # noqa: BLE001
        def mark_failed(job):
            job["status"] = "failed"
            job["progress"]["status"] = "failed"
            job["progress"]["fatal_error"] = str(exc)

        _set_job_progress(job_id, mark_failed)


def _dj_translate_job_stop_requested(job_id: str) -> bool:
    with JOBS_LOCK:
        job = JOBS.get(job_id) or {}
        progress = job.get("progress") or {}
        return bool(progress.get("stop_requested"))


def _run_dj_translate_job(job_id: str, dj_ids: List[str], auth_header: str) -> None:
    started = time.time()
    rows: List[Dict[str, Any]] = []
    processed = 0
    updated = 0
    failed = 0
    skipped = 0
    stopped = False

    try:
        for index, dj_id in enumerate(dj_ids, start=1):
            if _dj_translate_job_stop_requested(job_id):
                stopped = True
                break

            dj_id_clean = str(dj_id or "").strip()
            row_result: Dict[str, Any] = {
                "djId": dj_id_clean,
                "index": index,
                "status": "pending",
                "djName": "",
            }

            def _mark_running(job):
                p = job.get("progress") or {}
                p["current_index"] = index
                p["current_dj_id"] = dj_id_clean
                p["message"] = f"处理中 {index}/{len(dj_ids)}"

            _set_job_progress(job_id, _mark_running)

            try:
                encoded_id = quote(dj_id_clean, safe="")
                detail_resp = _raver_json_request(
                    method="GET",
                    upstream_path=f"/v1/djs/{encoded_id}",
                    auth_header=auth_header,
                )
                dj_data = detail_resp.get("data") if isinstance(detail_resp, dict) else None
                if not isinstance(dj_data, dict):
                    raise RuntimeError("DJ detail response missing data")

                source_country = str(dj_data.get("country") or "").strip()
                source_bio = str(dj_data.get("bio") or "").strip()
                row_result["djName"] = str(dj_data.get("name") or "").strip()

                if not source_country and not source_bio:
                    row_result["status"] = "skipped"
                    row_result["reason"] = "country and bio are both empty"
                    skipped += 1
                else:
                    translated_out = run_coze_translate_dj_fields(
                        {
                            "country": source_country,
                            "bio": source_bio,
                        }
                    )
                    translated = translated_out.get("translated") if isinstance(translated_out, dict) else {}
                    fields_cn = translated.get("fields_cn") if isinstance(translated, dict) else {}
                    fields_en = translated.get("fields_en") if isinstance(translated, dict) else {}

                    def _read_lang_value(group: Any, key: str) -> str:
                        if not isinstance(group, dict):
                            return ""
                        return str(group.get(key) or "").strip()

                    next_country_zh = _clean_dj_translation_text(_read_lang_value(fields_cn, "country"), source_country)
                    next_country_en = _clean_dj_translation_text(_read_lang_value(fields_en, "country"), source_country)
                    next_bio_zh = _clean_dj_translation_text(_read_lang_value(fields_cn, "bio"), source_bio)
                    next_bio_en = _clean_dj_translation_text(_read_lang_value(fields_en, "bio"), source_bio)

                    existing_country_i18n = (
                        dj_data.get("countryI18n") if isinstance(dj_data.get("countryI18n"), dict) else {}
                    )
                    existing_bio_i18n = (
                        dj_data.get("bioI18n") if isinstance(dj_data.get("bioI18n"), dict) else {}
                    )

                    if source_country:
                        if not next_country_en:
                            next_country_en = str(existing_country_i18n.get("en") or "").strip() or source_country
                        if not next_country_zh:
                            next_country_zh = str(existing_country_i18n.get("zh") or "").strip()
                    else:
                        next_country_en = ""
                        next_country_zh = ""

                    if source_bio:
                        if not next_bio_en:
                            next_bio_en = str(existing_bio_i18n.get("en") or "").strip() or source_bio
                        if not next_bio_zh:
                            next_bio_zh = str(existing_bio_i18n.get("zh") or "").strip()
                    else:
                        next_bio_en = ""
                        next_bio_zh = ""

                    update_payload: Dict[str, Any] = {}
                    if source_country and (next_country_en or next_country_zh):
                        update_payload["countryI18n"] = _normalize_country_i18n(
                            {
                                "en": next_country_en,
                                "zh": next_country_zh,
                                "enFull": str(existing_country_i18n.get("enFull") or "").strip(),
                            },
                            source_country,
                        )
                    if source_bio and (next_bio_en or next_bio_zh):
                        update_payload["bioI18n"] = {
                            "en": next_bio_en,
                            "zh": next_bio_zh,
                        }

                    if not update_payload:
                        row_result["status"] = "skipped"
                        row_result["reason"] = "no valid bilingual fields generated"
                        skipped += 1
                    else:
                        _raver_json_request(
                            method="PATCH",
                            upstream_path=f"/v1/djs/{encoded_id}",
                            payload=update_payload,
                            auth_header=auth_header,
                        )
                        row_result["status"] = "updated"
                        row_result["countryUpdated"] = "countryI18n" in update_payload
                        row_result["bioUpdated"] = "bioI18n" in update_payload
                        updated += 1
            except Exception as exc:  # noqa: BLE001
                row_result["status"] = "error"
                row_result["reason"] = str(exc)
                failed += 1

            processed += 1
            rows.append(row_result)

            def _mark_processed(job):
                p = job.get("progress") or {}
                p["processed"] = processed
                p["updated"] = updated
                p["failed"] = failed
                p["skipped"] = skipped
                p["current_dj_id"] = row_result.get("djId", "")
                p["current_dj_name"] = row_result.get("djName", "")
                p["message"] = (
                    f"{processed}/{len(dj_ids)} | updated={updated} failed={failed} skipped={skipped}"
                )
                p.setdefault("completed_rows", []).append(row_result)

            _set_job_progress(job_id, _mark_processed)

        elapsed_ms = int((time.time() - started) * 1000)
        result = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "total": len(dj_ids),
            "processed": processed,
            "success": updated,
            "failed": failed,
            "skipped": skipped,
            "stopped": stopped,
            "elapsed_ms": elapsed_ms,
            "rows": rows,
        }

        def _mark_done(job):
            job["status"] = "stopped" if stopped else "completed"
            job["result"] = result
            p = job.get("progress") or {}
            p["status"] = "stopped" if stopped else "completed"
            p["processed"] = processed
            p["updated"] = updated
            p["failed"] = failed
            p["skipped"] = skipped
            p["message"] = (
                f"已停止：{processed}/{len(dj_ids)}"
                if stopped
                else f"已完成：{processed}/{len(dj_ids)}"
            )

        _set_job_progress(job_id, _mark_done)
    except Exception as exc:  # noqa: BLE001
        elapsed_ms = int((time.time() - started) * 1000)
        result = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "total": len(dj_ids),
            "processed": processed,
            "success": updated,
            "failed": failed,
            "skipped": skipped,
            "stopped": stopped,
            "elapsed_ms": elapsed_ms,
            "rows": rows,
            "fatal_error": str(exc),
        }

        def _mark_failed(job):
            job["status"] = "failed"
            job["result"] = result
            p = job.get("progress") or {}
            p["status"] = "failed"
            p["fatal_error"] = str(exc)
            p["processed"] = processed
            p["updated"] = updated
            p["failed"] = failed
            p["skipped"] = skipped
            p["message"] = f"任务异常终止：{exc}"

        _set_job_progress(job_id, _mark_failed)


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, payload: Dict):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_file(self, file_path: Path, content_type: str):
        if not file_path.exists() or not file_path.is_file():
            self.send_error(404, "Not Found")
            return
        data = file_path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_raw(self, status: int, body: bytes, content_type: str = "application/octet-stream"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_project_static(self, rel_path: str):
        normalized = str(rel_path or "").lstrip("/")
        if not normalized:
            self.send_error(404, "Not Found")
            return
        target = (PROJECT_ROOT / normalized).resolve()
        try:
            target.relative_to(PROJECT_ROOT.resolve())
        except Exception:
            self.send_error(403, "Forbidden")
            return
        guessed, _ = mimetypes.guess_type(str(target))
        content_type = guessed or "application/octet-stream"
        if content_type.startswith("text/") and "charset=" not in content_type:
            content_type = f"{content_type}; charset=utf-8"
        if content_type == "application/javascript":
            content_type = "application/javascript; charset=utf-8"
        self._send_file(target, content_type)

    def _proxy_raver_get(self, upstream_path: str, raw_query: str, auth_header: str = ""):
        upstream_url = f"{RAVER_BFF_BASE}{upstream_path}"
        if raw_query:
            upstream_url = f"{upstream_url}?{raw_query}"
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
        }
        auth = (auth_header or "").strip()
        if auth:
            headers["Authorization"] = auth
        try:
            req = Request(
                upstream_url,
                headers=headers,
            )
            with urlopen(req, timeout=40) as resp:
                data = resp.read()
                ctype = resp.headers.get("Content-Type", "application/json; charset=utf-8")
                self._send_raw(resp.status, data, ctype)
        except HTTPError as exc:
            err_data = exc.read()
            err_ctype = (
                exc.headers.get("Content-Type", "application/json; charset=utf-8")
                if exc.headers
                else "application/json; charset=utf-8"
            )
            if err_data:
                self._send_raw(exc.code, err_data, err_ctype)
                return
            self._send_json(exc.code, {"error": f"upstream request failed: {exc.reason}"})
        except Exception as exc:  # noqa: BLE001
            self._send_json(502, {"error": f"raver proxy failed: {exc}"})

    def _send_raver_event_years(self, auth_header: str = ""):
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
        }
        auth = (auth_header or "").strip()
        if auth:
            headers["Authorization"] = auth
        try:
            req = Request(f"{RAVER_BFF_BASE}/v1/events/years", headers=headers)
            with urlopen(req, timeout=40) as resp:
                data = resp.read()
                ctype = resp.headers.get("Content-Type", "application/json; charset=utf-8")
                self._send_raw(resp.status, data, ctype)
                return
        except HTTPError as exc:
            if exc.code != 404:
                err_data = exc.read()
                err_ctype = (
                    exc.headers.get("Content-Type", "application/json; charset=utf-8")
                    if exc.headers
                    else "application/json; charset=utf-8"
                )
                if err_data:
                    self._send_raw(exc.code, err_data, err_ctype)
                    return
                self._send_json(exc.code, {"error": f"upstream request failed: {exc.reason}"})
                return
        except Exception as exc:  # noqa: BLE001
            self._send_json(502, {"error": f"raver event years proxy failed: {exc}"})
            return

        # Compatibility fallback for a backend process that has not yet been
        # restarted with /v1/events/years. Only reads paged event dates and
        # returns compact year metadata to keep the viewer unblocked.
        page = 1
        total_pages = 1
        counts: Dict[int, int] = {}
        try:
            while page <= total_pages and page <= 500:
                query = urlencode({"page": page, "limit": 100, "status": "all"})
                req = Request(f"{RAVER_BFF_BASE}/v1/events?{query}", headers=headers)
                with urlopen(req, timeout=40) as resp:
                    payload = json.loads(resp.read().decode("utf-8") or "{}")
                items = payload.get("data", {}).get("items")
                if not isinstance(items, list):
                    items = payload.get("events") if isinstance(payload.get("events"), list) else []
                for item in items:
                    raw_date = str((item or {}).get("startDate") or "")
                    match = re.match(r"^(\d{4})", raw_date)
                    if not match:
                        continue
                    year = int(match.group(1))
                    counts[year] = counts.get(year, 0) + 1
                pagination = payload.get("pagination") if isinstance(payload.get("pagination"), dict) else {}
                total_pages = int(pagination.get("totalPages") or total_pages or 1)
                page += 1
            years = [
                {"year": year, "count": count}
                for year, count in sorted(counts.items(), key=lambda item: item[0], reverse=True)
            ]
            self._send_json(200, {"years": years})
        except Exception as exc:  # noqa: BLE001
            self._send_json(502, {"error": f"raver event years fallback failed: {exc}"})

    def _proxy_raver_patch(self, upstream_path: str, payload: Dict[str, Any], auth_header: str = ""):
        upstream_url = f"{RAVER_BFF_BASE}{upstream_path}"
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
            "Content-Type": "application/json; charset=utf-8",
        }
        auth = (auth_header or "").strip()
        if auth:
            headers["Authorization"] = auth
        data = json.dumps(payload or {}, ensure_ascii=False).encode("utf-8")
        try:
            req = Request(upstream_url, data=data, headers=headers, method="PATCH")
            with urlopen(req, timeout=40) as resp:
                body = resp.read()
                ctype = resp.headers.get("Content-Type", "application/json; charset=utf-8")
                self._send_raw(resp.status, body, ctype)
        except HTTPError as exc:
            err_data = exc.read()
            err_ctype = (
                exc.headers.get("Content-Type", "application/json; charset=utf-8")
                if exc.headers
                else "application/json; charset=utf-8"
            )
            if err_data:
                self._send_raw(exc.code, err_data, err_ctype)
                return
            self._send_json(exc.code, {"error": f"upstream request failed: {exc.reason}"})
        except Exception as exc:  # noqa: BLE001
            self._send_json(502, {"error": f"raver patch proxy failed: {exc}"})

    def _proxy_raver_post(self, upstream_path: str, payload: Dict[str, Any], auth_header: str = ""):
        upstream_url = f"{RAVER_BFF_BASE}{upstream_path}"
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
            "Content-Type": "application/json; charset=utf-8",
        }
        auth = (auth_header or "").strip()
        if auth:
            headers["Authorization"] = auth
        data = json.dumps(payload or {}, ensure_ascii=False).encode("utf-8")
        try:
            req = Request(upstream_url, data=data, headers=headers, method="POST")
            with urlopen(req, timeout=40) as resp:
                body = resp.read()
                ctype = resp.headers.get("Content-Type", "application/json; charset=utf-8")
                self._send_raw(resp.status, body, ctype)
        except HTTPError as exc:
            err_data = exc.read()
            err_ctype = (
                exc.headers.get("Content-Type", "application/json; charset=utf-8")
                if exc.headers
                else "application/json; charset=utf-8"
            )
            if err_data:
                self._send_raw(exc.code, err_data, err_ctype)
                return
            self._send_json(exc.code, {"error": f"upstream request failed: {exc.reason}"})
        except Exception as exc:  # noqa: BLE001
            self._send_json(502, {"error": f"raver post proxy failed: {exc}"})

    def _proxy_raver_post_raw(
        self,
        upstream_path: str,
        raw_body: bytes,
        content_type: str,
        auth_header: str = "",
    ):
        upstream_url = f"{RAVER_BFF_BASE}{upstream_path}"
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
            "Content-Type": content_type or "application/octet-stream",
        }
        auth = (auth_header or "").strip()
        if auth:
            headers["Authorization"] = auth
        try:
            req = Request(upstream_url, data=raw_body, headers=headers, method="POST")
            with urlopen(req, timeout=60) as resp:
                body = resp.read()
                ctype = resp.headers.get("Content-Type", "application/json; charset=utf-8")
                self._send_raw(resp.status, body, ctype)
        except HTTPError as exc:
            err_data = exc.read()
            err_ctype = (
                exc.headers.get("Content-Type", "application/json; charset=utf-8")
                if exc.headers
                else "application/json; charset=utf-8"
            )
            if err_data:
                self._send_raw(exc.code, err_data, err_ctype)
                return
            self._send_json(exc.code, {"error": f"upstream request failed: {exc.reason}"})
        except Exception as exc:  # noqa: BLE001
            self._send_json(502, {"error": f"raver raw post proxy failed: {exc}"})

    def _proxy_raver_delete(self, upstream_path: str, auth_header: str = ""):
        upstream_url = f"{RAVER_BFF_BASE}{upstream_path}"
        headers = {
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
        }
        auth = (auth_header or "").strip()
        if auth:
            headers["Authorization"] = auth
        try:
            req = Request(upstream_url, headers=headers, method="DELETE")
            with urlopen(req, timeout=40) as resp:
                body = resp.read()
                ctype = resp.headers.get("Content-Type", "application/json; charset=utf-8")
                self._send_raw(resp.status, body, ctype)
        except HTTPError as exc:
            err_data = exc.read()
            err_ctype = (
                exc.headers.get("Content-Type", "application/json; charset=utf-8")
                if exc.headers
                else "application/json; charset=utf-8"
            )
            if err_data:
                self._send_raw(exc.code, err_data, err_ctype)
                return
            self._send_json(exc.code, {"error": f"upstream request failed: {exc.reason}"})
        except Exception as exc:  # noqa: BLE001
            self._send_json(502, {"error": f"raver delete proxy failed: {exc}"})

    def _raver_json_request(
        self,
        method: str,
        upstream_path: str,
        payload: Optional[Dict[str, Any]] = None,
        auth_header: str = "",
    ) -> Dict[str, Any]:
        return _raver_json_request(
            method=method,
            upstream_path=upstream_path,
            payload=payload,
            auth_header=auth_header,
        )

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/festival-viewer.html":
            self._send_project_static("festival-viewer.html")
            return
        if path == "/country-codes-iso3166.js":
            self._send_project_static("country-codes-iso3166.js")
            return
        if path.startswith("/festival-viewer/"):
            self._send_project_static(path)
            return
        if path in ("/", "/index.html"):
            self._send_project_static("festival-viewer.html")
            return
        if path == "/dj-library.html":
            self._send_file(WEB_DIR / "dj-library.html", "text/html; charset=utf-8")
            return
        if path == "/app.js":
            self._send_file(WEB_DIR / "app.js", "application/javascript; charset=utf-8")
            return
        if path == "/dj-library.js":
            self._send_file(WEB_DIR / "dj-library.js", "application/javascript; charset=utf-8")
            return
        if path == "/styles.css":
            self._send_file(WEB_DIR / "styles.css", "text/css; charset=utf-8")
            return
        if path == "/api/raver/djs":
            self._proxy_raver_get("/v1/djs", parsed.query)
            return
        if path == "/api/raver/events":
            self._proxy_raver_get(
                "/v1/events",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/events/years":
            self._send_raver_event_years(self.headers.get("Authorization", ""))
            return
        if path == "/api/raver/events/my":
            self._proxy_raver_get(
                "/v1/events/my",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/feed":
            self._proxy_raver_get(
                "/v1/feed",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/feed/search":
            self._proxy_raver_get(
                "/v1/feed/search",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/admin/v1/content-submissions":
            self._proxy_raver_get(
                "/api/admin/v1/content-submissions",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/admin/v1/dj-enrichment/results":
            self._proxy_raver_get(
                "/api/admin/v1/dj-enrichment/results",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        content_submission_detail_m = re.match(r"^/api/admin/v1/content-submissions/([^/]+)$", path)
        if content_submission_detail_m:
            submission_id = quote(unquote_to_bytes(content_submission_detail_m.group(1)))
            self._proxy_raver_get(
                f"/api/admin/v1/content-submissions/{submission_id}",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        dj_enrichment_detail_m = re.match(r"^/api/admin/v1/dj-enrichment/results/([^/]+)$", path)
        if dj_enrichment_detail_m:
            result_id = quote(unquote_to_bytes(dj_enrichment_detail_m.group(1)))
            self._proxy_raver_get(
                f"/api/admin/v1/dj-enrichment/results/{result_id}",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/djs/spotify/search":
            self._proxy_raver_get(
                "/v1/djs/spotify/search",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/djs/discogs/search":
            self._proxy_raver_get(
                "/v1/djs/discogs/search",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/djs/soundcloud/search":
            self._proxy_raver_get(
                "/v1/djs/soundcloud/search",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        discogs_artist_m = re.match(r"^/api/raver/djs/discogs/artists/([^/]+)$", path)
        if discogs_artist_m:
            artist_id = quote(discogs_artist_m.group(1), safe="")
            self._proxy_raver_get(
                f"/v1/djs/discogs/artists/{artist_id}",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        dj_sets_m = re.match(r"^/api/raver/djs/([^/]+)/sets$", path)
        if dj_sets_m:
            dj_id = quote(dj_sets_m.group(1), safe="")
            self._proxy_raver_get(f"/v1/djs/{dj_id}/sets", parsed.query)
            return
        dj_events_m = re.match(r"^/api/raver/djs/([^/]+)/events$", path)
        if dj_events_m:
            dj_id = quote(dj_events_m.group(1), safe="")
            self._proxy_raver_get(f"/v1/djs/{dj_id}/events", parsed.query)
            return
        dj_detail_m = re.match(r"^/api/raver/djs/([^/]+)$", path)
        if dj_detail_m:
            dj_id = quote(dj_detail_m.group(1), safe="")
            self._proxy_raver_get(f"/v1/djs/{dj_id}", parsed.query)
            return
        event_detail_m = re.match(r"^/api/raver/events/([^/]+)$", path)
        if event_detail_m:
            event_id = quote(event_detail_m.group(1), safe="")
            self._proxy_raver_get(
                f"/v1/events/{event_id}",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_lineup_m = re.match(r"^/api/raver/events/([^/]+)/lineup$", path)
        if event_lineup_m:
            event_id = quote(event_lineup_m.group(1), safe="")
            self._proxy_raver_get(
                f"/v1/events/{event_id}/lineup",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_timetable_m = re.match(r"^/api/raver/events/([^/]+)/timetable$", path)
        if event_timetable_m:
            event_id = quote(event_timetable_m.group(1), safe="")
            self._proxy_raver_get(
                f"/v1/events/{event_id}/timetable",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/profile/me":
            self._proxy_raver_get("/v1/profile/me", parsed.query, auth_header=self.headers.get("Authorization", ""))
            return
        if path == "/api/raver/learn/festivals":
            self._proxy_raver_get(
                "/v1/learn/festivals",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/learn/genres/admin/tree":
            self._proxy_raver_get(
                "/v1/learn/genres/admin/tree",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/learn/genres":
            self._proxy_raver_get(
                "/v1/learn/genres",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/learn/rankings":
            self._proxy_raver_get(
                "/v1/learn/rankings",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        ranking_detail_m = re.match(r"^/api/raver/learn/rankings/([^/]+)$", path)
        if ranking_detail_m:
            board_id = quote(ranking_detail_m.group(1), safe="")
            self._proxy_raver_get(
                f"/v1/learn/rankings/{board_id}",
                parsed.query,
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/dj-source-cache/query":
            q = (query.get("q") or [""])[0]
            normalized_query = _normalize_dj_cache_query(q)
            if not normalized_query:
                self._send_json(400, {"error": "q is required"})
                return
            record = _load_dj_source_cache_record(q)
            self._send_json(
                200,
                {
                    "ok": True,
                    "query": str(q or "").strip(),
                    "normalizedQuery": normalized_query,
                    "cache": record,
                },
            )
            return
        if path == "/api/dj-source-cache/avatar/resolve":
            raw_url = (query.get("url") or [""])[0].strip()
            if not raw_url:
                self._send_json(400, {"error": "url is required"})
                return
            local_url = _find_cached_avatar_local_url(raw_url)
            self._send_json(200, {"ok": True, "url": raw_url, "localUrl": local_url})
            return
        if path == "/api/dj-source-cache/logs":
            limit_raw = (query.get("limit") or ["50"])[0]
            try:
                limit = max(1, min(1000, int(limit_raw)))
            except ValueError:
                limit = 50
            logs = _read_recent_dj_cache_logs(limit=limit)
            self._send_json(200, {"ok": True, "count": len(logs), "logs": logs})
            return
        avatar_file_m = re.match(r"^/api/dj-source-cache/avatar/([^/]+)$", path)
        if avatar_file_m:
            raw_name = avatar_file_m.group(1)
            try:
                file_name = unquote_to_bytes(raw_name).decode("utf-8", errors="ignore")
            except Exception:
                file_name = raw_name
            if not re.fullmatch(r"[a-f0-9]{40}\.(?:jpg|jpeg|png|webp)", file_name, flags=re.I):
                self.send_error(404, "Not Found")
                return
            file_path = (DJ_SOURCE_CACHE_AVATAR_DIR / file_name).resolve()
            try:
                file_path.relative_to(DJ_SOURCE_CACHE_AVATAR_DIR.resolve())
            except Exception:
                self.send_error(404, "Not Found")
                return
            guessed, _ = mimetypes.guess_type(str(file_path))
            self._send_file(file_path, guessed or "application/octet-stream")
            return
        if path == "/api/proxy-image":
            raw_url = (query.get("url") or [""])[0].strip()
            if not raw_url:
                self._send_json(400, {"error": "url is required"})
                return
            try:
                req = Request(raw_url, headers={"User-Agent": USER_AGENT})
                with urlopen(req, timeout=40) as resp:
                    data = resp.read()
                    ctype = resp.headers.get("Content-Type", "")
                if not ctype:
                    guessed, _ = mimetypes.guess_type(raw_url)
                    ctype = guessed or "application/octet-stream"
                self.send_response(200)
                self.send_header("Content-Type", ctype)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
                self.send_header("Access-Control-Allow-Headers", "Content-Type")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as exc:  # noqa: BLE001
                self._send_json(502, {"error": f"image proxy failed: {exc}"})
            return
        if path == "/api/viewer/runtime-config":
            self._send_json(
                200,
                {
                    "ok": True,
                    "data": {
                        "amap": {
                            "jsApiKey": AMAP_JS_API_KEY,
                            "securityJsCode": AMAP_SECURITY_JS_CODE,
                        },
                        "mapkit": {
                            "jsToken": MAPKIT_JS_TOKEN,
                        },
                        "mapbox": {
                            "accessToken": MAPBOX_ACCESS_TOKEN,
                        },
                        "geoapify": {
                            "apiKey": GEOAPIFY_API_KEY,
                        }
                    },
                },
            )
            return
        if path == "/api/raver/djs/translate-bilingual/progress":
            job_id = (query.get("job_id") or [""])[0].strip()
            if not job_id:
                self._send_json(400, {"error": "job_id is required"})
                return
            since_raw = (query.get("since") or ["0"])[0].strip()
            try:
                since = max(0, int(since_raw))
            except ValueError:
                since = 0
            with JOBS_LOCK:
                job = JOBS.get(job_id)
                if not job or job.get("kind") != "dj_translate":
                    self._send_json(404, {"error": "job not found"})
                    return
                progress = job.get("progress", {}) or {}
                snapshot = json.loads(json.dumps(progress, ensure_ascii=False))
                status = str(job.get("status") or "unknown")

            completed_rows = snapshot.get("completed_rows") or []
            next_since = len(completed_rows)
            new_rows = completed_rows[since:] if since < next_since else []
            snapshot.pop("completed_rows", None)
            snapshot["completed_row_count"] = next_since
            snapshot["job_status"] = status

            self._send_json(
                200,
                {
                    "job_id": job_id,
                    "progress": snapshot,
                    "new_rows": new_rows,
                    "next_since": next_since,
                },
            )
            return
        if path == "/api/raver/djs/translate-bilingual/result":
            job_id = (query.get("job_id") or [""])[0].strip()
            if not job_id:
                self._send_json(400, {"error": "job_id is required"})
                return
            with JOBS_LOCK:
                job = JOBS.get(job_id)
                if not job or job.get("kind") != "dj_translate":
                    self._send_json(404, {"error": "job not found"})
                    return
                result = job.get("result")
                status = str(job.get("status") or "")
            if status in ("running", "stopping"):
                self._send_json(409, {"error": "job is not completed yet"})
                return
            self._send_json(200, {"job_id": job_id, "status": status, "result": result or {}})
            return
        if path == "/api/scrape/progress":
            job_id = (query.get("job_id") or [""])[0].strip()
            if not job_id:
                self._send_json(400, {"error": "job_id is required"})
                return
            since_raw = (query.get("since") or ["0"])[0].strip()
            try:
                since = max(0, int(since_raw))
            except ValueError:
                since = 0
            with JOBS_LOCK:
                job = JOBS.get(job_id)
                if not job:
                    self._send_json(404, {"error": "job not found"})
                    return
                progress = job.get("progress", {}) or {}
                # snapshot to avoid concurrent mutation while serializing
                snapshot = json.loads(json.dumps(progress, ensure_ascii=False))

            completed = snapshot.get("completed_event_results") or []
            next_since = len(completed)
            new_events = completed[since:] if since < next_since else []
            snapshot.pop("completed_event_results", None)
            snapshot["completed_event_count"] = next_since

            self._send_json(200, {
                "job_id": job_id,
                "progress": snapshot,
                "new_events": new_events,
                "next_since": next_since,
            })
            return
        if path == "/api/scrape/result":
            job_id = (query.get("job_id") or [""])[0].strip()
            if not job_id:
                self._send_json(400, {"error": "job_id is required"})
                return
            with JOBS_LOCK:
                job = JOBS.get(job_id)
                if not job:
                    self._send_json(404, {"error": "job not found"})
                    return
                result = job.get("result")
                status = job.get("status")
            if status != "completed" or result is None:
                self._send_json(409, {"error": "job is not completed yet"})
                return
            self._send_json(200, {"job_id": job_id, "result": result})
            return
        self.send_error(404, "Not Found")

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        if path == "/api/raver/wiki/brands/upload-image":
            self._proxy_raver_post_raw(
                "/v1/wiki/brands/upload-image",
                raw if isinstance(raw, (bytes, bytearray)) else b"",
                self.headers.get("Content-Type", "application/octet-stream"),
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/djs/upload-image":
            self._proxy_raver_post_raw(
                "/v1/djs/upload-image",
                raw if isinstance(raw, (bytes, bytearray)) else b"",
                self.headers.get("Content-Type", "application/octet-stream"),
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/events/upload-image":
            self._proxy_raver_post_raw(
                "/v1/events/upload-image",
                raw if isinstance(raw, (bytes, bytearray)) else b"",
                self.headers.get("Content-Type", "application/octet-stream"),
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/feed/upload-image":
            self._proxy_raver_post_raw(
                "/v1/feed/upload-image",
                raw if isinstance(raw, (bytes, bytearray)) else b"",
                self.headers.get("Content-Type", "application/octet-stream"),
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/learn/rankings/upload-image":
            self._proxy_raver_post_raw(
                "/v1/learn/rankings/upload-image",
                raw if isinstance(raw, (bytes, bytearray)) else b"",
                self.headers.get("Content-Type", "application/octet-stream"),
                auth_header=self.headers.get("Authorization", ""),
            )
            return

        try:
            body = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON body"})
            return

        if path == "/api/viewer/news/import-wechat":
            payload = body if isinstance(body, dict) else {}
            article_url = str(payload.get("url") or "").strip()
            if not article_url:
                self._send_json(400, {"error": "url is required"})
                return
            try:
                data = _import_wechat_article_payload(article_url)
                self._send_json(200, {"ok": True, "data": data})
            except ValueError as exc:
                self._send_json(400, {"error": str(exc)})
            except Exception as exc:  # noqa: BLE001
                self._send_json(502, {"error": f"wechat import failed: {exc}"})
            return

        if path == "/api/raver/events":
            self._proxy_raver_post(
                "/v1/events",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/feed/posts":
            self._proxy_raver_post(
                "/v1/feed/posts",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/feed/draft-media/cleanup":
            self._proxy_raver_post(
                "/v1/feed/draft-media/cleanup",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        content_submission_review_m = re.match(r"^/api/admin/v1/content-submissions/([^/]+)/review$", path)
        if content_submission_review_m:
            submission_id = quote(unquote_to_bytes(content_submission_review_m.group(1)))
            self._proxy_raver_post(
                f"/api/admin/v1/content-submissions/{submission_id}/review",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/admin/v1/dj-enrichment/jobs":
            self._proxy_raver_post(
                "/api/admin/v1/dj-enrichment/jobs",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        dj_enrichment_review_m = re.match(r"^/api/admin/v1/dj-enrichment/results/([^/]+)/review$", path)
        if dj_enrichment_review_m:
            result_id = quote(unquote_to_bytes(dj_enrichment_review_m.group(1)))
            self._proxy_raver_post(
                f"/api/admin/v1/dj-enrichment/results/{result_id}/review",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/learn/festivals":
            self._proxy_raver_post(
                "/v1/learn/festivals",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/learn/genres/key-artists/auto-match":
            self._proxy_raver_post(
                "/v1/learn/genres/key-artists/auto-match",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        genre_key_artist_bindings_m = re.match(r"^/api/raver/learn/genres/([^/]+)/key-artist-bindings$", path)
        if genre_key_artist_bindings_m:
            genre_id = quote(genre_key_artist_bindings_m.group(1), safe="")
            self._proxy_raver_post(
                f"/v1/learn/genres/{genre_id}/key-artist-bindings",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/learn/rankings":
            self._proxy_raver_post(
                "/v1/learn/rankings",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        ranking_update_m = re.match(r"^/api/raver/learn/rankings/([^/]+)/update$", path)
        if ranking_update_m:
            board_id = quote(ranking_update_m.group(1), safe="")
            self._proxy_raver_patch(
                f"/v1/learn/rankings/{board_id}",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        ranking_delete_m = re.match(r"^/api/raver/learn/rankings/([^/]+)/delete$", path)
        if ranking_delete_m:
            board_id = quote(ranking_delete_m.group(1), safe="")
            self._proxy_raver_delete(
                f"/v1/learn/rankings/{board_id}",
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        ranking_year_upsert_m = re.match(r"^/api/raver/learn/rankings/([^/]+)/years/([^/]+)/upsert$", path)
        if ranking_year_upsert_m:
            board_id = quote(ranking_year_upsert_m.group(1), safe="")
            year = quote(ranking_year_upsert_m.group(2), safe="")
            self._proxy_raver_post(
                f"/v1/learn/rankings/{board_id}/years/{year}/upsert",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        learn_festival_update_m = re.match(r"^/api/raver/learn/festivals/([^/]+)/update$", path)
        if learn_festival_update_m:
            festival_id = quote(learn_festival_update_m.group(1), safe="")
            self._proxy_raver_patch(
                f"/v1/learn/festivals/{festival_id}",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        learn_festival_delete_m = re.match(r"^/api/raver/learn/festivals/([^/]+)/delete$", path)
        if learn_festival_delete_m:
            festival_id = quote(learn_festival_delete_m.group(1), safe="")
            self._proxy_raver_delete(
                f"/v1/learn/festivals/{festival_id}",
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_delete_m = re.match(r"^/api/raver/events/([^/]+)/delete$", path)
        if event_delete_m:
            event_id = quote(event_delete_m.group(1), safe="")
            self._proxy_raver_delete(
                f"/v1/events/{event_id}",
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        dj_delete_m = re.match(r"^/api/raver/djs/([^/]+)/delete$", path)
        if dj_delete_m:
            dj_id = quote(dj_delete_m.group(1), safe="")
            self._proxy_raver_delete(
                f"/v1/djs/{dj_id}",
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_update_m = re.match(r"^/api/raver/events/([^/]+)/update$", path)
        if event_update_m:
            event_id = quote(event_update_m.group(1), safe="")
            self._proxy_raver_patch(
                f"/v1/events/{event_id}",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_lineup_create_m = re.match(r"^/api/raver/events/([^/]+)/lineup$", path)
        if event_lineup_create_m:
            event_id = quote(event_lineup_create_m.group(1), safe="")
            self._proxy_raver_post(
                f"/v1/events/{event_id}/lineup",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_lineup_update_m = re.match(r"^/api/raver/events/([^/]+)/lineup/([^/]+)/update$", path)
        if event_lineup_update_m:
            event_id = quote(event_lineup_update_m.group(1), safe="")
            artist_id = quote(event_lineup_update_m.group(2), safe="")
            self._proxy_raver_patch(
                f"/v1/events/{event_id}/lineup/{artist_id}",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_lineup_delete_m = re.match(r"^/api/raver/events/([^/]+)/lineup/([^/]+)/delete$", path)
        if event_lineup_delete_m:
            event_id = quote(event_lineup_delete_m.group(1), safe="")
            artist_id = quote(event_lineup_delete_m.group(2), safe="")
            self._proxy_raver_delete(
                f"/v1/events/{event_id}/lineup/{artist_id}",
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_timetable_create_m = re.match(r"^/api/raver/events/([^/]+)/timetable$", path)
        if event_timetable_create_m:
            event_id = quote(event_timetable_create_m.group(1), safe="")
            self._proxy_raver_post(
                f"/v1/events/{event_id}/timetable",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_timetable_update_m = re.match(r"^/api/raver/events/([^/]+)/timetable/([^/]+)/update$", path)
        if event_timetable_update_m:
            event_id = quote(event_timetable_update_m.group(1), safe="")
            slot_id = quote(event_timetable_update_m.group(2), safe="")
            self._proxy_raver_patch(
                f"/v1/events/{event_id}/timetable/{slot_id}",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        event_timetable_delete_m = re.match(r"^/api/raver/events/([^/]+)/timetable/([^/]+)/delete$", path)
        if event_timetable_delete_m:
            event_id = quote(event_timetable_delete_m.group(1), safe="")
            slot_id = quote(event_timetable_delete_m.group(2), safe="")
            self._proxy_raver_delete(
                f"/v1/events/{event_id}/timetable/{slot_id}",
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        feed_post_update_m = re.match(r"^/api/raver/feed/posts/([^/]+)/update$", path)
        if feed_post_update_m:
            post_id = quote(feed_post_update_m.group(1), safe="")
            self._proxy_raver_patch(
                f"/v1/feed/posts/{post_id}",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        feed_post_delete_m = re.match(r"^/api/raver/feed/posts/([^/]+)/delete$", path)
        if feed_post_delete_m:
            post_id = quote(feed_post_delete_m.group(1), safe="")
            self._proxy_raver_delete(
                f"/v1/feed/posts/{post_id}",
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        dj_update_m = re.match(r"^/api/raver/djs/([^/]+)/update$", path)
        if dj_update_m:
            dj_id = quote(dj_update_m.group(1), safe="")
            self._proxy_raver_patch(
                f"/v1/djs/{dj_id}",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/djs/translate-bilingual/start":
            payload = body if isinstance(body, dict) else {}
            raw_ids = payload.get("djIds")
            if not isinstance(raw_ids, list):
                self._send_json(400, {"error": "djIds must be an array"})
                return

            auth_header = str(self.headers.get("Authorization", "") or "").strip()
            if not auth_header:
                self._send_json(401, {"error": "Authorization is required"})
                return

            dedup_ids: List[str] = []
            seen_ids = set()
            for value in raw_ids:
                dj_id = str(value or "").strip()
                if not dj_id or dj_id in seen_ids:
                    continue
                seen_ids.add(dj_id)
                dedup_ids.append(dj_id)

            if not dedup_ids:
                self._send_json(400, {"error": "djIds cannot be empty"})
                return

            job_id = str(uuid4())
            with JOBS_LOCK:
                JOBS[job_id] = {
                    "kind": "dj_translate",
                    "status": "running",
                    "created_at": datetime.now(timezone.utc).isoformat(),
                    "result": None,
                    "progress": {
                        "status": "running",
                        "total": len(dedup_ids),
                        "processed": 0,
                        "updated": 0,
                        "failed": 0,
                        "skipped": 0,
                        "stop_requested": False,
                        "current_index": 0,
                        "current_dj_id": "",
                        "current_dj_name": "",
                        "message": "任务已启动",
                        "completed_rows": [],
                    },
                }

            t = threading.Thread(
                target=_run_dj_translate_job,
                args=(job_id, dedup_ids, auth_header),
                daemon=True,
            )
            t.start()
            self._send_json(200, {"job_id": job_id, "status": "running", "total": len(dedup_ids)})
            return
        if path == "/api/raver/djs/translate-bilingual/stop":
            payload = body if isinstance(body, dict) else {}
            job_id = str(payload.get("job_id") or "").strip()
            if not job_id:
                self._send_json(400, {"error": "job_id is required"})
                return
            with JOBS_LOCK:
                job = JOBS.get(job_id)
                if not job or job.get("kind") != "dj_translate":
                    self._send_json(404, {"error": "job not found"})
                    return
                if str(job.get("status") or "") not in ("running", "stopping"):
                    self._send_json(409, {"error": "job is not running"})
                    return
                progress = job.get("progress") or {}
                progress["stop_requested"] = True
                progress["status"] = "stopping"
                progress["message"] = "收到停止请求，当前条目完成后停止"
                job["status"] = "stopping"
            self._send_json(200, {"ok": True, "job_id": job_id, "status": "stopping"})
            return
        if path == "/api/raver/djs/translate-bilingual":
            payload = body if isinstance(body, dict) else {}
            raw_ids = payload.get("djIds")
            if not isinstance(raw_ids, list):
                self._send_json(400, {"error": "djIds must be an array"})
                return

            auth_header = str(self.headers.get("Authorization", "") or "").strip()
            if not auth_header:
                self._send_json(401, {"error": "Authorization is required"})
                return

            dedup_ids: List[str] = []
            seen_ids = set()
            for value in raw_ids:
                dj_id = str(value or "").strip()
                if not dj_id or dj_id in seen_ids:
                    continue
                seen_ids.add(dj_id)
                dedup_ids.append(dj_id)

            if not dedup_ids:
                self._send_json(400, {"error": "djIds cannot be empty"})
                return

            rows: List[Dict[str, Any]] = []
            total = len(dedup_ids)
            success = 0
            failed = 0
            skipped = 0

            for index, dj_id in enumerate(dedup_ids, start=1):
                row_result: Dict[str, Any] = {
                    "djId": dj_id,
                    "index": index,
                    "status": "pending",
                }
                try:
                    encoded_id = quote(dj_id, safe="")
                    detail_resp = self._raver_json_request(
                        method="GET",
                        upstream_path=f"/v1/djs/{encoded_id}",
                        auth_header=auth_header,
                    )
                    dj_data = detail_resp.get("data") if isinstance(detail_resp, dict) else None
                    if not isinstance(dj_data, dict):
                        raise RuntimeError("DJ detail response missing data")

                    source_country = str(dj_data.get("country") or "").strip()
                    source_bio = str(dj_data.get("bio") or "").strip()
                    if not source_country and not source_bio:
                        skipped += 1
                        row_result.update(
                            {
                                "status": "skipped",
                                "reason": "country and bio are both empty",
                            }
                        )
                        rows.append(row_result)
                        continue

                    translated_out = run_coze_translate_dj_fields(
                        {
                            "country": source_country,
                            "bio": source_bio,
                        }
                    )
                    translated = translated_out.get("translated") if isinstance(translated_out, dict) else {}
                    fields_cn = translated.get("fields_cn") if isinstance(translated, dict) else {}
                    fields_en = translated.get("fields_en") if isinstance(translated, dict) else {}

                    def _read_lang_value(group: Any, key: str) -> str:
                        if not isinstance(group, dict):
                            return ""
                        return str(group.get(key) or "").strip()

                    next_country_zh = _clean_dj_translation_text(_read_lang_value(fields_cn, "country"), source_country)
                    next_country_en = _clean_dj_translation_text(_read_lang_value(fields_en, "country"), source_country)
                    next_bio_zh = _clean_dj_translation_text(_read_lang_value(fields_cn, "bio"), source_bio)
                    next_bio_en = _clean_dj_translation_text(_read_lang_value(fields_en, "bio"), source_bio)

                    existing_country_i18n = dj_data.get("countryI18n") if isinstance(dj_data.get("countryI18n"), dict) else {}
                    existing_bio_i18n = dj_data.get("bioI18n") if isinstance(dj_data.get("bioI18n"), dict) else {}

                    if not next_country_en:
                        next_country_en = str(existing_country_i18n.get("en") or "").strip()
                    if not next_country_zh:
                        next_country_zh = str(existing_country_i18n.get("zh") or "").strip()
                    if not next_bio_en:
                        next_bio_en = str(existing_bio_i18n.get("en") or "").strip()
                    if not next_bio_zh:
                        next_bio_zh = str(existing_bio_i18n.get("zh") or "").strip()

                    if source_country:
                        if not next_country_en and not next_country_zh:
                            next_country_en = source_country
                    else:
                        next_country_en = ""
                        next_country_zh = ""
                    if source_bio:
                        if not next_bio_en and not next_bio_zh:
                            next_bio_en = source_bio
                    else:
                        next_bio_en = ""
                        next_bio_zh = ""

                    update_payload: Dict[str, Any] = {}
                    if next_country_en or next_country_zh:
                        update_payload["countryI18n"] = _normalize_country_i18n(
                            {
                                "en": next_country_en,
                                "zh": next_country_zh,
                                "enFull": str(existing_country_i18n.get("enFull") or "").strip(),
                            },
                            source_country,
                        )
                    if next_bio_en or next_bio_zh:
                        update_payload["bioI18n"] = {
                            "en": next_bio_en,
                            "zh": next_bio_zh,
                        }

                    if not update_payload:
                        skipped += 1
                        row_result.update(
                            {
                                "status": "skipped",
                                "reason": "no bilingual fields generated",
                            }
                        )
                        rows.append(row_result)
                        continue

                    self._raver_json_request(
                        method="PATCH",
                        upstream_path=f"/v1/djs/{encoded_id}",
                        payload=update_payload,
                        auth_header=auth_header,
                    )
                    success += 1
                    row_result.update(
                        {
                            "status": "updated",
                            "countryUpdated": "countryI18n" in update_payload,
                            "bioUpdated": "bioI18n" in update_payload,
                        }
                    )
                except Exception as exc:  # noqa: BLE001
                    failed += 1
                    row_result.update({"status": "error", "reason": str(exc)})
                rows.append(row_result)

            self._send_json(
                200,
                {
                    "ok": True,
                    "data": {
                        "total": total,
                        "success": success,
                        "failed": failed,
                        "skipped": skipped,
                        "rows": rows,
                    },
                },
            )
            return
        if path == "/api/raver/djs/manual/import":
            self._proxy_raver_post(
                "/v1/djs/manual/import",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/djs/spotify/import":
            self._proxy_raver_post(
                "/v1/djs/spotify/import",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/djs/discogs/import":
            self._proxy_raver_post(
                "/v1/djs/discogs/import",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/raver/auth/login":
            self._proxy_raver_post(
                "/v1/auth/login",
                body if isinstance(body, dict) else {},
                auth_header=self.headers.get("Authorization", ""),
            )
            return
        if path == "/api/dj-source-cache/log":
            payload = body if isinstance(body, dict) else {}
            entry = _append_dj_cache_log(
                level=str(payload.get("level", "info") or "info"),
                action=str(payload.get("action", "client_log") or "client_log"),
                query=str(payload.get("query", "") or ""),
                source=str(payload.get("source", "") or ""),
                message=str(payload.get("message", "") or ""),
                detail=payload.get("detail") if isinstance(payload.get("detail"), dict) else None,
            )
            self._send_json(200, {"ok": True, "entry": entry})
            return
        if path == "/api/dj-source-cache/query/save":
            payload = body if isinstance(body, dict) else {}
            query_text = str(payload.get("query", "") or "").strip()
            normalized_query = _normalize_dj_cache_query(query_text)
            sources_raw = payload.get("sources")
            if not normalized_query:
                self._send_json(400, {"error": "query is required"})
                return
            if not isinstance(sources_raw, dict):
                self._send_json(400, {"error": "sources must be an object"})
                return
            cache_avatars = payload.get("cacheAvatars", True)
            cache_avatars = bool(cache_avatars) if isinstance(cache_avatars, bool) else True
            try:
                safe_sources = _sanitize_cache_sources(
                    query=query_text,
                    sources=sources_raw,
                    cache_avatars=cache_avatars,
                )
                now_ms = int(time.time() * 1000)
                record = {
                    "cacheKey": f"query:{normalized_query}",
                    "query": query_text,
                    "normalizedQuery": normalized_query,
                    "schemaVersion": 1,
                    "updatedAt": now_ms,
                    "sources": safe_sources,
                }
                query_file = _dj_cache_query_file(normalized_query)
                with DJ_SOURCE_CACHE_LOCK:
                    _write_json_atomic(query_file, record)
                _prune_dj_source_cache_if_needed(force=True)
                source_summary: Dict[str, Dict[str, Any]] = {}
                for source_key in ("spotify", "discogs", "soundcloud"):
                    group = safe_sources.get(source_key) or {}
                    items = group.get("items") if isinstance(group.get("items"), list) else []
                    avatar_cached = 0
                    for item in items:
                        if isinstance(item, dict) and str(item.get("avatarDisplayUrl", "")).strip():
                            avatar_cached += 1
                    source_summary[source_key] = {
                        "status": str(group.get("status", "idle") or "idle"),
                        "items": len(items),
                        "avatarsCached": avatar_cached,
                    }
                    _append_dj_cache_log(
                        level="info",
                        action="query_save",
                        query=query_text,
                        source=source_key,
                        message=(
                            f"status={source_summary[source_key]['status']} "
                            f"items={source_summary[source_key]['items']} "
                            f"avatarsCached={source_summary[source_key]['avatarsCached']}"
                        ),
                    )
                self._send_json(
                    200,
                    {
                        "ok": True,
                        "cache": record,
                        "summary": source_summary,
                        "file": str(query_file),
                    },
                )
            except Exception as exc:  # noqa: BLE001
                _append_dj_cache_log(
                    level="error",
                    action="query_save_error",
                    query=query_text,
                    source="",
                    message=str(exc),
                )
                self._send_json(500, {"error": f"save cache failed: {exc}"})
            return

        if path == "/api/coze/recognize":
            festival_image = str(body.get("festival_image", "")).strip()
            if not festival_image:
                self._send_json(400, {"error": "festival_image is required"})
                return
            try:
                out = run_coze_recognition(festival_image)
                self._send_json(
                    200,
                    {
                        "ok": True,
                        "lineup_info": out.get("lineup_info") or [],
                        "formatted_output": out.get("raw", {}).get("formatted_output"),
                        "raw_response": out.get("raw"),
                    },
                )
            except Exception as exc:  # noqa: BLE001
                self._send_json(502, {"error": f"coze recognize failed: {exc}"})
            return

        if path == "/api/coze/poster-info":
            poster_image = str(body.get("poster_image", "")).strip()
            file_type = str(body.get("file_type", "")).strip()
            if not poster_image:
                self._send_json(400, {"error": "poster_image is required"})
                return
            try:
                out = run_coze_poster_recognition(poster_image, file_type=file_type)
                self._send_json(
                    200,
                    {
                        "ok": True,
                        "event_info": out.get("event_info") or {},
                        "raw_response": out.get("raw"),
                    },
                )
            except Exception as exc:  # noqa: BLE001
                self._send_json(502, {"error": f"coze poster recognize failed: {exc}"})
            return

        if path == "/api/coze/translate-festival":
            festival = body.get("festival")
            if not isinstance(festival, dict):
                self._send_json(400, {"error": "festival object is required"})
                return
            try:
                out = run_coze_translate_festival(festival)
                self._send_json(
                    200,
                    {
                        "ok": True,
                        "translated": out.get("translated") or {},
                        "formatted_output": out.get("raw", {}).get("formatted_output"),
                        "raw_response": out.get("raw"),
                    },
                )
            except Exception as exc:  # noqa: BLE001
                self._send_json(502, {"error": f"coze translate failed: {exc}"})
            return

        if path == "/api/coze/normalize-event-location":
            location_payload = (
                body.get("location")
                or body.get("locationPoint")
                or body.get("location_point")
                or {}
            )
            editable_payload = body.get("editable")
            if not isinstance(location_payload, dict):
                location_payload = {}
            if not isinstance(editable_payload, dict):
                editable_payload = {}
            if not location_payload and not editable_payload:
                self._send_json(400, {"error": "location or editable object is required"})
                return
            context_payload = body.get("context")
            if not isinstance(context_payload, dict):
                context_payload = {}
            try:
                out = run_coze_normalize_event_location(
                    location_payload=location_payload,
                    context_payload=context_payload,
                    raw_payload=body if isinstance(body, dict) else {},
                )
                self._send_json(
                    200,
                    {
                        "ok": True,
                        "normalized": out.get("normalized") or {},
                        "issues": out.get("issues") or [],
                        "formatted_output": out.get("raw", {}).get("formatted_output"),
                        "raw_response": out.get("raw"),
                    },
                )
            except Exception as exc:  # noqa: BLE001
                self._send_json(502, {"error": f"coze location normalize failed: {exc}"})
            return

        if path == "/api/coze/translate-dj-fields":
            raw_fields = body.get("fields")
            fields = raw_fields if isinstance(raw_fields, dict) else {}
            source_country = str(fields.get("country") or "").strip()
            source_bio = str(fields.get("bio") or "").strip()
            if not source_country and not source_bio:
                self._send_json(400, {"error": "fields.country or fields.bio is required"})
                return
            try:
                out = run_coze_translate_dj_fields(
                    {
                        "country": source_country,
                        "bio": source_bio,
                    }
                )
                translated = out.get("translated") if isinstance(out, dict) else {}
                fields_cn_raw = translated.get("fields_cn") if isinstance(translated, dict) else {}
                fields_en_raw = translated.get("fields_en") if isinstance(translated, dict) else {}

                def _read_lang(group: Any, key: str) -> str:
                    if not isinstance(group, dict):
                        return ""
                    return str(group.get(key) or "").strip()

                next_country_cn = _clean_dj_translation_text(_read_lang(fields_cn_raw, "country"), source_country)
                next_country_en = _clean_dj_translation_text(_read_lang(fields_en_raw, "country"), source_country)
                next_bio_cn = _clean_dj_translation_text(_read_lang(fields_cn_raw, "bio"), source_bio)
                next_bio_en = _clean_dj_translation_text(_read_lang(fields_en_raw, "bio"), source_bio)

                if not source_country:
                    next_country_cn = ""
                    next_country_en = ""
                if not source_bio:
                    next_bio_cn = ""
                    next_bio_en = ""

                self._send_json(
                    200,
                    {
                        "ok": True,
                        "translated": {
                            "fields_cn": {
                                "country": next_country_cn,
                                "bio": next_bio_cn,
                            },
                            "fields_en": {
                                "country": next_country_en,
                                "bio": next_bio_en,
                            },
                        },
                        "raw_response": out.get("raw") if isinstance(out, dict) else None,
                    },
                )
            except Exception as exc:  # noqa: BLE001
                self._send_json(502, {"error": f"coze dj translate failed: {exc}"})
            return

        if path == "/api/open-folder":
            relative_path = str(body.get("relative_path", "")).strip()
            if not relative_path:
                self._send_json(400, {"error": "relative_path is required"})
                return
            scope = str(body.get("scope", "brands")).strip() or "brands"
            try:
                out = open_folder_in_os(relative_path, scope=scope)
                self._send_json(200, {"ok": True, **out})
            except Exception as exc:  # noqa: BLE001
                self._send_json(500, {"error": str(exc)})
            return

        if path == "/api/search":
            keyword = str(body.get("keyword", "")).strip()
            locale = str(body.get("locale", "en-GB")).strip() or "en-GB"
            if not keyword:
                self._send_json(400, {"error": "keyword is required"})
                return
            try:
                events = discover_event_urls(locale=locale, keyword=keyword)
                self._send_json(200, {"keyword": keyword, "locale": locale, "count": len(events), "events": events})
            except Exception as exc:  # noqa: BLE001
                self._send_json(500, {"error": str(exc)})
            return

        if path == "/api/scrape/start":
            event_urls = body.get("event_urls") or []
            if not isinstance(event_urls, list) or not event_urls:
                self._send_json(400, {"error": "event_urls must be a non-empty array"})
                return
            skip_festival_ids = body.get("skip_festival_ids") or []
            if not isinstance(skip_festival_ids, list):
                self._send_json(400, {"error": "skip_festival_ids must be an array"})
                return

            job_id = str(uuid4())
            progress_events = []
            for u in event_urls:
                slug = urlparse(u).path.rstrip("/").split("/")[-1]
                progress_events.append(
                    {
                        "url": u,
                        "slug": slug,
                        "title": None,
                        "status": "queued",
                        "message": "排队中",
                        "total_timetables": 0,
                        "completed_timetables": 0,
                    }
                )

            with JOBS_LOCK:
                JOBS[job_id] = {
                    "status": "running",
                    "created_at": datetime.now(timezone.utc).isoformat(),
                    "result": None,
                    "progress": {
                        "status": "running",
                        "total_events": len(event_urls),
                        "completed_events": 0,
                        "skipped_events": 0,
                        "completed_event_results": [],
                        "current_event_index": 0,
                        "events": progress_events,
                    },
                }

            t = threading.Thread(target=_run_scrape_job, args=(job_id, event_urls, skip_festival_ids), daemon=True)
            t.start()

            self._send_json(200, {"job_id": job_id, "status": "running"})
            return

        self.send_error(404, "Not Found")


def run(host: str = "127.0.0.1", port: int = 8000):
    _start_oss_cleanup_daemon()
    _ensure_dj_source_cache_dirs()
    server = ThreadingHTTPServer((host, port), Handler)
    print(f"Web tool running at http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    run()
