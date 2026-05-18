#!/usr/bin/env python3
"""
Colab-friendly DJ multi-source prefetch + local cache exporter.

Goals:
1) Extract DJ names from scrapRave brands festival-info.json (optional).
2) Fetch top-N candidates from Spotify/Discogs/SoundCloud for each DJ name.
3) Cache query snapshots + avatars + structured logs on disk.
4) Export one zip package for download from Colab.

Designed to mirror web_tool cache shape as much as possible:
- queries/<sha1(normalized_name)>.json
- avatars/<sha1(avatar_url)>.<ext>
- logs.ndjson
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import mimetypes
import os
import re
import time
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlparse

try:
    import requests
except ImportError:  # pragma: no cover - handled at runtime
    requests = None  # type: ignore[assignment]


USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)

SOURCE_KEYS = ("spotify", "discogs", "soundcloud")


def now_ms() -> int:
    return int(time.time() * 1000)


def normalize_query(text: str) -> str:
    return " ".join(str(text or "").strip().lower().split())


def is_meaningful_dj_name(text: str) -> bool:
    """
    Keep names that contain at least one letter/number/CJK.
    Filters out pure punctuation like ')' or '---'.
    """
    s = str(text or "").strip()
    if not s:
        return False
    return bool(re.search(r"[A-Za-z0-9\u4e00-\u9fff]", s))


def query_sha1(normalized_query: str) -> str:
    return hashlib.sha1(normalized_query.encode("utf-8")).hexdigest()


def file_sha1(text: str) -> str:
    return hashlib.sha1(str(text or "").strip().encode("utf-8")).hexdigest()


def infer_ext(content_type: str, url: str) -> str:
    ctype = str(content_type or "").lower()
    if "png" in ctype:
        return "png"
    if "webp" in ctype:
        return "webp"
    if "jpeg" in ctype or "jpg" in ctype:
        return "jpg"
    guessed, _ = mimetypes.guess_type(url)
    guessed = str(guessed or "").lower()
    if "png" in guessed:
        return "png"
    if "webp" in guessed:
        return "webp"
    return "jpg"


def replace_soundcloud_avatar_variant(url: str, variant: str) -> str:
    base = str(url or "").strip()
    if not base or "sndcdn.com/avatars-" not in base.lower():
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


def soundcloud_avatar_candidates(url: str) -> List[str]:
    base = str(url or "").strip()
    if not base:
        return []
    out: List[str] = []
    for variant in ("original", "t500x500"):
        u = replace_soundcloud_avatar_variant(base, variant)
        if u:
            out.append(u)
    out.append(base)
    dedup: List[str] = []
    seen = set()
    for u in out:
        if u in seen:
            continue
        seen.add(u)
        dedup.append(u)
    return dedup


def split_collab_names(raw_name: str) -> List[str]:
    """
    Split B2B/B3B acts like:
    - "AXWELL B2B SEBASTIAN INGROSSO"
    - "A b3b B b3b C"
    Returns participant names; if no split pattern, returns [raw_name].
    """
    text = str(raw_name or "").strip()
    if not text:
        return []
    for key in ("B3B", "B2B"):
        token = "__DJ_SPLIT__"
        replaced = re.sub(rf"(?i)\s*{re.escape(key)}\s*", token, text)
        parts = [p.strip() for p in replaced.split(token) if p.strip()]
        if len(parts) >= (3 if key == "B3B" else 2):
            limit = 3 if key == "B3B" else 2
            return parts[:limit]
    return [text]


def load_json(path: Path) -> Optional[Dict[str, Any]]:
    try:
        with path.open("r", encoding="utf-8") as f:
            obj = json.load(f)
        if isinstance(obj, dict):
            return obj
    except Exception:
        return None
    return None


def load_env_file(path: Path) -> Dict[str, str]:
    loaded: Dict[str, str] = {}
    if not path.exists() or not path.is_file():
        return loaded
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.lower().startswith("export "):
            line = line[7:].strip()
            if not line:
                continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        k = key.strip()
        v = value.strip().strip('"').strip("'")
        if not k:
            continue
        os.environ[k] = v
        loaded[k] = v
    return loaded


def is_colab_runtime() -> bool:
    try:
        import google.colab  # noqa: F401

        return True
    except Exception:
        return False


def colab_download_file(path: Path) -> Tuple[bool, str]:
    try:
        from google.colab import files  # type: ignore

        files.download(str(path))
        return True, ""
    except Exception as e:
        return False, str(e)


def extract_names_from_brands(brands_root: Path) -> List[str]:
    names_by_key: Dict[str, str] = {}
    for path in brands_root.rglob("festival-info.json"):
        obj = load_json(path)
        if not obj:
            continue
        lineup = obj.get("lineup")
        if not isinstance(lineup, list):
            continue
        for row in lineup:
            if not isinstance(row, dict):
                continue
            musician = str(row.get("musician") or "").strip()
            if not musician:
                continue
            for name in split_collab_names(musician):
                key = normalize_query(name)
                if key and key not in names_by_key:
                    names_by_key[key] = name
    return sorted(names_by_key.values(), key=lambda x: x.lower())


def load_names_from_file(path: Path, split_collab: bool = False) -> List[str]:
    if not path.exists():
        return []
    ext = path.suffix.lower()
    out: List[str] = []
    if ext in (".txt", ".list"):
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            s = line.strip()
            if s:
                out.append(s)
    elif ext == ".json":
        try:
            obj = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(obj, list):
                for x in obj:
                    s = str(x).strip()
                    if s:
                        out.append(s)
            elif isinstance(obj, dict):
                for key in ("names", "djs", "items"):
                    arr = obj.get(key)
                    if isinstance(arr, list):
                        for x in arr:
                            s = str(x).strip()
                            if s:
                                out.append(s)
                        break
        except Exception:
            return []
    elif ext == ".csv":
        with path.open("r", encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                val = str(
                    row.get("name")
                    or row.get("dj")
                    or row.get("musician")
                    or row.get("artist")
                    or ""
                ).strip()
                if val:
                    out.append(val)
    else:
        # best effort: treat as line text
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            s = line.strip()
            if s:
                out.append(s)

    dedup: Dict[str, str] = {}
    for raw in out:
        candidates = split_collab_names(raw) if split_collab else [str(raw or "").strip()]
        for name in candidates:
            clean = str(name or "").strip()
            if not clean:
                continue
            if not is_meaningful_dj_name(clean):
                continue
            key = normalize_query(clean)
            if key and key not in dedup:
                dedup[key] = clean
    return sorted(dedup.values(), key=lambda x: x.lower())


def get_discogs_token_with_key() -> Tuple[str, str]:
    preferred = (
        "DISCOGS_USER_TOKEN",
        "DISCOGS_TOKEN",
        "Discogs_USER_TOKEN",
        "discogs_user_token",
        "discogs_token",
    )
    for key in preferred:
        value = str(os.getenv(key, "")).strip()
        if value:
            return key, value

    # Fallback: case-insensitive scan
    for key, value in os.environ.items():
        lk = str(key).lower()
        if "discogs" in lk and "token" in lk:
            vv = str(value or "").strip()
            if vv:
                return key, vv
    return "", ""


def get_discogs_token() -> str:
    _key, token = get_discogs_token_with_key()
    return token


def get_source_credential_status() -> Dict[str, bool]:
    _discogs_key, discogs_token = get_discogs_token_with_key()
    return {
        "spotify": bool(
            str(os.getenv("SPOTIFY_CLIENT_ID", "")).strip()
            and str(os.getenv("SPOTIFY_CLIENT_SECRET", "")).strip()
        ),
        "discogs": bool(discogs_token),
        "soundcloud": bool(
            (str(os.getenv("SOUNDCLOUD_CLIENT_ID", "")).strip() or str(os.getenv("SoundCloud_CLIENT_ID", "")).strip())
            and (
                str(os.getenv("SOUNDCLOUD_CLIENT_SECRET", "")).strip()
                or str(os.getenv("SoundCloud_CLIENT_SECRET", "")).strip()
            )
        ),
    }


@dataclass
class RuntimeConfig:
    output_root: Path
    queries_dir: Path
    avatars_dir: Path
    logs_file: Path
    top_n: int
    dj_interval_sec: float
    retry_interval_sec: float
    retry_times: int
    request_timeout_sec: float


class Logger:
    def __init__(self, logs_file: Path, verbose: bool = True) -> None:
        self.logs_file = logs_file
        self.verbose = verbose
        self.logs_file.parent.mkdir(parents=True, exist_ok=True)

    def write(
        self,
        level: str,
        action: str,
        query: str = "",
        source: str = "",
        message: str = "",
        detail: Optional[Dict[str, Any]] = None,
    ) -> None:
        record = {
            "id": f"log-{now_ms()}-{os.urandom(4).hex()}",
            "at": now_ms(),
            "level": level,
            "action": action,
            "query": query,
            "source": source,
            "message": message,
            "detail": detail if isinstance(detail, dict) else None,
        }
        with self.logs_file.open("a", encoding="utf-8") as f:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
        if self.verbose:
            print(
                f"[{level}] {action}"
                f"{' [' + source + ']' if source else ''}"
                f"{' ' + query if query else ''}"
                f" -> {message}"
            )


class SourceClient:
    def __init__(self, cfg: RuntimeConfig, logger: Logger) -> None:
        if requests is None:
            raise RuntimeError("`requests` is required. Please run: pip install requests")
        self.cfg = cfg
        self.log = logger
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT, "Accept": "application/json"})
        self.spotify_token: Optional[str] = None
        self.spotify_expires_at = 0.0
        self.sc_token: Optional[str] = None
        self.sc_expires_at = 0.0

    def _get(self, url: str, headers: Optional[Dict[str, str]] = None) -> requests.Response:
        return self.session.get(url, headers=headers, timeout=self.cfg.request_timeout_sec)

    def _post(self, url: str, headers: Dict[str, str], data: Dict[str, Any]) -> requests.Response:
        return self.session.post(url, headers=headers, data=data, timeout=self.cfg.request_timeout_sec)

    def _spotify_access_token(self) -> Optional[str]:
        now = time.time()
        if self.spotify_token and now < self.spotify_expires_at - 30:
            return self.spotify_token
        cid = os.getenv("SPOTIFY_CLIENT_ID", "").strip()
        sec = os.getenv("SPOTIFY_CLIENT_SECRET", "").strip()
        if not cid or not sec:
            return None
        auth = requests.auth.HTTPBasicAuth(cid, sec)
        try:
            resp = self.session.post(
                "https://accounts.spotify.com/api/token",
                auth=auth,
                data={"grant_type": "client_credentials"},
                timeout=self.cfg.request_timeout_sec,
            )
        except Exception as e:
            self.log.write("error", "spotify_token_exception", message=str(e))
            return None
        if not resp.ok:
            self.log.write(
                "error",
                "spotify_token_non_ok",
                message=f"status={resp.status_code} body={resp.text[:200]}",
            )
            return None
        payload = resp.json()
        self.spotify_token = str(payload.get("access_token") or "")
        expires_in = float(payload.get("expires_in") or 3600)
        self.spotify_expires_at = now + max(60.0, expires_in)
        return self.spotify_token or None

    def _soundcloud_access_token(self) -> Optional[str]:
        now = time.time()
        if self.sc_token and now < self.sc_expires_at - 30:
            return self.sc_token

        cid = os.getenv("SOUNDCLOUD_CLIENT_ID", os.getenv("SoundCloud_CLIENT_ID", "")).strip()
        sec = os.getenv("SOUNDCLOUD_CLIENT_SECRET", os.getenv("SoundCloud_CLIENT_SECRET", "")).strip()
        if not cid or not sec:
            return None

        try:
            resp = self.session.post(
                "https://secure.soundcloud.com/oauth/token",
                auth=requests.auth.HTTPBasicAuth(cid, sec),
                headers={"Accept": "application/json; charset=utf-8"},
                data={"grant_type": "client_credentials"},
                timeout=self.cfg.request_timeout_sec,
            )
        except Exception as e:
            self.log.write("error", "soundcloud_token_exception", message=str(e))
            return None
        if not resp.ok:
            self.log.write(
                "error",
                "soundcloud_token_non_ok",
                message=f"status={resp.status_code} body={resp.text[:200]}",
            )
            return None
        payload = resp.json()
        self.sc_token = str(payload.get("access_token") or "")
        expires_in = float(payload.get("expires_in") or 3600)
        self.sc_expires_at = now + max(60.0, expires_in)
        return self.sc_token or None

    def fetch_spotify(self, query: str, top_n: int) -> List[Dict[str, Any]]:
        token = self._spotify_access_token()
        if not token:
            raise RuntimeError("spotify token unavailable")
        url = "https://api.spotify.com/v1/search"
        params = {"q": query, "type": "artist", "limit": str(max(1, min(20, top_n * 3)))}
        resp = self.session.get(
            url,
            params=params,
            headers={"Authorization": f"Bearer {token}"},
            timeout=self.cfg.request_timeout_sec,
        )
        if not resp.ok:
            raise RuntimeError(f"spotify search status={resp.status_code} body={resp.text[:240]}")
        items = (resp.json().get("artists") or {}).get("items") or []
        out: List[Dict[str, Any]] = []
        for row in items:
            if not isinstance(row, dict):
                continue
            images = row.get("images") if isinstance(row.get("images"), list) else []
            image_url = ""
            if images:
                try:
                    images_sorted = sorted(images, key=lambda x: int(x.get("width") or 0), reverse=True)
                    image_url = str(images_sorted[0].get("url") or "").strip()
                except Exception:
                    image_url = ""
            out.append(
                {
                    "source": "spotify",
                    "id": str(row.get("id") or "").strip(),
                    "name": str(row.get("name") or "").strip(),
                    "spotifyId": str(row.get("id") or "").strip(),
                    "spotifyUrl": str((row.get("external_urls") or {}).get("spotify") or "").strip(),
                    "followersCount": int(((row.get("followers") or {}).get("total") or 0)),
                    "popularity": int(row.get("popularity") or 0),
                    "genres": row.get("genres") if isinstance(row.get("genres"), list) else [],
                    "avatarUrl": image_url,
                }
            )
        out.sort(
            key=lambda x: (
                1 if normalize_query(x.get("name", "")) == normalize_query(query) else 0,
                int(x.get("followersCount") or 0),
                int(x.get("popularity") or 0),
            ),
            reverse=True,
        )
        return out[:top_n]

    def fetch_discogs(self, query: str, top_n: int) -> List[Dict[str, Any]]:
        token = get_discogs_token()
        if not token:
            raise RuntimeError("discogs token unavailable (DISCOGS_USER_TOKEN)")
        headers = {"Authorization": f"Discogs token={token}", "User-Agent": USER_AGENT}
        search_url = "https://api.discogs.com/database/search"
        resp = self.session.get(
            search_url,
            params={"q": query, "type": "artist", "per_page": str(max(10, top_n * 3))},
            headers=headers,
            timeout=self.cfg.request_timeout_sec,
        )
        if not resp.ok:
            raise RuntimeError(f"discogs search status={resp.status_code} body={resp.text[:240]}")
        rows = resp.json().get("results") or []
        out: List[Dict[str, Any]] = []
        for row in rows:
            if not isinstance(row, dict):
                continue
            artist_id = row.get("id")
            detail: Dict[str, Any] = {}
            if isinstance(artist_id, int) and artist_id > 0:
                try:
                    d = self.session.get(
                        f"https://api.discogs.com/artists/{artist_id}",
                        headers=headers,
                        timeout=self.cfg.request_timeout_sec,
                    )
                    if d.ok:
                        detail = d.json() if isinstance(d.json(), dict) else {}
                except Exception:
                    detail = {}
            images = detail.get("images") if isinstance(detail.get("images"), list) else []
            avatar_url = ""
            for img in images:
                if isinstance(img, dict):
                    avatar_url = str(img.get("uri") or img.get("resource_url") or "").strip()
                    if avatar_url:
                        break
            out.append(
                {
                    "source": "discogs",
                    "id": str(artist_id or "").strip(),
                    "artistId": artist_id,
                    "name": str(row.get("title") or detail.get("name") or "").strip(),
                    "aliases": [
                        str(x.get("name") or "").strip()
                        for x in (detail.get("aliases") or [])
                        if isinstance(x, dict) and str(x.get("name") or "").strip()
                    ],
                    "profile": str(detail.get("profile") or "").strip(),
                    "discogsUrl": str(detail.get("uri") or "").strip(),
                    "avatarUrl": avatar_url,
                }
            )
        out.sort(
            key=lambda x: 1 if normalize_query(x.get("name", "")) == normalize_query(query) else 0,
            reverse=True,
        )
        return out[:top_n]

    def fetch_soundcloud(self, query: str, top_n: int) -> List[Dict[str, Any]]:
        token = self._soundcloud_access_token()
        if not token:
            raise RuntimeError("soundcloud token unavailable")
        headers = {
            "Authorization": f"OAuth {token}",
            "Accept": "application/json; charset=utf-8",
        }
        resp = self.session.get(
            "https://api.soundcloud.com/users",
            params={"q": query, "limit": str(max(20, top_n * 4))},
            headers=headers,
            timeout=self.cfg.request_timeout_sec,
        )
        if not resp.ok:
            raise RuntimeError(f"soundcloud search status={resp.status_code} body={resp.text[:240]}")
        rows = resp.json() if isinstance(resp.json(), list) else []
        out: List[Dict[str, Any]] = []
        for row in rows:
            if not isinstance(row, dict):
                continue
            web_profiles: Dict[str, str] = {}
            uid = row.get("id")
            if isinstance(uid, int) and uid > 0:
                try:
                    wp = self.session.get(
                        f"https://api.soundcloud.com/users/{uid}/web-profiles",
                        headers=headers,
                        timeout=self.cfg.request_timeout_sec,
                    )
                    if wp.ok:
                        arr = wp.json() if isinstance(wp.json(), list) else []
                        for item in arr:
                            if not isinstance(item, dict):
                                continue
                            service = str(item.get("service") or "").strip().lower()
                            link = str(item.get("url") or "").strip()
                            if service and link and service not in web_profiles:
                                web_profiles[service] = link
                except Exception:
                    pass
            out.append(
                {
                    "source": "soundcloud",
                    "id": str(uid or "").strip(),
                    "soundcloudId": str(uid or "").strip(),
                    "name": str(row.get("username") or "").strip(),
                    "permalink": str(row.get("permalink") or "").strip(),
                    "soundcloudUrl": str(row.get("permalink_url") or "").strip(),
                    "avatarUrl": str(row.get("avatar_url") or "").strip(),
                    "city": str(row.get("city") or "").strip(),
                    "country": str(row.get("country") or "").strip(),
                    "description": str(row.get("description") or "").strip(),
                    "website": str(row.get("website") or "").strip(),
                    "trackCount": int(row.get("track_count") or 0),
                    "playlistCount": int(row.get("playlist_count") or 0),
                    "followersCount": int(row.get("followers_count") or 0),
                    "publicFavoritesCount": int(row.get("public_favorites_count") or 0),
                    "spotifyUrl": web_profiles.get("spotify", ""),
                    "instagramUrl": web_profiles.get("instagram", ""),
                    "facebookUrl": web_profiles.get("facebook", ""),
                    "twitterUrl": web_profiles.get("twitter", ""),
                    "youtubeUrl": web_profiles.get("youtube", ""),
                }
            )
        out.sort(
            key=lambda x: (
                1 if normalize_query(x.get("name", "")) == normalize_query(query) else 0,
                int(x.get("followersCount") or 0),
            ),
            reverse=True,
        )
        return out[:top_n]


def ensure_dirs(cfg: RuntimeConfig) -> None:
    cfg.output_root.mkdir(parents=True, exist_ok=True)
    cfg.queries_dir.mkdir(parents=True, exist_ok=True)
    cfg.avatars_dir.mkdir(parents=True, exist_ok=True)
    cfg.logs_file.parent.mkdir(parents=True, exist_ok=True)


def write_json_atomic(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def save_avatar(
    session: requests.Session,
    cfg: RuntimeConfig,
    logger: Logger,
    source: str,
    query: str,
    url: str,
) -> str:
    avatar_url = str(url or "").strip()
    if not avatar_url:
        return ""
    digest = file_sha1(avatar_url)
    # if already exists, return cached file name
    existed = sorted(cfg.avatars_dir.glob(f"{digest}.*"))
    if existed:
        return existed[0].name

    urls = [avatar_url]
    if source == "soundcloud":
        urls = soundcloud_avatar_candidates(avatar_url)

    last_err = ""
    for u in urls:
        try:
            resp = session.get(u, timeout=20)
            if not resp.ok or not resp.content:
                last_err = f"status={resp.status_code}"
                continue
            ext = infer_ext(resp.headers.get("Content-Type", ""), u)
            out = cfg.avatars_dir / f"{digest}.{ext}"
            out.write_bytes(resp.content)
            return out.name
        except Exception as e:
            last_err = str(e)
            continue
    logger.write(
        "warn",
        "avatar_cache_failed",
        query=query,
        source=source,
        message=last_err or "unknown error",
        detail={"avatarUrl": avatar_url},
    )
    return ""


def fetch_source_with_retry(
    source_key: str,
    query: str,
    client: SourceClient,
    top_n: int,
    retry_times: int,
    retry_interval_sec: float,
    logger: Logger,
) -> Tuple[str, str, List[Dict[str, Any]]]:
    """
    Returns: (status, message, items)
    status: ok | err
    """
    fn = {
        "spotify": client.fetch_spotify,
        "discogs": client.fetch_discogs,
        "soundcloud": client.fetch_soundcloud,
    }.get(source_key)
    if fn is None:
        return ("err", "unsupported source", [])

    last_err = ""
    attempts = max(1, retry_times + 1)
    for i in range(1, attempts + 1):
        try:
            items = fn(query, top_n=top_n)
            if items:
                return ("ok", f"fetched {len(items)}", items)
            last_err = "empty result"
            if i < attempts:
                logger.write(
                    "warn",
                    "source_retry_empty",
                    query=query,
                    source=source_key,
                    message=f"attempt {i}/{attempts}, retry in {retry_interval_sec}s",
                )
                time.sleep(retry_interval_sec)
        except Exception as e:
            last_err = str(e)
            if i < attempts:
                logger.write(
                    "warn",
                    "source_retry_error",
                    query=query,
                    source=source_key,
                    message=f"attempt {i}/{attempts}: {last_err}, retry in {retry_interval_sec}s",
                )
                time.sleep(retry_interval_sec)
    return ("err", last_err or "fetch failed", [])


def build_cache_record(
    query: str,
    normalized_query: str,
    sources: Dict[str, Dict[str, Any]],
) -> Dict[str, Any]:
    return {
        "cacheKey": f"query:{normalized_query}",
        "query": query,
        "normalizedQuery": normalized_query,
        "schemaVersion": 1,
        "updatedAt": now_ms(),
        "sources": sources,
    }


def run_prefetch(
    names: List[str],
    cfg: RuntimeConfig,
    enabled_sources: Iterable[str],
    zip_output: bool,
    global_offset: int = 0,
    global_total: Optional[int] = None,
) -> Dict[str, Any]:
    ensure_dirs(cfg)
    logger = Logger(cfg.logs_file, verbose=True)
    client = SourceClient(cfg, logger)

    enabled = [k for k in SOURCE_KEYS if k in set(enabled_sources)]
    total = len(names)
    total_global = int(global_total if global_total is not None else total)
    summary = {
        "startedAt": now_ms(),
        "finishedAt": None,
        "totals": {
            "targetNames": total,
            "processed": 0,
            "success": 0,
            "partial": 0,
            "errored": 0,
            "skipped": 0,
        },
        "rows": [],
        "outputRoot": str(cfg.output_root),
        "zipPath": "",
    }

    for idx, name in enumerate(names, start=1):
        query = str(name or "").strip()
        normalized = normalize_query(query)
        if not normalized:
            summary["totals"]["skipped"] += 1
            continue

        global_index = global_offset + idx
        logger.write(
            "info",
            "prefetch_dj_start",
            query=query,
            message=f"{global_index}/{total_global}",
            detail={
                "index": idx,
                "total": total,
                "globalIndex": global_index,
                "globalTotal": total_global,
                "djName": query,
            },
        )

        source_groups: Dict[str, Dict[str, Any]] = {}
        failed_sources: List[Dict[str, str]] = []
        source_counts = {"spotify": 0, "discogs": 0, "soundcloud": 0}

        for source_key in SOURCE_KEYS:
            if source_key not in enabled:
                source_groups[source_key] = {
                    "status": "idle",
                    "message": "disabled",
                    "fetchedAt": now_ms(),
                    "items": [],
                    "selectedIndex": -1,
                }
                continue

            status, message, items = fetch_source_with_retry(
                source_key=source_key,
                query=query,
                client=client,
                top_n=cfg.top_n,
                retry_times=cfg.retry_times,
                retry_interval_sec=cfg.retry_interval_sec,
                logger=logger,
            )

            safe_items: List[Dict[str, Any]] = []
            for item in items[: cfg.top_n]:
                candidate = json.loads(json.dumps(item, ensure_ascii=False))
                avatar_url = str(candidate.get("avatarUrl") or "").strip()
                if avatar_url:
                    cached_name = save_avatar(
                        session=client.session,
                        cfg=cfg,
                        logger=logger,
                        source=source_key,
                        query=query,
                        url=avatar_url,
                    )
                    if cached_name:
                        candidate["avatarCachedFile"] = cached_name
                safe_items.append(candidate)

            source_counts[source_key] = len(safe_items) if status == "ok" else 0
            if status != "ok":
                failed_sources.append({"source": source_key, "reason": message})

            source_groups[source_key] = {
                "status": status,
                "message": message,
                "fetchedAt": now_ms(),
                "items": safe_items,
                "selectedIndex": 0 if safe_items else -1,
            }

        record = build_cache_record(query=query, normalized_query=normalized, sources=source_groups)
        record_path = cfg.queries_dir / f"{query_sha1(normalized)}.json"
        write_json_atomic(record_path, record)

        status = "ok"
        if failed_sources and all(source_counts[k] == 0 for k in source_counts):
            status = "err"
            summary["totals"]["errored"] += 1
        elif failed_sources:
            status = "partial"
            summary["totals"]["partial"] += 1
        else:
            summary["totals"]["success"] += 1

        summary["totals"]["processed"] += 1
        logger.write(
            "warn" if failed_sources else "info",
            "prefetch_dj_result",
            query=query,
            message=(
                f"第 {global_index}/{total_global} 个 DJ：{query} | "
                f"Spotify={source_counts['spotify']} 条 | "
                f"Discogs={source_counts['discogs']} 条 | "
                f"SoundCloud={source_counts['soundcloud']} 条 | "
                f"失败源："
                + (
                    ", ".join([f"{x['source']}({x['reason']})" for x in failed_sources])
                    if failed_sources
                    else "无"
                )
            ),
            detail={
                "index": idx,
                "total": total,
                "globalIndex": global_index,
                "globalTotal": total_global,
                "djName": query,
                "status": status,
                "sourceCounts": source_counts,
                "failedSources": failed_sources,
                "queryFile": str(record_path),
            },
        )
        summary["rows"].append(
            {
                "index": idx,
                "globalIndex": global_index,
                "djName": query,
                "status": status,
                "sourceCounts": source_counts,
                "failedSources": failed_sources,
                "queryFile": str(record_path),
            }
        )

        if idx < total and cfg.dj_interval_sec > 0:
            time.sleep(cfg.dj_interval_sec)

    summary["finishedAt"] = now_ms()
    summary_path = cfg.output_root / "summary.json"
    write_json_atomic(summary_path, summary)

    if zip_output:
        zip_path = cfg.output_root.parent / f"{cfg.output_root.name}.zip"
        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for p in cfg.output_root.rglob("*"):
                if p.is_file():
                    zf.write(p, arcname=str(p.relative_to(cfg.output_root.parent)))
        summary["zipPath"] = str(zip_path)
        write_json_atomic(summary_path, summary)

    return summary


def dump_env_status(output_root: Path) -> Path:
    status = {
        "SPOTIFY_CLIENT_ID": bool(os.getenv("SPOTIFY_CLIENT_ID")),
        "SPOTIFY_CLIENT_SECRET": bool(os.getenv("SPOTIFY_CLIENT_SECRET")),
        "DISCOGS_USER_TOKEN": bool(os.getenv("DISCOGS_USER_TOKEN")),
        "DISCOGS_TOKEN": bool(os.getenv("DISCOGS_TOKEN")),
        "SOUNDCLOUD_CLIENT_ID": bool(
            os.getenv("SOUNDCLOUD_CLIENT_ID") or os.getenv("SoundCloud_CLIENT_ID")
        ),
        "SOUNDCLOUD_CLIENT_SECRET": bool(
            os.getenv("SOUNDCLOUD_CLIENT_SECRET") or os.getenv("SoundCloud_CLIENT_SECRET")
        ),
    }
    p = output_root / "env_status.json"
    write_json_atomic(p, status)
    return p


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description="Colab-friendly DJ source prefetch exporter")
    ap.add_argument(
        "--env-file",
        type=str,
        default="",
        help="optional env file path (KEY=VALUE per line), useful in Colab upload",
    )
    ap.add_argument("--brands-root", type=str, default="brands", help="brands root path")
    ap.add_argument(
        "--names-file",
        type=str,
        default="",
        help="optional DJ list file (txt/csv/json). If empty, extract from brands lineup.",
    )
    ap.add_argument("--output-root", type=str, default="dj_source_cache_export", help="output folder")
    ap.add_argument("--top-n", type=int, default=3, help="max candidates per source")
    ap.add_argument("--dj-interval-sec", type=float, default=5.0, help="sleep seconds between DJs")
    ap.add_argument("--retry-interval-sec", type=float, default=2.0, help="retry interval per source")
    ap.add_argument("--retry-times", type=int, default=1, help="retry times per source")
    ap.add_argument("--request-timeout-sec", type=float, default=20.0, help="http timeout seconds")
    ap.add_argument(
        "--sources",
        type=str,
        default="spotify,discogs,soundcloud",
        help="comma list from spotify,discogs,soundcloud",
    )
    ap.add_argument("--export-only-names", action="store_true", help="only export DJ names, no source fetch")
    ap.add_argument("--zip", action="store_true", help="zip output folder when done")
    ap.add_argument(
        "--start-index",
        type=int,
        default=1,
        help="1-based inclusive start index for names-file processing (for resume)",
    )
    ap.add_argument(
        "--end-index",
        type=int,
        default=0,
        help="1-based inclusive end index (0 means process to the end)",
    )
    ap.add_argument(
        "--chunk-size",
        type=int,
        default=500,
        help="package every N DJs into one zip (default: 500)",
    )
    ap.add_argument(
        "--auto-download",
        action="store_true",
        help="in Colab, auto trigger files.download for every chunk zip",
    )
    return ap.parse_args()


def main() -> None:
    args = parse_args()

    if args.env_file:
        env_file_path = Path(args.env_file).resolve()
        if not env_file_path.exists():
            raise SystemExit(f"env file not found: {env_file_path}")
        loaded = load_env_file(env_file_path)
        print(f"[env] loaded {len(loaded)} keys from {env_file_path}")

    output_root = Path(args.output_root).resolve()
    output_root.mkdir(parents=True, exist_ok=True)

    names: List[str]
    if args.names_file:
        names = load_names_from_file(Path(args.names_file).resolve(), split_collab=False)
    else:
        names = extract_names_from_brands(Path(args.brands_root).resolve())
    original_total = len(names)
    start_index = max(1, int(args.start_index))
    end_index = int(args.end_index) if int(args.end_index) > 0 else original_total
    end_index = min(max(1, end_index), original_total) if original_total > 0 else 0
    if original_total > 0:
        if start_index > end_index:
            names = []
        else:
            names = names[start_index - 1 : end_index]
    else:
        names = []

    names_path = output_root / "dj_names.json"
    write_json_atomic(
        names_path,
        {
            "count": len(names),
            "originalCount": original_total,
            "startIndex": start_index,
            "endIndex": end_index,
            "names": names,
        },
    )

    # env status (presence only, no secret values)
    dump_env_status(output_root)

    if args.export_only_names:
        print(f"[done] exported names only: {len(names)} -> {names_path}")
        return

    if requests is None:
        raise SystemExit("Missing dependency: requests. Install with `pip install requests`.")

    cfg = RuntimeConfig(
        output_root=output_root,
        queries_dir=output_root / "queries",
        avatars_dir=output_root / "avatars",
        logs_file=output_root / "logs.ndjson",
        top_n=max(1, int(args.top_n)),
        dj_interval_sec=max(0.0, float(args.dj_interval_sec)),
        retry_interval_sec=max(0.0, float(args.retry_interval_sec)),
        retry_times=max(0, int(args.retry_times)),
        request_timeout_sec=max(5.0, float(args.request_timeout_sec)),
    )
    enabled_sources = [x.strip().lower() for x in str(args.sources).split(",") if x.strip()]
    enabled_sources = [x for x in enabled_sources if x in SOURCE_KEYS]
    if not enabled_sources:
        raise SystemExit("No valid sources enabled. Use --sources spotify,discogs,soundcloud")
    source_cred = get_source_credential_status()
    discogs_key, discogs_token = get_discogs_token_with_key()
    if discogs_token:
        print(f"[env] discogs token detected from key={discogs_key} len={len(discogs_token)}")
    else:
        print("[env] discogs token NOT detected (checked common keys + case-insensitive scan)")
        hint_keys = sorted([k for k in os.environ.keys() if "discogs" in str(k).lower()])
        if hint_keys:
            print(f"[env] found related env keys: {hint_keys}")
    auto_disabled: List[str] = []
    effective_sources: List[str] = []
    for source_key in enabled_sources:
        if source_cred.get(source_key):
            effective_sources.append(source_key)
        else:
            auto_disabled.append(source_key)
    if auto_disabled:
        print(f"[warn] auto-disabled sources due missing credentials: {', '.join(auto_disabled)}")
    enabled_sources = effective_sources
    if not enabled_sources:
        raise SystemExit("All requested sources are disabled due missing credentials.")
    chunk_size = max(1, int(args.chunk_size))
    if chunk_size <= 0:
        chunk_size = 500

    auto_download = bool(args.auto_download)

    chunks_root = output_root / "chunks"
    chunks_root.mkdir(parents=True, exist_ok=True)
    global_summary: Dict[str, Any] = {
        "startedAt": now_ms(),
        "finishedAt": None,
        "config": {
            "originalNameCount": original_total,
            "selectedNameCount": len(names),
            "startIndex": start_index,
            "endIndex": end_index,
            "chunkSize": chunk_size,
            "topN": cfg.top_n,
            "djIntervalSec": cfg.dj_interval_sec,
            "retryTimes": cfg.retry_times,
            "retryIntervalSec": cfg.retry_interval_sec,
            "sources": enabled_sources,
            "autoDisabledSources": auto_disabled,
            "autoDownload": auto_download,
        },
        "totals": {
            "targetNames": len(names),
            "processed": 0,
            "success": 0,
            "partial": 0,
            "errored": 0,
            "skipped": 0,
            "chunks": 0,
        },
        "chunks": [],
    }

    for chunk_idx, start in enumerate(range(0, len(names), chunk_size), start=1):
        end = min(len(names), start + chunk_size)
        chunk_names = names[start:end]
        chunk_label = f"chunk_{chunk_idx:04d}_{start + 1}-{end}"
        chunk_output = chunks_root / chunk_label
        chunk_cfg = RuntimeConfig(
            output_root=chunk_output,
            queries_dir=chunk_output / "queries",
            avatars_dir=chunk_output / "avatars",
            logs_file=chunk_output / "logs.ndjson",
            top_n=cfg.top_n,
            dj_interval_sec=cfg.dj_interval_sec,
            retry_interval_sec=cfg.retry_interval_sec,
            retry_times=cfg.retry_times,
            request_timeout_sec=cfg.request_timeout_sec,
        )

        print(
            f"[chunk] start {chunk_idx} | DJs {start + 1}-{end}/{len(names)} | output={chunk_output}"
        )
        chunk_summary = run_prefetch(
            names=chunk_names,
            cfg=chunk_cfg,
            enabled_sources=enabled_sources,
            zip_output=True,
            global_offset=start,
            global_total=len(names),
        )

        totals = chunk_summary.get("totals", {})
        global_summary["totals"]["processed"] += int(totals.get("processed") or 0)
        global_summary["totals"]["success"] += int(totals.get("success") or 0)
        global_summary["totals"]["partial"] += int(totals.get("partial") or 0)
        global_summary["totals"]["errored"] += int(totals.get("errored") or 0)
        global_summary["totals"]["skipped"] += int(totals.get("skipped") or 0)
        global_summary["totals"]["chunks"] += 1

        zip_path = str(chunk_summary.get("zipPath") or "")
        chunk_record: Dict[str, Any] = {
            "chunkIndex": chunk_idx,
            "startIndex": start + 1,
            "endIndex": end,
            "nameCount": len(chunk_names),
            "outputRoot": str(chunk_output),
            "zipPath": zip_path,
            "totals": totals,
        }

        if auto_download and zip_path:
            ok, err = colab_download_file(Path(zip_path))
            chunk_record["downloadTriggered"] = ok
            chunk_record["downloadError"] = err
            if ok:
                print(f"[chunk] download triggered: {zip_path}")
            else:
                print(f"[chunk] download failed: {zip_path} | {err}")

        global_summary["chunks"].append(chunk_record)
        # write rolling summary after every chunk
        write_json_atomic(output_root / "summary_global.json", global_summary)

    global_summary["finishedAt"] = now_ms()
    write_json_atomic(output_root / "summary_global.json", global_summary)
    print("[done] global summary:")
    print(json.dumps(global_summary.get("totals", {}), ensure_ascii=False, indent=2))
    print(f"[done] output root: {output_root}")


if __name__ == "__main__":
    main()
