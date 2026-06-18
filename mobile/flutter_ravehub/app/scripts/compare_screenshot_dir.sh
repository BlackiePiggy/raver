#!/usr/bin/env bash
set -euo pipefail

REFERENCE_DIR="${1:-qa/screenshots/ios-reference}"
CANDIDATE_DIR="${2:-app/build/screenshots/flutter}"
DIFF_DIR="${3:-app/build/screenshots/diff}"
THRESHOLD="${RAVEHUB_SCREENSHOT_DIFF_THRESHOLD:-0.01}"

if [[ ! -d "$REFERENCE_DIR" ]]; then
  echo "Screenshot reference directory not found: $REFERENCE_DIR"
  echo "Skipping pixel diff until native iOS reference screenshots are added."
  exit 0
fi

if [[ ! -d "$CANDIDATE_DIR" ]]; then
  echo "Candidate screenshot directory not found: $CANDIDATE_DIR"
  exit 1
fi

python3 - "$REFERENCE_DIR" "$CANDIDATE_DIR" "$DIFF_DIR" "$THRESHOLD" <<'PY'
from pathlib import Path
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    print("Pillow is required. Install with: python3 -m pip install pillow")
    sys.exit(2)

reference_dir = Path(sys.argv[1])
candidate_dir = Path(sys.argv[2])
diff_dir = Path(sys.argv[3])
threshold = float(sys.argv[4])

reference_files = sorted(reference_dir.glob("*.png"))
if not reference_files:
    print(f"No PNG references found in {reference_dir}; skipping pixel diff.")
    sys.exit(0)

diff_dir.mkdir(parents=True, exist_ok=True)
failures = []

for reference_file in reference_files:
    candidate_file = candidate_dir / reference_file.name
    if not candidate_file.exists():
        failures.append(f"{reference_file.name}: missing candidate screenshot")
        continue

    with Image.open(reference_file).convert("RGBA") as reference_image:
        with Image.open(candidate_file).convert("RGBA") as candidate_image:
            if reference_image.size != candidate_image.size:
                failures.append(
                    f"{reference_file.name}: size mismatch "
                    f"reference={reference_image.size} candidate={candidate_image.size}"
                )
                continue

            diff = ImageChops.difference(reference_image, candidate_image)
            changed_pixels = sum(1 for pixel in diff.getdata() if pixel != (0, 0, 0, 0))
            total_pixels = reference_image.size[0] * reference_image.size[1]
            ratio = changed_pixels / total_pixels
            if ratio > threshold:
                mask = diff.convert("L").point(lambda value: 255 if value else 0)
                highlight = Image.new("RGBA", reference_image.size, (255, 0, 0, 180))
                overlay = Image.alpha_composite(candidate_image, Image.composite(highlight, Image.new("RGBA", reference_image.size), mask))
                overlay.save(diff_dir / reference_file.name)
                failures.append(
                    f"{reference_file.name}: diff ratio {ratio:.4%} exceeds {threshold:.4%}"
                )
            else:
                print(f"{reference_file.name}: diff ratio {ratio:.4%}")

if failures:
    print("Screenshot diff failures:")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print("Screenshot diff passed.")
PY
