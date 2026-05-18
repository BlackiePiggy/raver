#!/usr/bin/env python3
"""
Merge DJ source cache export (from Colab/Drive) into local web_tool cache root.

Input supports either:
1) run directory with `chunks/*.zip`
2) run directory with extracted `chunks/chunk_*/{queries,avatars}`
3) a single chunk zip file

Usage:
  python3 scrapRave/import_dj_source_cache_from_export.py \
    --input /path/to/run_20260402_xxx \
    --cache-root /Users/blackie/Projects/raver/scrapRave/web_tool/.cache/dj_source_cache
"""

from __future__ import annotations

import argparse
import json
import shutil
import tempfile
import zipfile
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


def ensure_dirs(cache_root: Path) -> Tuple[Path, Path]:
    queries = cache_root / "queries"
    avatars = cache_root / "avatars"
    queries.mkdir(parents=True, exist_ok=True)
    avatars.mkdir(parents=True, exist_ok=True)
    return queries, avatars


def safe_json_load(path: Path) -> Optional[Dict]:
    try:
        text = path.read_text(encoding="utf-8")
        obj = json.loads(text)
        if isinstance(obj, dict):
            return obj
    except Exception:
        return None
    return None


def prefer_new_query(src: Path, dst: Path) -> bool:
    """
    Return True if src should overwrite dst.
    Preference order:
    1) larger updatedAt (if both valid numbers)
    2) newer mtime
    """
    if not dst.exists():
        return True

    src_obj = safe_json_load(src)
    dst_obj = safe_json_load(dst)
    src_updated = src_obj.get("updatedAt") if isinstance(src_obj, dict) else None
    dst_updated = dst_obj.get("updatedAt") if isinstance(dst_obj, dict) else None

    try:
        src_num = float(src_updated)
    except Exception:
        src_num = None
    try:
        dst_num = float(dst_updated)
    except Exception:
        dst_num = None

    if src_num is not None and dst_num is not None:
        return src_num >= dst_num

    return src.stat().st_mtime >= dst.stat().st_mtime


def iter_chunk_dirs_from_extracted(root: Path) -> Iterable[Path]:
    chunks_root = root / "chunks"
    if chunks_root.is_dir():
        for p in sorted(chunks_root.glob("chunk_*")):
            if p.is_dir():
                yield p
    # Fallback: maybe root itself is chunk dir
    if root.is_dir() and root.name.startswith("chunk_"):
        yield root


def import_from_chunk_dir(chunk_dir: Path, queries_dst: Path, avatars_dst: Path) -> Dict[str, int]:
    stats = {
        "query_added": 0,
        "query_updated": 0,
        "query_skipped_older": 0,
        "query_invalid": 0,
        "avatar_added": 0,
        "avatar_exists": 0,
    }

    queries_src = chunk_dir / "queries"
    avatars_src = chunk_dir / "avatars"

    if queries_src.is_dir():
        for src in sorted(queries_src.glob("*.json")):
            dst = queries_dst / src.name
            if not dst.exists():
                shutil.copy2(src, dst)
                stats["query_added"] += 1
                continue
            if prefer_new_query(src, dst):
                shutil.copy2(src, dst)
                stats["query_updated"] += 1
            else:
                stats["query_skipped_older"] += 1
    else:
        stats["query_invalid"] += 1

    if avatars_src.is_dir():
        for src in sorted(avatars_src.iterdir()):
            if not src.is_file():
                continue
            dst = avatars_dst / src.name
            if dst.exists():
                stats["avatar_exists"] += 1
            else:
                shutil.copy2(src, dst)
                stats["avatar_added"] += 1

    return stats


