#!/usr/bin/env python3
"""
Auto-import unmatched archive timetable DJs into DJ DB from local source cache.

Rules:
1) Only process DJs that are currently unmatched in archive timetable.
2) For each unmatched DJ name, look up cache query by exact normalized name
   (case-insensitive exact, same normalization as viewer/export script).
3) Keep only candidates whose name is exact-match (case-insensitive).
4) If multiple exact candidates exist, choose the one with max followers.
   (and record a log entry for multi-candidate resolution)
5) Call /v1/djs/manual/import to create/update DJ DB records.

Usage example:
  python3 scrapRave/auto_import_unmatched_djs_from_cache.py \
    --bff-base http://127.0.0.1:3001 \
    --username uploadtester \
    --password 123456
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import re
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse, parse_qs, unquote
from urllib.request import Request, urlopen

from export_unmatched_timetable_djs import (
    build_dj_maps,
    collect_unmatched_names,
    fetch_all_djs_from_bff,
    normalize_name_key,
)


USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_BRANDS_ROOT = SCRIPT_DIR / "brands"
DEFAULT_CACHE_ROOT = SCRIPT_DIR / "web_tool" / ".cache" / "dj_source_cache"
DEFAULT_REPORT_DIR = SCRIPT_DIR / "tmp_unmatched_export"


def now_ms() -> int:
    return int(time.time() * 1000)


def read_json(path: Path) -> Optional[Dict[str, Any]]:
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    return obj if isinstance(obj, dict) else None


def write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def append_ndjson(path: Path, row: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def as_list(value: Any) -> List[Any]:
    return value if isinstance(value, list) else []


def first_non_empty(*values: Any) -> str:
    for value in values:
        text = str(value or "").strip()
        if text:
            return text
    return ""


def parse_non_negative_int(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, (int, float)):
        if value < 0:
            return None
        return int(value)
    text = str(value).strip()
    if not text:
        return None
    try:
        num = float(text)
    except Exception:
        return None
    if num < 0:
        return None
    return int(num)


def payload_has_non_empty_key(obj: Dict[str, Any], keys: Sequence[str]) -> bool:
    for key in keys:
        if key in obj:
            value = obj.get(key)
            if isinstance(value, str):
                if value.strip():
                    return True
            elif value is not None:
                return True
    return False


def get_nested(obj: Any, path: Sequence[Any]) -> Any:
    cur = obj
    for key in path:
        if isinstance(cur, dict):
            cur = cur.get(key)
            continue
        if isinstance(cur, list) and isinstance(key, int):
            if 0 <= key < len(cur):
                cur = cur[key]
                continue
            return None
        return None
    return cur


def normalize_string_list(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, list):
        out: List[str] = []
        for item in value:
            text = str(item or "").strip()
            if text:
                out.append(text)
        return out
    text = str(value).strip()
    if not text:
        return []
    return [x.strip() for x in re.split(r"[\n,，、|;/]+", text) if x.strip()]


def cache_query_file_for_name(cache_queries_dir: Path, name: str) -> Path:
    normalized = normalize_name_key(name)
    digest = hashlib.sha1(normalized.encode("utf-8")).hexdigest()
    return cache_queries_dir / f"{digest}.json"


def load_cache_record_for_name(cache_queries_dir: Path, name: str) -> Optional[Dict[str, Any]]:
    path = cache_query_file_for_name(cache_queries_dir, name)
    if not path.exists():
        return None
    return read_json(path)


def extract_spotify_artist_id(value: Any) -> str:
    raw = str(value or "").strip()
    if not raw:
        return ""

    def pick(text: str) -> str:
        text = str(text or "").strip()
        if not text:
            return ""
        m = re.search(r"spotify:artist:([A-Za-z0-9]{10,64})", text, flags=re.I)
        if m:
            return m.group(1)
        m = re.search(r"/artist/([A-Za-z0-9]{10,64})", text, flags=re.I)
        if m:
            return m.group(1)
        return ""

    got = pick(raw)
    if got:
        return got

    decoded = raw
    for _ in range(3):
        try:
            nxt = unquote(decoded)
        except Exception:
            break
        if nxt == decoded:
            break
        decoded = nxt
        got = pick(decoded)
        if got:
            return got

    try:
        maybe_url = raw if re.match(r"^https?://", raw, flags=re.I) else f"https://{raw}"
        parsed = urlparse(maybe_url)
        got = pick(parsed.path or "")
        if got:
            return got
        query_map = parse_qs(parsed.query or "")
        for key in ("uri", "spotify_uri", "spotify"):
            for candidate in query_map.get(key, []):
                got = pick(candidate)
                if got:
                    return got
        for key in ("artist", "artist_id", "spotifyArtistId"):
            for candidate in query_map.get(key, []):
                value = str(candidate or "").strip()
                if re.fullmatch(r"[A-Za-z0-9]{10,64}", value):
                    return value
    except Exception:
        return ""
    return ""


def collect_service_profiles(candidate: Dict[str, Any]) -> List[Dict[str, Any]]:
    profiles: List[Dict[str, Any]] = []
    raw = candidate.get("raw")

    def append_all(value: Any) -> None:
        if isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    profiles.append(item)

    append_all(candidate.get("webProfiles"))
    append_all(candidate.get("web_profiles"))
    if isinstance(raw, dict):
        append_all(raw.get("webProfiles"))
        append_all(raw.get("web_profiles"))
        user = raw.get("user")
        if isinstance(user, dict):
            append_all(user.get("webProfiles"))
            append_all(user.get("web_profiles"))
    return profiles


def pick_service_url(profiles: Sequence[Dict[str, Any]], services: Sequence[str]) -> str:
    target = {str(s or "").strip().lower() for s in services if str(s or "").strip()}
    if not target:
        return ""
    for profile in profiles:
        service = str(profile.get("service") or profile.get("type") or "").strip().lower()
        url = first_non_empty(profile.get("url"), profile.get("href"), profile.get("link"))
        if service in target and url:
            return url
    return ""


def candidate_name(candidate: Dict[str, Any]) -> str:
    raw = candidate.get("raw")
    return first_non_empty(
        candidate.get("name"),
        candidate.get("username"),
        candidate.get("title"),
        get_nested(raw, ["user", "username"]),
        get_nested(raw, ["artistDetail", "name"]),
        get_nested(raw, ["searchItem", "title"]),
    )


def candidate_followers(candidate: Dict[str, Any]) -> int:
    raw = candidate.get("raw")
    values = [
        candidate.get("spotifyFollowers"),
        candidate.get("followers"),
        candidate.get("followersCount"),
        candidate.get("followers_count"),
        candidate.get("soundCloudFollowers"),
        candidate.get("soundcloudFollowers"),
        get_nested(raw, ["followers", "total"]),
        get_nested(raw, ["user", "followers_count"]),
        get_nested(raw, ["followers_count"]),
    ]
    nums = [parse_non_negative_int(v) for v in values]
    valid = [n for n in nums if n is not None]
    return max(valid) if valid else 0


def candidate_has_avatar(candidate: Dict[str, Any]) -> bool:
    return bool(
        first_non_empty(
            candidate.get("avatarUrl"),
            candidate.get("avatar_url"),
            candidate.get("imageUrl"),
            candidate.get("primaryImageUrl"),
            candidate.get("thumbnailImageUrl"),
            candidate.get("thumbUrl"),
            candidate.get("coverImageUrl"),
            get_nested(candidate.get("raw"), ["user", "avatar_url"]),
            get_nested(candidate.get("raw"), ["images", 0, "url"]),
        )
    )


def candidate_source_priority(source_key: str) -> int:
    return {"spotify": 3, "soundcloud": 2, "discogs": 1}.get(str(source_key or "").lower(), 0)


def iter_cache_candidates(cache_record: Dict[str, Any]) -> List[Tuple[str, Dict[str, Any]]]:
    out: List[Tuple[str, Dict[str, Any]]] = []
    sources = cache_record.get("sources")
    if not isinstance(sources, dict):
        return out
    for source_key in ("spotify", "discogs", "soundcloud"):
        group = sources.get(source_key)
        items = group.get("items") if isinstance(group, dict) else []
        if not isinstance(items, list):
            continue
        for item in items:
            if isinstance(item, dict):
                out.append((source_key, item))
    return out


def choose_best_exact_candidate(
    target_name: str,
    cache_record: Dict[str, Any],
) -> Tuple[Optional[Tuple[str, Dict[str, Any]]], List[Dict[str, Any]]]:
    target_key = normalize_name_key(target_name)
    matches: List[Tuple[str, Dict[str, Any]]] = []
    for source_key, candidate in iter_cache_candidates(cache_record):
        if normalize_name_key(candidate_name(candidate)) == target_key:
            matches.append((source_key, candidate))

    if not matches:
        return None, []

    def rank(entry: Tuple[str, Dict[str, Any]]) -> Tuple[int, int, int, int]:
        source_key, candidate = entry
        followers = candidate_followers(candidate)
        source_rank = candidate_source_priority(source_key)
        has_avatar = 1 if candidate_has_avatar(candidate) else 0
        has_bio = 1 if first_non_empty(candidate.get("bio"), candidate.get("profile"), candidate.get("description")) else 0
        return (followers, source_rank, has_avatar, has_bio)

    sorted_matches = sorted(matches, key=rank, reverse=True)
    best = sorted_matches[0]
    details: List[Dict[str, Any]] = []
    for source_key, candidate in sorted_matches:
        details.append(
            {
                "source": source_key,
                "name": candidate_name(candidate),
                "sourceId": first_non_empty(
                    candidate.get("sourceId"),
                    candidate.get("id"),
                    candidate.get("artistId"),
                    candidate.get("soundcloudId"),
                    candidate.get("soundcloudid"),
                    candidate.get("spotifyId"),
                ),
                "followers": candidate_followers(candidate),
                "hasAvatar": candidate_has_avatar(candidate),
            }
        )
    return best, details


def build_import_payload(target_name: str, source_key: str, candidate: Dict[str, Any]) -> Dict[str, Any]:
    raw = candidate.get("raw")
    profiles = collect_service_profiles(candidate)

    spotify_url = first_non_empty(
        candidate.get("spotifyUrl"),
        get_nested(raw, ["external_urls", "spotify"]),
        pick_service_url(profiles, ["spotify"]),
    )
    spotify_id = first_non_empty(
        candidate.get("spotifyId"),
        candidate.get("spotifyID"),
        extract_spotify_artist_id(spotify_url),
    )

    instagram_url = first_non_empty(candidate.get("instagramUrl"), pick_service_url(profiles, ["instagram"]))
    facebook_url = first_non_empty(candidate.get("facebookUrl"), pick_service_url(profiles, ["facebook"]))
    twitter_url = first_non_empty(candidate.get("twitterUrl"), pick_service_url(profiles, ["twitter", "x"]))
    youtube_url = first_non_empty(candidate.get("youtubeUrl"), pick_service_url(profiles, ["youtube"]))
    website = first_non_empty(
        candidate.get("website"),
        candidate.get("websiteUrl"),
        pick_service_url(profiles, ["personal"]),
        get_nested(raw, ["user", "website"]),
    )
    soundcloud_url = first_non_empty(
        candidate.get("soundcloudUrl"),
        candidate.get("permalinkUrl"),
        candidate.get("permalink_url"),
        pick_service_url(profiles, ["soundcloud"]),
        get_nested(raw, ["user", "permalink_url"]),
    )
    soundcloud_id = first_non_empty(
        candidate.get("soundcloudId"),
        candidate.get("soundcloudid"),
        candidate.get("sourceId"),
        candidate.get("id"),
        get_nested(raw, ["user", "id"]),
    )

    track_count = parse_non_negative_int(
        first_non_empty(candidate.get("trackCount"), candidate.get("track_count"), get_nested(raw, ["user", "track_count"]))
    )
    playlist_count = parse_non_negative_int(
        first_non_empty(candidate.get("playlistCount"), candidate.get("playlist_count"), get_nested(raw, ["user", "playlist_count"]))
    )
    soundcloud_followers = parse_non_negative_int(
        first_non_empty(
            candidate.get("soundCloudFollowers"),
            candidate.get("soundcloudFollowers"),
            candidate.get("followersCount"),
            candidate.get("followers_count"),
            get_nested(raw, ["user", "followers_count"]),
        )
    )
    soundcloud_favorites = parse_non_negative_int(
        first_non_empty(
            candidate.get("soundCloudFavorites"),
            candidate.get("soundcloudFavorites"),
            candidate.get("publicFavoritesCount"),
            candidate.get("public_favorites_count"),
            get_nested(raw, ["user", "public_favorites_count"]),
        )
    )
    spotify_followers = parse_non_negative_int(
        first_non_empty(candidate.get("spotifyFollowers"), get_nested(raw, ["followers", "total"]))
    )

    candidate_primary_name = candidate_name(candidate)
    final_name = candidate_primary_name if normalize_name_key(candidate_primary_name) == normalize_name_key(target_name) else target_name

    payload: Dict[str, Any] = {
        "name": final_name,
        "aliases": normalize_string_list(candidate.get("aliases")),
        "genres": normalize_string_list(candidate.get("genres")),
        "bio": first_non_empty(
            candidate.get("bio"),
            candidate.get("profile"),
            candidate.get("description"),
            get_nested(raw, ["artistDetail", "profile"]),
            get_nested(raw, ["user", "description"]),
        ),
        "country": first_non_empty(candidate.get("country"), get_nested(raw, ["user", "country"])),
        "website": website,
        "spotifyId": spotify_id,
        "spotifyFollowers": spotify_followers,
        "instagramUrl": instagram_url,
        "facebookUrl": facebook_url,
        "soundcloudUrl": soundcloud_url,
        "soundcloudId": soundcloud_id,
        "trackCount": track_count,
        "playlistCount": playlist_count,
        "soundCloudFollowers": soundcloud_followers,
        "soundCloudFavorites": soundcloud_favorites,
        "twitterUrl": twitter_url,
        "youtubeUrl": youtube_url,
        "isVerified": True,
    }

    # Keep payload concise and avoid sending null/empty arrays when not needed.
    if not payload["aliases"]:
        payload["aliases"] = []
    if not payload["genres"]:
        payload["genres"] = []
    if not payload_has_non_empty_key(payload, ["bio"]):
        payload["bio"] = ""
    if not payload_has_non_empty_key(payload, ["country"]):
        payload["country"] = ""
    if not payload_has_non_empty_key(payload, ["website"]):
        payload["website"] = ""
    if not payload_has_non_empty_key(payload, ["spotifyId"]):
        payload["spotifyId"] = ""
    if not payload_has_non_empty_key(payload, ["instagramUrl"]):
        payload["instagramUrl"] = ""
    if not payload_has_non_empty_key(payload, ["facebookUrl"]):
        payload["facebookUrl"] = ""
    if not payload_has_non_empty_key(payload, ["soundcloudUrl"]):
        payload["soundcloudUrl"] = ""
    if not payload_has_non_empty_key(payload, ["soundcloudId"]):
        payload["soundcloudId"] = ""
    if not payload_has_non_empty_key(payload, ["twitterUrl"]):
        payload["twitterUrl"] = ""
    if not payload_has_non_empty_key(payload, ["youtubeUrl"]):
        payload["youtubeUrl"] = ""

    # Attach metadata for report readability (not sent to API).
    payload["_meta"] = {
        "selectedSource": source_key,
        "selectedFollowers": candidate_followers(candidate),
    }
    return payload


def guess_content_type(file_name: str, fallback: str = "image/jpeg") -> str:
    guessed, _ = mimetypes.guess_type(file_name)
    if guessed:
        return guessed
    return fallback


def replace_soundcloud_avatar_variant(url: str, variant: str) -> str:
    base = str(url or "").strip()
    if not base:
        return ""
    if "sndcdn.com/avatars-" not in base.lower():
        return ""
    try:
        parsed = urlparse(base)
        replaced = re.sub(
            r"-(?:tiny|small|large|t\d+x\d+|crop|original)\.(jpe?g|png|webp)$",
            rf"-{variant}.\1",
            parsed.path or "",
            flags=re.I,
        )
        if not replaced or replaced == (parsed.path or ""):
            return ""
        return parsed._replace(path=replaced).geturl()
    except Exception:
        return ""


def build_avatar_fetch_candidates(url: str) -> List[str]:
    base = str(url or "").strip()
    if not base:
        return []
    if "sndcdn.com/avatars-" in base.lower():
        variants = [
            replace_soundcloud_avatar_variant(base, "original"),
            replace_soundcloud_avatar_variant(base, "t500x500"),
            base,
        ]
        out: List[str] = []
        for item in variants:
            text = str(item or "").strip()
            if text and text not in out:
                out.append(text)
        return out
    return [base]


def candidate_avatar_url(candidate: Dict[str, Any]) -> str:
    raw = candidate.get("raw")
    images = get_nested(raw, ["images"])
    first_image_url = ""
    if isinstance(images, list):
        for img in images:
            if isinstance(img, dict):
                url = first_non_empty(img.get("url"), img.get("uri"), img.get("resource_url"))
                if url:
                    first_image_url = url
                    break
    return first_non_empty(
        candidate.get("avatarUrl"),
        candidate.get("avatar_url"),
        candidate.get("imageUrl"),
        candidate.get("primaryImageUrl"),
        candidate.get("thumbnailImageUrl"),
        candidate.get("thumbUrl"),
        candidate.get("coverImageUrl"),
        candidate.get("avatarDisplayUrl"),
        get_nested(raw, ["user", "avatar_url"]),
        first_image_url,
    )


def try_read_local_cached_avatar(cache_root: Path, candidate: Dict[str, Any]) -> Optional[Tuple[bytes, str, str, str]]:
    avatars_dir = cache_root / "avatars"
    if not avatars_dir.exists():
        return None

    avatar_cached_file = str(candidate.get("avatarCachedFile") or "").strip()
    if avatar_cached_file:
        p = avatars_dir / avatar_cached_file
        if p.exists() and p.is_file():
            data = p.read_bytes()
            return data, p.name, guess_content_type(p.name), "avatarCachedFile"

    avatar_display = str(candidate.get("avatarDisplayUrl") or "").strip()
    if avatar_display:
        m = re.search(r"/api/dj-source-cache/avatar/([A-Za-z0-9_.-]+)$", avatar_display)
        if m:
            p = avatars_dir / m.group(1)
            if p.exists() and p.is_file():
                data = p.read_bytes()
                return data, p.name, guess_content_type(p.name), "avatarDisplayUrl(local)"
    return None


def download_avatar_bytes_single(url: str, timeout_sec: int) -> Optional[Tuple[bytes, str, str, str]]:
    candidate_url = str(url or "").strip()
    if not candidate_url:
        return None
    try:
        req = Request(candidate_url, headers={"User-Agent": USER_AGENT, "Accept": "*/*"})
        with urlopen(req, timeout=timeout_sec) as resp:
            data = resp.read()
            ctype = str(resp.headers.get("Content-Type") or "").split(";")[0].strip() or "image/jpeg"
        if not data:
            return None
        path = urlparse(candidate_url).path or ""
        ext = Path(path).suffix
        if not ext:
            ext = mimetypes.guess_extension(ctype) or ".jpg"
        file_name = f"avatar{ext}"
        return data, file_name, ctype, candidate_url
    except Exception:
        return None


def download_avatar_bytes(url: str, timeout_sec: int) -> Optional[Tuple[bytes, str, str, str]]:
    for candidate_url in build_avatar_fetch_candidates(url):
        hit = download_avatar_bytes_single(candidate_url, timeout_sec=timeout_sec)
        if hit:
            return hit
    return None


def resolve_candidate_avatar_blob(
    cache_root: Path,
    candidate: Dict[str, Any],
    timeout_sec: int,
) -> Optional[Tuple[bytes, str, str, str]]:
    local = try_read_local_cached_avatar(cache_root, candidate)
    if local:
        return local
    avatar_url = candidate_avatar_url(candidate)
    if not avatar_url:
        return None
    return download_avatar_bytes(avatar_url, timeout_sec=timeout_sec)


def build_multipart_form_body(
    fields: Dict[str, str],
    file_field: str,
    file_name: str,
    file_bytes: bytes,
    content_type: str,
) -> Tuple[bytes, str]:
    boundary = f"----raverBoundary{os.urandom(12).hex()}"
    lines: List[bytes] = []
    for key, value in fields.items():
        lines.append(f"--{boundary}\r\n".encode("utf-8"))
        lines.append(
            f'Content-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode("utf-8")
        )
    safe_name = re.sub(r'["\r\n]+', "_", file_name or "avatar.jpg")
    lines.append(f"--{boundary}\r\n".encode("utf-8"))
    lines.append(
        (
            f'Content-Disposition: form-data; name="{file_field}"; filename="{safe_name}"\r\n'
            f"Content-Type: {content_type}\r\n\r\n"
        ).encode("utf-8")
    )
    lines.append(file_bytes)
    lines.append(b"\r\n")
    lines.append(f"--{boundary}--\r\n".encode("utf-8"))
    return b"".join(lines), boundary


def upload_dj_avatar(
    base_url: str,
    bearer_token: str,
    dj_id: str,
    file_name: str,
    file_bytes: bytes,
    content_type: str,
    timeout_sec: int,
) -> Dict[str, Any]:
    url = f"{base_url.rstrip('/')}/v1/djs/upload-image"
    fields = {"djId": str(dj_id), "usage": "avatar"}
    body, boundary = build_multipart_form_body(
        fields=fields,
        file_field="image",
        file_name=file_name,
        file_bytes=file_bytes,
        content_type=content_type,
    )
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
        "Content-Type": f"multipart/form-data; boundary={boundary}",
    }
    token = str(bearer_token or "").strip()
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = Request(url, data=body, headers=headers, method="POST")
    try:
        with urlopen(req, timeout=timeout_sec) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            parsed = json.loads(text) if text else {}
            if isinstance(parsed, dict):
                return parsed
            return {"data": parsed}
    except HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"upload avatar failed ({exc.code}): {raw}") from exc
    except URLError as exc:
        raise RuntimeError(f"upload avatar network error: {exc}") from exc


def upload_candidate_avatar_with_fallback(
    base_url: str,
    bearer_token: str,
    dj_id: str,
    cache_root: Path,
    candidate: Dict[str, Any],
    timeout_sec: int,
) -> Tuple[Dict[str, Any], str]:
    primary = resolve_candidate_avatar_blob(
        cache_root=cache_root,
        candidate=candidate,
        timeout_sec=timeout_sec,
    )
    if not primary:
        raise RuntimeError("no avatar source")

    file_bytes, file_name, content_type, source_label = primary
    try:
        resp = upload_dj_avatar(
            base_url=base_url,
            bearer_token=bearer_token,
            dj_id=dj_id,
            file_name=file_name,
            file_bytes=file_bytes,
            content_type=content_type,
            timeout_sec=timeout_sec,
        )
        return resp, source_label
    except Exception as exc:
        err = str(exc)
        if "File too large" not in err:
            raise

        base_avatar = candidate_avatar_url(candidate)
        if not base_avatar:
            raise
        urls = build_avatar_fetch_candidates(base_avatar)
        last_exc: Optional[Exception] = None
        for idx, fb_url in enumerate(urls):
            if idx == 0:
                # Usually original image; skip to smaller fallbacks after "File too large".
                continue
            blob = download_avatar_bytes_single(fb_url, timeout_sec=timeout_sec)
            if not blob:
                continue
            fb_bytes, fb_name, fb_ctype, fb_source = blob
            try:
                resp = upload_dj_avatar(
                    base_url=base_url,
                    bearer_token=bearer_token,
                    dj_id=dj_id,
                    file_name=fb_name,
                    file_bytes=fb_bytes,
                    content_type=fb_ctype,
                    timeout_sec=timeout_sec,
                )
                return resp, fb_source
            except Exception as fallback_exc:  # noqa: BLE001
                last_exc = fallback_exc
                continue
        if last_exc:
            raise last_exc
        raise


def request_json(
    method: str,
    url: str,
    payload: Optional[Dict[str, Any]] = None,
    bearer_token: str = "",
    timeout_sec: int = 20,
) -> Dict[str, Any]:
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }
    body: Optional[bytes] = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    token = str(bearer_token or "").strip()
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = Request(url, data=body, headers=headers, method=method.upper())
    try:
        with urlopen(req, timeout=timeout_sec) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            data = json.loads(text) if text else {}
            if isinstance(data, dict):
                return data
            return {"data": data}
    except HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        message = raw
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                message = str(parsed.get("error") or parsed)
        except Exception:
            pass
        raise RuntimeError(f"{method.upper()} {url} failed ({exc.code}): {message}") from exc
    except URLError as exc:
        raise RuntimeError(f"{method.upper()} {url} network error: {exc}") from exc


def login_get_token(base_url: str, username: str, password: str, timeout_sec: int) -> str:
    url = f"{base_url.rstrip('/')}/v1/auth/login"
    payload = {
        "username": str(username or "").strip(),
        "password": str(password or "").strip(),
    }
    data = request_json("POST", url, payload=payload, timeout_sec=timeout_sec)
    token = str(data.get("token") or "").strip()
    if not token:
        raise RuntimeError("login succeeded but token missing")
    return token


def manual_import(
    base_url: str,
    bearer_token: str,
    payload: Dict[str, Any],
    timeout_sec: int,
) -> Dict[str, Any]:
    send_payload = {k: v for k, v in payload.items() if not str(k).startswith("_")}
    url = f"{base_url.rstrip('/')}/v1/djs/manual/import"
    return request_json("POST", url, payload=send_payload, bearer_token=bearer_token, timeout_sec=timeout_sec)


def fetch_dj_detail(
    base_url: str,
    bearer_token: str,
    dj_id: str,
    timeout_sec: int,
) -> Dict[str, Any]:
    url = f"{base_url.rstrip('/')}/v1/djs/{dj_id}"
    resp = request_json("GET", url, payload=None, bearer_token=bearer_token, timeout_sec=timeout_sec)
    data = resp.get("data") if isinstance(resp.get("data"), dict) else {}
    return data if isinstance(data, dict) else {}


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description="Auto import unmatched archive DJs from local cache")
    ap.add_argument("--brands-root", type=str, default=str(DEFAULT_BRANDS_ROOT), help="brands root path")
    ap.add_argument(
        "--cache-root",
        type=str,
        default=str(DEFAULT_CACHE_ROOT),
        help="dj source cache root (contains queries/avatars)",
    )
    ap.add_argument("--bff-base", type=str, default="http://127.0.0.1:3001", help="Raver BFF base URL")
    ap.add_argument(
        "--auth-token",
        type=str,
        default=os.getenv("RAVER_BEARER_TOKEN", "").strip(),
        help="Bearer token (optional, if empty will login by username/password)",
    )
    ap.add_argument(
        "--username",
        type=str,
        default=os.getenv("RAVER_USERNAME", "uploadtester"),
        help="login username (used only when auth-token is empty)",
    )
    ap.add_argument(
        "--password",
        type=str,
        default=os.getenv("RAVER_PASSWORD", "123456"),
        help="login password (used only when auth-token is empty)",
    )
    ap.add_argument("--timeout-sec", type=int, default=20, help="HTTP timeout seconds")
    ap.add_argument("--avatar-timeout-sec", type=int, default=30, help="avatar download/upload timeout seconds")
    ap.add_argument("--limit", type=int, default=0, help="limit unmatched names to process (0 means all)")
    ap.add_argument("--progress-every", type=int, default=50, help="print progress every N items")
    ap.add_argument("--dry-run", action="store_true", help="only evaluate and build payload, do not import")
    ap.add_argument(
        "--upload-avatar",
        dest="upload_avatar",
        action="store_true",
        default=True,
        help="upload selected candidate avatar to OSS after manual import (default: true)",
    )
    ap.add_argument(
        "--no-upload-avatar",
        dest="upload_avatar",
        action="store_false",
        help="disable avatar upload",
    )
    ap.add_argument(
        "--overwrite-avatar",
        action="store_true",
        help="when DJ already has avatarUrl, still overwrite with selected source avatar",
    )
    ap.add_argument(
        "--avatar-backfill-report",
        type=str,
        default="",
        help="if set, skip import flow and backfill avatar for imported rows from this report json",
    )
    ap.add_argument(
        "--report-dir",
        type=str,
        default=str(DEFAULT_REPORT_DIR),
        help="directory for report json and ndjson logs",
    )
    return ap.parse_args()


def run_avatar_backfill_from_report(args: argparse.Namespace, token: str, cache_root: Path, report_dir: Path) -> Dict[str, Any]:
    source_report = Path(str(args.avatar_backfill_report)).expanduser().resolve()
    if not source_report.exists():
        raise SystemExit(f"avatar-backfill report not found: {source_report}")
    payload = read_json(source_report)
    if not payload:
        raise SystemExit(f"invalid report json: {source_report}")

    source_rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    targets = [
        row for row in source_rows
        if isinstance(row, dict)
        and str(row.get("status") or "").strip().lower() == "imported"
        and str(row.get("djId") or "").strip()
    ]
    if int(args.limit or 0) > 0:
        targets = targets[: int(args.limit)]

    run_id = time.strftime("%Y%m%d_%H%M%S")
    report_json = report_dir / f"auto_import_unmatched_avatar_backfill_{run_id}.json"
    report_log = report_dir / f"auto_import_unmatched_avatar_backfill_{run_id}.ndjson"

    total = len(targets)
    print(f"[step] avatar backfill targets from report: {total}")
    started_at = now_ms()

    totals = {
        "processed": 0,
        "cacheHit": 0,
        "exactMatchHit": 0,
        "multipleExactCandidateNames": 0,
        "avatarUploaded": 0,
        "avatarSkippedHasExisting": 0,
        "avatarSkippedNoSource": 0,
        "avatarUploadErrors": 0,
        "skippedNoCache": 0,
        "skippedNoExactMatch": 0,
    }
    rows: List[Dict[str, Any]] = []

    cache_queries_dir = cache_root / "queries"
    for index, src in enumerate(targets, start=1):
        name = str(src.get("name") or "").strip()
        dj_id = str(src.get("djId") or "").strip()
        totals["processed"] += 1
        if index == 1 or index % max(1, int(args.progress_every)) == 0:
            print(f"[progress] avatar {index}/{total} | {name} | {dj_id}")

        row: Dict[str, Any] = {
            "index": index,
            "name": name,
            "djId": dj_id,
            "status": "",
            "reason": "",
        }

        cache_record = load_cache_record_for_name(cache_queries_dir, name)
        if not cache_record:
            totals["skippedNoCache"] += 1
            row["status"] = "skipped"
            row["reason"] = "no_cache_record"
            rows.append(row)
            continue
        totals["cacheHit"] += 1

        picked, candidates = choose_best_exact_candidate(name, cache_record)
        if not picked:
            totals["skippedNoExactMatch"] += 1
            row["status"] = "skipped"
            row["reason"] = "no_exact_name_candidate_in_cache"
            rows.append(row)
            continue
        totals["exactMatchHit"] += 1

        source_key, candidate = picked
        row["selectedSource"] = source_key
        row["selectedCandidateName"] = candidate_name(candidate)
        row["selectedFollowers"] = candidate_followers(candidate)
        row["exactCandidateCount"] = len(candidates)

        if len(candidates) > 1:
            totals["multipleExactCandidateNames"] += 1
            append_ndjson(
                report_log,
                {
                    "at": now_ms(),
                    "level": "info",
                    "action": "multiple_exact_candidates_avatar_backfill",
                    "queryName": name,
                    "djId": dj_id,
                    "candidateCount": len(candidates),
                    "selected": {
                        "source": source_key,
                        "name": candidate_name(candidate),
                        "followers": candidate_followers(candidate),
                    },
                    "candidates": candidates,
                },
            )

        try:
            detail = fetch_dj_detail(
                base_url=str(args.bff_base).strip().rstrip("/"),
                bearer_token=token,
                dj_id=dj_id,
                timeout_sec=int(args.timeout_sec),
            )
            existing_avatar = first_non_empty(detail.get("avatarUrl"), detail.get("avatar_url"))
            row["avatarBefore"] = existing_avatar
            if existing_avatar and not args.overwrite_avatar:
                totals["avatarSkippedHasExisting"] += 1
                row["status"] = "skipped"
                row["reason"] = "existing_avatar"
                rows.append(row)
                continue

            try:
                upload_resp, avatar_source = upload_candidate_avatar_with_fallback(
                    base_url=str(args.bff_base).strip().rstrip("/"),
                    bearer_token=token,
                    dj_id=dj_id,
                    cache_root=cache_root,
                    candidate=candidate,
                    timeout_sec=int(args.avatar_timeout_sec),
                )
            except Exception as upload_exc:  # noqa: BLE001
                if "no avatar source" in str(upload_exc):
                    totals["avatarSkippedNoSource"] += 1
                    row["status"] = "skipped"
                    row["reason"] = "no_avatar_source"
                    rows.append(row)
                    continue
                raise
            upload_data = upload_resp.get("data") if isinstance(upload_resp.get("data"), dict) else {}
            uploaded_url = first_non_empty(upload_data.get("url"), upload_resp.get("url"))
            totals["avatarUploaded"] += 1
            row["status"] = "uploaded"
            row["reason"] = "ok"
            row["avatarUploadSource"] = avatar_source
            row["avatarUploadUrl"] = uploaded_url
            rows.append(row)
        except Exception as exc:  # noqa: BLE001
            totals["avatarUploadErrors"] += 1
            row["status"] = "error"
            row["reason"] = str(exc)
            rows.append(row)
            append_ndjson(
                report_log,
                {
                    "at": now_ms(),
                    "level": "error",
                    "action": "avatar_backfill_failed",
                    "queryName": name,
                    "djId": dj_id,
                    "selectedSource": source_key,
                    "error": str(exc),
                },
            )

    finished_at = now_ms()
    report = {
        "startedAtMs": started_at,
        "finishedAtMs": finished_at,
        "durationMs": max(0, finished_at - started_at),
        "config": {
            "bffBase": str(args.bff_base).strip().rstrip("/"),
            "cacheRoot": str(cache_root),
            "sourceReport": str(source_report),
            "limit": int(args.limit or 0),
            "overwriteAvatar": bool(args.overwrite_avatar),
        },
        "totals": totals,
        "rows": rows,
        "logsFile": str(report_log),
    }
    write_json(report_json, report)
    return {
        "reportJsonPath": str(report_json),
        "reportLogPath": str(report_log),
        "report": report,
    }


def main() -> None:
    args = parse_args()
    started_at = now_ms()

    brands_root = Path(args.brands_root).expanduser().resolve()
    cache_root = Path(args.cache_root).expanduser().resolve()
    cache_queries_dir = cache_root / "queries"
    report_dir = Path(args.report_dir).expanduser().resolve()
    report_dir.mkdir(parents=True, exist_ok=True)

    if not brands_root.exists():
        raise SystemExit(f"brands root not found: {brands_root}")
    if not cache_queries_dir.exists():
        raise SystemExit(f"cache queries dir not found: {cache_queries_dir}")

    run_id = time.strftime("%Y%m%d_%H%M%S")
    report_json = report_dir / f"auto_import_unmatched_from_cache_{run_id}.json"
    report_log = report_dir / f"auto_import_unmatched_from_cache_{run_id}.ndjson"

    token = str(args.auth_token or "").strip()
    if not token:
        token = login_get_token(
            base_url=str(args.bff_base).strip().rstrip("/"),
            username=str(args.username or "").strip(),
            password=str(args.password or "").strip(),
            timeout_sec=int(args.timeout_sec),
        )
        print(f"[auth] login success as {args.username}")
    else:
        print("[auth] using provided bearer token")

    if str(args.avatar_backfill_report or "").strip():
        result = run_avatar_backfill_from_report(
            args=args,
            token=token,
            cache_root=cache_root,
            report_dir=report_dir,
        )
        totals = result.get("report", {}).get("totals", {}) if isinstance(result.get("report"), dict) else {}
        print("[done] avatar backfill completed")
        print(
            f"[summary] processed={totals.get('processed', 0)} "
            f"cacheHit={totals.get('cacheHit', 0)} "
            f"exactHit={totals.get('exactMatchHit', 0)} "
            f"avatarUploaded={totals.get('avatarUploaded', 0)} "
            f"avatarSkipExisting={totals.get('avatarSkippedHasExisting', 0)} "
            f"avatarSkipNoSource={totals.get('avatarSkippedNoSource', 0)} "
            f"avatarErr={totals.get('avatarUploadErrors', 0)} "
            f"multi={totals.get('multipleExactCandidateNames', 0)}"
        )
        print(f"[report] {result.get('reportJsonPath')}")
        print(f"[log]    {result.get('reportLogPath')}")
        return

    print("[step] loading DJ library from BFF...")
    djs = fetch_all_djs_from_bff(
        base_url=str(args.bff_base).strip().rstrip("/"),
        bearer_token=token,
        timeout_sec=int(args.timeout_sec),
    )
    by_key, by_id = build_dj_maps(djs)
    print(f"[step] DJ library loaded: {len(djs)} items")

    print("[step] collecting unmatched archive timetable DJ names...")
    unmatched_result = collect_unmatched_names(brands_root=brands_root, by_key=by_key, by_id=by_id)
    unmatched_all = unmatched_result.get("unmatched") if isinstance(unmatched_result.get("unmatched"), list) else []
    unmatched = unmatched_all
    if int(args.limit or 0) > 0:
        unmatched = unmatched[: int(args.limit)]
    total = len(unmatched)
    print(f"[step] unmatched names: {len(unmatched_all)} (processing {total})")

    totals = {
        "unmatchedTotal": len(unmatched_all),
        "processed": 0,
        "cacheHit": 0,
        "exactMatchHit": 0,
        "multipleExactCandidateNames": 0,
        "importCreated": 0,
        "importUpdated": 0,
        "dryRunReady": 0,
        "skippedNoCache": 0,
        "skippedNoExactMatch": 0,
        "importErrors": 0,
        "avatarUploaded": 0,
        "avatarSkippedHasExisting": 0,
        "avatarSkippedNoSource": 0,
        "avatarUploadErrors": 0,
    }
    rows: List[Dict[str, Any]] = []

    for index, item in enumerate(unmatched, start=1):
        name = str(item.get("name") or "").strip()
        if not name:
            continue
        totals["processed"] += 1
        if index == 1 or index % max(1, int(args.progress_every)) == 0:
            print(f"[progress] {index}/{total} | {name}")

        row: Dict[str, Any] = {
            "index": index,
            "name": name,
            "countInArchive": int(item.get("count") or 0),
            "status": "",
            "reason": "",
        }

        cache_record = load_cache_record_for_name(cache_queries_dir, name)
        if not cache_record:
            totals["skippedNoCache"] += 1
            row["status"] = "skipped"
            row["reason"] = "no_cache_record"
            rows.append(row)
            continue
        totals["cacheHit"] += 1

        picked, candidates = choose_best_exact_candidate(name, cache_record)
        if not picked:
            totals["skippedNoExactMatch"] += 1
            row["status"] = "skipped"
            row["reason"] = "no_exact_name_candidate_in_cache"
            rows.append(row)
            continue
        totals["exactMatchHit"] += 1

        source_key, candidate = picked
        row["selectedSource"] = source_key
        row["selectedCandidateName"] = candidate_name(candidate)
        row["selectedFollowers"] = candidate_followers(candidate)
        row["exactCandidateCount"] = len(candidates)

        if len(candidates) > 1:
            totals["multipleExactCandidateNames"] += 1
            multi_log = {
                "at": now_ms(),
                "level": "info",
                "action": "multiple_exact_candidates",
                "queryName": name,
                "candidateCount": len(candidates),
                "selected": {
                    "source": source_key,
                    "name": candidate_name(candidate),
                    "followers": candidate_followers(candidate),
                },
                "candidates": candidates,
            }
            append_ndjson(report_log, multi_log)

        payload = build_import_payload(name, source_key, candidate)
        row["payloadPreview"] = {
            "name": payload.get("name"),
            "spotifyId": payload.get("spotifyId"),
            "soundcloudId": payload.get("soundcloudId"),
            "country": payload.get("country"),
            "selectedSource": payload.get("_meta", {}).get("selectedSource"),
            "selectedFollowers": payload.get("_meta", {}).get("selectedFollowers"),
        }

        if args.dry_run:
            totals["dryRunReady"] += 1
            row["status"] = "dry_run_ready"
            row["reason"] = "not_imported"
            rows.append(row)
            continue

        try:
            resp = manual_import(
                base_url=str(args.bff_base).strip().rstrip("/"),
                bearer_token=token,
                payload=payload,
                timeout_sec=int(args.timeout_sec),
            )
            data = resp.get("data") if isinstance(resp.get("data"), dict) else {}
            action = str(data.get("action") or "").strip()
            dj = data.get("dj") if isinstance(data.get("dj"), dict) else {}
            dj_id = str(dj.get("id") or "").strip()
            if action == "updated":
                totals["importUpdated"] += 1
            else:
                totals["importCreated"] += 1
            row["status"] = "imported"
            row["reason"] = action or "created"
            row["djId"] = dj_id
            existing_avatar = first_non_empty(dj.get("avatarUrl"), dj.get("avatar_url"))
            row["avatarBefore"] = existing_avatar

            if args.upload_avatar and dj_id:
                if existing_avatar and not args.overwrite_avatar:
                    totals["avatarSkippedHasExisting"] += 1
                    row["avatarUploadStatus"] = "skipped_existing_avatar"
                else:
                    try:
                        upload_resp, avatar_source = upload_candidate_avatar_with_fallback(
                            base_url=str(args.bff_base).strip().rstrip("/"),
                            bearer_token=token,
                            dj_id=dj_id,
                            cache_root=cache_root,
                            candidate=candidate,
                            timeout_sec=int(args.avatar_timeout_sec),
                        )
                        upload_data = upload_resp.get("data") if isinstance(upload_resp.get("data"), dict) else {}
                        uploaded_url = first_non_empty(upload_data.get("url"), upload_resp.get("url"))
                        totals["avatarUploaded"] += 1
                        row["avatarUploadStatus"] = "uploaded"
                        row["avatarUploadSource"] = avatar_source
                        row["avatarUploadUrl"] = uploaded_url
                    except Exception as avatar_exc:  # noqa: BLE001
                        if "no avatar source" in str(avatar_exc):
                            totals["avatarSkippedNoSource"] += 1
                            row["avatarUploadStatus"] = "skipped_no_avatar_source"
                        else:
                            totals["avatarUploadErrors"] += 1
                            row["avatarUploadStatus"] = "error"
                            row["avatarUploadError"] = str(avatar_exc)
                            append_ndjson(
                                report_log,
                                {
                                    "at": now_ms(),
                                    "level": "error",
                                    "action": "avatar_upload_failed",
                                    "queryName": name,
                                    "selectedSource": source_key,
                                    "djId": dj_id,
                                    "error": str(avatar_exc),
                                },
                            )
            elif args.upload_avatar and not dj_id:
                totals["avatarUploadErrors"] += 1
                row["avatarUploadStatus"] = "error"
                row["avatarUploadError"] = "missing dj id in manual import response"
            else:
                row["avatarUploadStatus"] = "disabled"
            rows.append(row)
        except Exception as exc:  # noqa: BLE001
            totals["importErrors"] += 1
            row["status"] = "error"
            row["reason"] = str(exc)
            rows.append(row)
            append_ndjson(
                report_log,
                {
                    "at": now_ms(),
                    "level": "error",
                    "action": "manual_import_failed",
                    "queryName": name,
                    "selectedSource": source_key,
                    "error": str(exc),
                },
            )

    finished_at = now_ms()
    report = {
        "startedAtMs": started_at,
        "finishedAtMs": finished_at,
        "durationMs": max(0, finished_at - started_at),
        "config": {
            "brandsRoot": str(brands_root),
            "cacheRoot": str(cache_root),
            "cacheQueriesDir": str(cache_queries_dir),
            "bffBase": str(args.bff_base).strip().rstrip("/"),
            "usedTokenLogin": not bool(str(args.auth_token or "").strip()),
            "dryRun": bool(args.dry_run),
            "limit": int(args.limit or 0),
            "uploadAvatar": bool(args.upload_avatar),
            "overwriteAvatar": bool(args.overwrite_avatar),
        },
        "unmatchedStats": unmatched_result.get("stats") if isinstance(unmatched_result.get("stats"), dict) else {},
        "totals": totals,
        "rows": rows,
        "logsFile": str(report_log),
    }
    write_json(report_json, report)

    print("[done] auto import completed")
    print(
        f"[summary] processed={totals['processed']} "
        f"cacheHit={totals['cacheHit']} "
        f"exactHit={totals['exactMatchHit']} "
        f"created={totals['importCreated']} "
        f"updated={totals['importUpdated']} "
        f"errors={totals['importErrors']} "
        f"multi={totals['multipleExactCandidateNames']} "
        f"avatarUploaded={totals['avatarUploaded']} "
        f"avatarErr={totals['avatarUploadErrors']}"
    )
    print(f"[report] {report_json}")
    print(f"[log]    {report_log}")


if __name__ == "__main__":
    main()
