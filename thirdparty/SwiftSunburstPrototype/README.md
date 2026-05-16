# Swift Sunburst Prototype

This package is a native SwiftUI Canvas prototype for rendering the PulseRoots genre hierarchy without WebView.

## Run on macOS

```bash
cd SwiftSunburstPrototype
swift run SunburstPreview
```

The preview app loads `Sources/SunburstPreview/Resources/genres_tree.json`, renders a native sunburst chart, and lets you:

- Click a segment to focus into that branch.
- Click the center to go back to the parent branch.
- Click empty space to reset to the root.
- Inspect the selected genre in the left panel.

## Structure

- `Sources/SunburstCore`: shared model, layout, hit testing, and SwiftUI Canvas renderer.
- `Sources/SunburstPreview`: macOS preview app for fast iteration.
- `Sources/SunburstPreview/Resources/genres_tree.json`: generated tree data from `../genres_flat.csv`.

## iOS Integration Path

Keep `SunburstCore` platform-neutral and import it from the iOS app target. The iOS app can reuse:

- `GenreNode`
- `SunburstLayout`
- `SunburstHitTesting`
- `SunburstCanvasView`

Then replace the macOS left sidebar with an iOS bottom sheet or native detail view.

## Replicating `vasturiano/sunburst-chart`

The correct animation model is not "re-layout the focused subtree and interpolate segment paths." The original library uses a stable global partition and animates projection scales:

1. Build a full tree hierarchy.
2. Compute stable partition coordinates for every node:
   - `x0/x1`: normalized angular domain.
   - `y0/y1`: normalized depth/radius domain.
3. Render visible arcs by projecting those stable coordinates through the current focus domain.
4. On click, animate the focus domain:
   - angle domain moves from current node range to target node range.
   - radius domain moves from current depth range to target depth range.
5. Do not mutate render state from inside the drawing pass.
6. Hit testing should use the currently projected visible segments.
7. Center tap returns to parent. Empty-space tap returns to root.

### Done

- Native SwiftUI Canvas renderer.
- Tree data loaded from generated JSON.
- Stable global partition coordinates.
- Focus-domain animation using `TimelineView(.animation)`.
- D3-style square-root radius projection.
- Tableau-like fixed palette.
- Selected/hover segment stroke emphasis.
- Tap segment to focus.
- Tap center to go to parent.
- Tap empty space to reset.
- Rotated labels for large first/second-level segments.
- Approximate label fitting by arc length and ring width.
- macOS hover feedback for fast desktop tuning.
- macOS preview app for rapid iteration.

### Not Done Yet

- Exact label clipping behavior.
- Touch-specific bottom sheet and gesture affordances.
- Pixel-level color/stroke parity.
- Accessibility labels and keyboard navigation.
