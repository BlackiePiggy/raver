#!/usr/bin/env python3
"""Scrape Tomorrowland-related event data from festtimetable.com.

Features:
1. Discover event URLs from sitemap.
2. Scrape each event page:
   - basic event info (title/date/description)
   - timetable cards
   - photos (label + image URL)
3. Scrape each timetable detail page:
   - stage name
   - set times
   - artist name
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from html import unescape
from typing import Dict, List, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

BASE_URL = "https://festtimetable.com"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)


@dataclass
class FetchResult:
    url: str
    text: str


def fetch_text(url: str, timeout: int = 30, retries: int = 3, sleep_sec: float = 0.6) -> FetchResult:
    last_exc: Optional[Exception] = None
    for i in range(retries):
        try:
            req = Request(url, headers={"User-Agent": USER_AGENT})
            with urlopen(req, timeout=timeout) as resp:
                data = resp.read().decode("utf-8", errors="replace")
            return FetchResult(url=url, text=data)
        except (HTTPError, URLError, TimeoutError) as exc:
            last_exc = exc
            if i < retries - 1:
                time.sleep(sleep_sec * (i + 1))
    raise RuntimeError(f"Fetch failed: {url} ({last_exc})")


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
    block = find_balanced_div(html, m.start())
    return block or ""


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
        if end == -1:
            continue
        out.append(html[m.start() : end + 4])
    return out


def anchor_open_tag(anchor_html: str) -> str:
    end = anchor_html.find(">")
    return anchor_html[: end + 1] if end != -1 else anchor_html


def discover_event_urls(locale: str, keyword: str) -> List[str]:
    sitemap = fetch_text(f"{BASE_URL}/sitemap.xml").text
    root = ET.fromstring(sitemap)
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}

    # Accept any locale in sitemap, normalize back to requested locale.
    event_root_re = re.compile(r"^/([a-z]{2}-[A-Z]{2})/events/([^/]+)$")
    slugs: List[str] = []
    for loc in root.findall(".//sm:loc", ns):
        if loc.text is None:
            continue
        url = loc.text.strip()
        parsed = urlparse(url)
        path = parsed.path
        m = event_root_re.match(path)
        if not m:
            continue
        slug = m.group(2).strip()
        if keyword.lower() in slug.lower():
            slugs.append(slug)

    # Deduplicate while preserving order
    seen = set()
    deduped = []
    for slug in slugs:
        if slug in seen:
            continue
        seen.add(slug)
        deduped.append(f"{BASE_URL}/{locale}/events/{slug}")
    return deduped


def parse_event_page(html: str, event_url: str) -> Dict:
    event: Dict = {
        "event_url": event_url,
        "slug": urlparse(event_url).path.rstrip("/").split("/")[-1],
        "title": None,
        "start_datetime": None,
        "end_datetime": None,
        "date_text_start": None,
        "date_text_end": None,
        "description": None,
        "timetable": [],
        "photos": [],
    }

    title_m = re.search(r'<h2\s+class="event-information__title">(.*?)</h2>', html, flags=re.S)
    if title_m:
        event["title"] = strip_tags(title_m.group(1))

    desc_m = re.search(r'<p\s+class="event-information__description">(.*?)</p>', html, flags=re.S)
    if desc_m:
        event["description"] = strip_tags(desc_m.group(1))

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

    timetable_html = extract_section_by_id(html, "timetable")
    for a_html in find_anchor_blocks(timetable_html):
        open_tag = anchor_open_tag(a_html)
        attrs = parse_attrs(open_tag)
        klass = attrs.get("class", "")
        href = attrs.get("href")
        if "action-card--timetable" not in klass or not href:
            continue

        name = attrs.get("aria-label") or None
        dt_m = re.search(r'<time[^>]*datetime="([^"]+)"', a_html)
        date_text_m = re.search(r'<span\s+class="datetime__date">([^<]+)</span>', a_html)
        time_text_m = re.search(r'<span\s+class="datetime__time">([^<]+)</span>', a_html)

        event["timetable"].append(
            {
                "name": name,
                "url": urljoin(BASE_URL, href),
                "start_datetime": dt_m.group(1) if dt_m else None,
                "date_text": strip_tags(date_text_m.group(1)) if date_text_m else None,
                "time_text": strip_tags(time_text_m.group(1)) if time_text_m else None,
            }
        )

    photos_html = extract_section_by_id(html, "photos")
    for a_html in find_anchor_blocks(photos_html):
        open_tag = anchor_open_tag(a_html)
        attrs = parse_attrs(open_tag)
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

    return event


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
            klass = attrs.get("class", "")
            if "bystage-list__item" not in klass:
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


def scrape(keyword: str, locale: str, max_events: Optional[int], with_timetable_details: bool, sleep_sec: float) -> Dict:
    event_urls = discover_event_urls(locale=locale, keyword=keyword)
    if max_events is not None:
        event_urls = event_urls[:max_events]

    result: Dict = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "base_url": BASE_URL,
        "locale": locale,
        "keyword": keyword,
        "event_count": len(event_urls),
        "events": [],
        "errors": [],
    }

    for idx, event_url in enumerate(event_urls, start=1):
        try:
            print(f"[{idx}/{len(event_urls)}] event: {event_url}", file=sys.stderr)
            html = fetch_text(event_url).text
            event = parse_event_page(html, event_url)

            if with_timetable_details:
                details = []
                for t in event.get("timetable", []):
                    t_url = t.get("url")
                    if not t_url:
                        continue
                    try:
                        d_html = fetch_text(t_url).text
                        details.append(parse_timetable_detail_page(d_html, t_url))
                        time.sleep(sleep_sec)
                    except Exception as exc:  # noqa: BLE001
                        result["errors"].append({"url": t_url, "error": str(exc)})
                event["timetable_details"] = details

            result["events"].append(event)
            time.sleep(sleep_sec)
        except Exception as exc:  # noqa: BLE001
            result["errors"].append({"url": event_url, "error": str(exc)})

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Scrape Tomorrowland-related data from festtimetable.com")
    parser.add_argument("--keyword", default="tomorrowland", help="Keyword in event slug (default: tomorrowland)")
    parser.add_argument("--locale", default="en-GB", help="Locale path prefix (default: en-GB)")
    parser.add_argument("--max-events", type=int, default=None, help="Optional max number of matched events")
    parser.add_argument("--no-timetable-details", action="store_true", help="Skip scraping each timetable detail page")
    parser.add_argument("--sleep", type=float, default=0.25, help="Sleep between requests in seconds")
    parser.add_argument("--output", default="tomorrowland_festtimetable.json", help="Output JSON file path")
    args = parser.parse_args()

    data = scrape(
        keyword=args.keyword,
        locale=args.locale,
        max_events=args.max_events,
        with_timetable_details=not args.no_timetable_details,
        sleep_sec=args.sleep,
    )

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(
        f"Done. events={data['event_count']} scraped={len(data['events'])} "
        f"errors={len(data['errors'])} output={args.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
