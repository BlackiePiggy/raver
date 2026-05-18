#!/usr/bin/env python3
"""
Export unmatched performer names from local timetable (brands/**/festival-info.json).

Match logic follows festival-viewer.html behavior:
- normalize name by trim + lowercase + collapse spaces
- match by DJ name or aliases
- for normal slot: prefer explicit djIds[0]/djId, else fallback name match
- for B2B/B3B slot: split into performers, then match each performer independently
  (explicit djIds[index]/djId for first performer with name-check, else name match)

Output files:
- unmatched_dj_names_for_colab.json
- unmatched_dj_names_for_colab.txt
- unmatched_dj_names_for_colab.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlencode
from urllib.request import Request, urlopen


USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)


def normalize_name_key(name: str) -> str:
    return re.sub(r"\s+", " ", str(name or "").strip().lower())


def is_meaningful_dj_name(text: str) -> bool:
    s = str(text or "").strip()
    if not s:
        return False
    return bool(re.search(r"[A-Za-z0-9\u4e00-\u9fff]", s))


def split_collab_performers(raw_name: str) -> List[str]:
    """
    Mirror ttExtractCollaborativePerformers:
    - detect b2b/b3b (case-insensitive)
    - split by regex \\s*b(?:2|3)b\\s*
    """
    name = str(raw_name or "").strip()
    if not name:
        return []
    if not re.search(r"\bb(?:2|3)b\b", name, flags=re.I):
        return []
    token = "__TT_ACT_SPLIT__"
    replaced = re.sub(r"\s*b(?:2|3)b\s*", token, name, flags=re.I)
    performers = [x.strip() for x in replaced.split(token) if str(x).strip()]
    return performers if len(performers) >= 2 else []


def choose_preferred_dj(current: Optional[Dict[str, Any]], candidate: Dict[str, Any]) -> Dict[str, Any]:
    if not current:
        return candidate
    current_has_avatar = bool(str(current.get("avatarUrl") or "").strip())
    candidate_has_avatar = bool(str(candidate.get("avatarUrl") or "").strip())
    if not current_has_avatar and candidate_has_avatar:
        return candidate
    current_verified = bool(current.get("isVerified"))
    candidate_verified = bool(candidate.get("isVerified"))
    if not current_verified and candidate_verified:
        return candidate
    return current


def dj_matches_performer_name(dj: Optional[Dict[str, Any]], performer_name: str) -> bool:
    target = normalize_name_key(performer_name)
    if not target or not dj:
        return False
    if normalize_name_key(str(dj.get("name") or "")) == target:
        return True
    aliases = dj.get("aliases")
    if isinstance(aliases, list):
        for alias in aliases:
            if normalize_name_key(str(alias or "")) == target:
                return True
    return False


def load_json(path: Path) -> Optional[Dict[str, Any]]:
    try:
        with path.open("r", encoding="utf-8") as f:
            obj = json.load(f)
        if isinstance(obj, dict):
            return obj
    except Exception:
        return None
    return None


def fetch_json(url: str, headers: Optional[Dict[str, str]] = None, timeout: int = 20) -> Dict[str, Any]:
    req_headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    if headers:
        req_headers.update(headers)
    req = Request(url, headers=req_headers)
    with urlopen(req, timeout=timeout) as resp:
        body = resp.read().decode("utf-8", errors="replace")
    data = json.loads(body)
    if not isinstance(data, dict):
        raise RuntimeError("invalid json object response")
    return data


def fetch_all_djs_from_bff(base_url: str, bearer_token: str, timeout_sec: int = 20) -> List[Dict[str, Any]]:
    headers: Dict[str, str] = {}
    if bearer_token:
        headers["Authorization"] = f"Bearer {bearer_token}"

    page = 1
    limit = 100
    out: List[Dict[str, Any]] = []
    total_pages = None

    while True:
        query = urlencode({"page": page, "limit": limit, "sortBy": "name"})
        url = f"{base_url.rstrip('/')}/v1/djs?{query}"
        payload = fetch_json(url, headers=headers, timeout=timeout_sec)
        data = payload.get("data") if isinstance(payload.get("data"), dict) else {}
        items = data.get("items") if isinstance(data, dict) else None
        if not isinstance(items, list):
            raise RuntimeError(f"unexpected response schema at page={page}")
        out.extend([x for x in items if isinstance(x, dict)])

        pagination = payload.get("pagination") if isinstance(payload.get("pagination"), dict) else {}
        if total_pages is None:
            tp = pagination.get("totalPages")
            if isinstance(tp, int) and tp > 0:
                total_pages = tp
            else:
                total = pagination.get("total")
                if isinstance(total, int) and total >= 0:
                    total_pages = max(1, int(math.ceil(total / float(limit))))
                else:
                    total_pages = 1
        if page >= int(total_pages):
            break
        page += 1
    return out


def load_djs_from_file(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(str(path))
    obj = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(obj, list):
        return [x for x in obj if isinstance(x, dict)]
    if isinstance(obj, dict):
        data = obj.get("data")
        if isinstance(data, dict) and isinstance(data.get("items"), list):
            return [x for x in data["items"] if isinstance(x, dict)]
        if isinstance(obj.get("items"), list):
            return [x for x in obj["items"] if isinstance(x, dict)]
    raise RuntimeError("Unsupported DJ library JSON format")


def build_dj_maps(djs: List[Dict[str, Any]]) -> Tuple[Dict[str, Dict[str, Any]], Dict[str, Dict[str, Any]]]:
    by_key: Dict[str, Dict[str, Any]] = {}
    by_id: Dict[str, Dict[str, Any]] = {}
    for dj in djs:
        dj_id = str(dj.get("id") or "").strip()
        if dj_id and dj_id not in by_id:
            by_id[dj_id] = dj
        keys = set()
        name_key = normalize_name_key(str(dj.get("name") or ""))
        if name_key:
            keys.add(name_key)
        aliases = dj.get("aliases")
        if isinstance(aliases, list):
            for alias in aliases:
                alias_key = normalize_name_key(str(alias or ""))
                if alias_key:
                    keys.add(alias_key)
        for key in keys:
            by_key[key] = choose_preferred_dj(by_key.get(key), dj)
    return by_key, by_id


def find_matched_for_slot(slot: Dict[str, Any], by_key: Dict[str, Dict[str, Any]], by_id: Dict[str, Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    dj_ids = slot.get("djIds")
    if isinstance(dj_ids, list) and dj_ids:
        first_id = str(dj_ids[0] or "").strip()
        if first_id and first_id in by_id:
            return by_id[first_id]
    dj_id = str(slot.get("djId") or "").strip()
    if dj_id and dj_id in by_id:
        return by_id[dj_id]
    name_key = normalize_name_key(str(slot.get("musician") or ""))
    if name_key:
        return by_key.get(name_key)
    return None


def find_matched_for_performer(
    slot: Dict[str, Any],
    performer_name: str,
    performer_index: int,
    by_key: Dict[str, Dict[str, Any]],
    by_id: Dict[str, Dict[str, Any]],
) -> Optional[Dict[str, Any]]:
    def try_get_matched_by_id(raw_id: Any) -> Optional[Dict[str, Any]]:
        dj_id = str(raw_id or "").strip()
        if not dj_id:
            return None
        dj = by_id.get(dj_id)
        if not dj:
            return None
        if dj_matches_performer_name(dj, performer_name):
            return dj
        return None

    dj_ids = slot.get("djIds")
    if isinstance(dj_ids, list) and performer_index < len(dj_ids):
        m = try_get_matched_by_id(dj_ids[performer_index])
        if m:
            return m
    if performer_index == 0:
        m = try_get_matched_by_id(slot.get("djId"))
        if m:
            return m
    return by_key.get(normalize_name_key(performer_name))


def collect_unmatched_names(
    brands_root: Path,
    by_key: Dict[str, Dict[str, Any]],
    by_id: Dict[str, Dict[str, Any]],
) -> Dict[str, Any]:
    unmatched: Dict[str, Dict[str, Any]] = {}
    stats = {
        "festivalFiles": 0,
        "lineupRows": 0,
        "performerChecks": 0,
        "matchedPerformers": 0,
        "unmatchedPerformers": 0,
        "invalidNameSkipped": 0,
    }

    for info_path in sorted(brands_root.rglob("festival-info.json")):
        obj = load_json(info_path)
        if not obj:
            continue
        lineup = obj.get("lineup")
        if not isinstance(lineup, list):
            continue
        stats["festivalFiles"] += 1
        rel_path = str(info_path.relative_to(brands_root))

        for row in lineup:
            if not isinstance(row, dict):
                continue
            stats["lineupRows"] += 1
            musician = str(row.get("musician") or "").strip()
            if not musician:
                continue
            performers = split_collab_performers(musician)

            if performers:
                for idx, performer in enumerate(performers):
                    stats["performerChecks"] += 1
                    if not is_meaningful_dj_name(performer):
                        stats["invalidNameSkipped"] += 1
                        continue
                    matched = find_matched_for_performer(row, performer, idx, by_key, by_id)
                    if matched:
                        stats["matchedPerformers"] += 1
                        continue
                    stats["unmatchedPerformers"] += 1
                    key = normalize_name_key(performer)
                    if not key:
                        continue
                    entry = unmatched.setdefault(
                        key,
                        {
                            "name": performer,
                            "count": 0,
                            "examples": [],
                        },
                    )
                    entry["count"] += 1
                    if len(entry["examples"]) < 3:
                        entry["examples"].append(
                            {
                                "festivalInfoPath": rel_path,
                                "musicianRaw": musician,
                                "performer": performer,
                                "date": str(row.get("date") or ""),
                                "time": str(row.get("time") or ""),
                                "stage": str(row.get("stage") or ""),
                            }
                        )
                continue

            stats["performerChecks"] += 1
            if not is_meaningful_dj_name(musician):
                stats["invalidNameSkipped"] += 1
                continue
            matched = find_matched_for_slot(row, by_key, by_id)
            if matched:
                stats["matchedPerformers"] += 1
                continue
            stats["unmatchedPerformers"] += 1
            key = normalize_name_key(musician)
            if not key:
                continue
            entry = unmatched.setdefault(
                key,
                {
                    "name": musician,
                    "count": 0,
                    "examples": [],
                },
            )
            entry["count"] += 1
            if len(entry["examples"]) < 3:
                entry["examples"].append(
                    {
                        "festivalInfoPath": rel_path,
                        "musicianRaw": musician,
                        "performer": musician,
                        "date": str(row.get("date") or ""),
                        "time": str(row.get("time") or ""),
                        "stage": str(row.get("stage") or ""),
                    }
                )

    unmatched_list = sorted(
        unmatched.values(),
        key=lambda x: (str(x.get("name") or "").lower(), -int(x.get("count") or 0)),
    )
    return {"stats": stats, "unmatched": unmatched_list}


def write_outputs(output_dir: Path, payload: Dict[str, Any]) -> Dict[str, str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    unmatched = payload.get("unmatched") if isinstance(payload.get("unmatched"), list) else []
    stats = payload.get("stats") if isinstance(payload.get("stats"), dict) else {}

    json_path = output_dir / "unmatched_dj_names_for_colab.json"
    txt_path = output_dir / "unmatched_dj_names_for_colab.txt"
    csv_path = output_dir / "unmatched_dj_names_for_colab.csv"
    summary_path = output_dir / "unmatched_dj_names_summary.json"

    json_obj = {
        "generatedAt": int(time.time() * 1000),
        "count": len(unmatched),
        "names": [str(x.get("name") or "") for x in unmatched if str(x.get("name") or "").strip()],
        "items": unmatched,
        "stats": stats,
    }
    json_path.write_text(json.dumps(json_obj, ensure_ascii=False, indent=2), encoding="utf-8")

    txt_lines = [str(x.get("name") or "").strip() for x in unmatched]
    txt_path.write_text("\n".join([x for x in txt_lines if x]), encoding="utf-8")

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "name",
                "count",
                "exampleFestivalInfoPath",
                "exampleMusicianRaw",
                "exampleDate",
                "exampleTime",
                "exampleStage",
            ],
        )
        w.writeheader()
        for item in unmatched:
            ex = item.get("examples")[0] if isinstance(item.get("examples"), list) and item.get("examples") else {}
            w.writerow(
                {
                    "name": str(item.get("name") or ""),
                    "count": int(item.get("count") or 0),
                    "exampleFestivalInfoPath": str(ex.get("festivalInfoPath") or ""),
                    "exampleMusicianRaw": str(ex.get("musicianRaw") or ""),
                    "exampleDate": str(ex.get("date") or ""),
                    "exampleTime": str(ex.get("time") or ""),
                    "exampleStage": str(ex.get("stage") or ""),
                }
            )

    summary_path.write_text(
        json.dumps(
            {
                "generatedAt": int(time.time() * 1000),
                "files": {
                    "json": str(json_path),
                    "txt": str(txt_path),
                    "csv": str(csv_path),
                },
                "stats": stats,
                "unmatchedNameCount": len(unmatched),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return {
        "json": str(json_path),
        "txt": str(txt_path),
        "csv": str(csv_path),
        "summary": str(summary_path),
    }


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description="Export unmatched timetable DJ names for Colab prefetch")
    ap.add_argument("--brands-root", type=str, default="./brands", help="local brands root")
    ap.add_argument("--output-dir", type=str, default="./exports/unmatched_dj_names", help="output dir")
    ap.add_argument("--bff-base", type=str, default="http://127.0.0.1:3001", help="Raver BFF base")
    ap.add_argument(
        "--auth-token",
        type=str,
        default=os.getenv("RAVER_BEARER_TOKEN", ""),
        help="optional bearer token",
    )
    ap.add_argument(
        "--dj-library-file",
        type=str,
        default="",
        help="optional local dj library json; if set, skip API fetch",
    )
    ap.add_argument("--timeout-sec", type=int, default=20, help="http timeout")
    return ap.parse_args()


def main() -> None:
    args = parse_args()
    brands_root = Path(args.brands_root).resolve()
    output_dir = Path(args.output_dir).resolve()
    if not brands_root.exists():
        raise SystemExit(f"brands root not found: {brands_root}")

    if args.dj_library_file:
        djs = load_djs_from_file(Path(args.dj_library_file).resolve())
        source = f"file:{Path(args.dj_library_file).resolve()}"
    else:
        djs = fetch_all_djs_from_bff(
            base_url=str(args.bff_base).strip().rstrip("/"),
            bearer_token=str(args.auth_token or "").strip(),
            timeout_sec=int(args.timeout_sec),
        )
        source = f"api:{str(args.bff_base).strip().rstrip('/')}/v1/djs"

    by_key, by_id = build_dj_maps(djs)
    result = collect_unmatched_names(brands_root=brands_root, by_key=by_key, by_id=by_id)
    result["djLibrary"] = {
        "source": source,
        "count": len(djs),
        "nameKeys": len(by_key),
        "idKeys": len(by_id),
    }
    files = write_outputs(output_dir=output_dir, payload=result)

    print("[done] unmatched DJ export completed")
    print(f"[info] dj library source: {source}")
    print(
        f"[info] unmatched names: {len(result.get('unmatched', []))} | "
        f"checks: {result.get('stats', {}).get('performerChecks', 0)}"
    )
    print("[files]")
    for key, path in files.items():
        print(f"  - {key}: {path}")


if __name__ == "__main__":
    main()