def import_from_zip(zip_path: Path, queries_dst: Path, avatars_dst: Path) -> Dict[str, int]:
    with tempfile.TemporaryDirectory(prefix="dj_cache_import_") as td:
        tmp = Path(td)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(tmp)
        merged = {
            "query_added": 0,
            "query_updated": 0,
            "query_skipped_older": 0,
            "query_invalid": 0,
            "avatar_added": 0,
            "avatar_exists": 0,
        }
        chunk_dirs = [p for p in tmp.rglob("chunk_*") if p.is_dir()]
        if not chunk_dirs:
            chunk_dirs = [tmp]
        for chunk in sorted(chunk_dirs):
            part = import_from_chunk_dir(chunk, queries_dst, avatars_dst)
            for k, v in part.items():
                merged[k] += v
        return merged


def add_stats(total: Dict[str, int], part: Dict[str, int]) -> None:
    for k, v in part.items():
        total[k] = total.get(k, 0) + int(v)


def is_run_dir(path: Path) -> bool:
    if not path.is_dir():
        return False
    if path.name.startswith("run_"):
        return True
    if (path / "summary_global.json").exists():
        return True
    if (path / "chunks").is_dir():
        return True
    return False


def iter_input_targets(root: Path) -> List[Path]:
    """
    Expand an input path to actionable targets.
    - zip file => itself
    - run folder => itself
    - parent folder with run_* => each run folder
    - fallback => itself
    """
    if root.is_file() and root.suffix.lower() == ".zip":
        return [root]
    if not root.is_dir():
        return []
    if is_run_dir(root):
        return [root]
    run_dirs = sorted([p for p in root.glob("run_*") if p.is_dir()])
    if run_dirs:
        return run_dirs
    return [root]


def main() -> None:
    parser = argparse.ArgumentParser(description="Import DJ source cache export into local cache root")
    parser.add_argument(
        "--input",
        required=True,
        help="Path to run folder (with chunks) or a chunk zip file",
    )
    parser.add_argument(
        "--cache-root",
        default="/Users/blackie/Projects/raver/scrapRave/web_tool/.cache/dj_source_cache",
        help="Target cache root used by web_tool server",
    )
    args = parser.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    cache_root = Path(args.cache_root).expanduser().resolve()
    queries_dst, avatars_dst = ensure_dirs(cache_root)

    totals = {
        "query_added": 0,
        "query_updated": 0,
        "query_skipped_older": 0,
        "query_invalid": 0,
        "avatar_added": 0,
        "avatar_exists": 0,
        "chunk_zips_processed": 0,
        "chunk_dirs_processed": 0,
    }

    targets = iter_input_targets(input_path)
    if not targets:
        raise SystemExit(f"input path not found: {input_path}")
    processed_targets: List[str] = []

    for target in targets:
        processed_targets.append(str(target))
        if target.is_file() and target.suffix.lower() == ".zip":
            part = import_from_zip(target, queries_dst, avatars_dst)
            add_stats(totals, part)
            totals["chunk_zips_processed"] += 1
            continue

        if target.is_dir():
            # 1) import from zips first
            chunk_zip_root = target / "chunks"
            if chunk_zip_root.is_dir():
                zip_files = sorted(chunk_zip_root.glob("chunk_*.zip"))
            else:
                zip_files = []
            for z in zip_files:
                part = import_from_zip(z, queries_dst, avatars_dst)
                add_stats(totals, part)
                totals["chunk_zips_processed"] += 1

            # 2) import from extracted chunk dirs (if any)
            for d in iter_chunk_dirs_from_extracted(target):
                part = import_from_chunk_dir(d, queries_dst, avatars_dst)
                add_stats(totals, part)
                totals["chunk_dirs_processed"] += 1
            continue

    result = {
        "input": str(input_path),
        "processedTargets": processed_targets,
        "cacheRoot": str(cache_root),
        "totals": totals,
        "finalCounts": {
            "queryFiles": len(list(queries_dst.glob("*.json"))),
            "avatarFiles": len([p for p in avatars_dst.iterdir() if p.is_file()]),
        },
    }

    out = cache_root / "import_result.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print(f"[done] wrote report: {out}")


if __name__ == "__main__":
    main()
