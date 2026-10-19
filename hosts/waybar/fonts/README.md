# Syncshell icon font

`SyncshellIcons.ttf` contains three monochrome outlines derived directly from
the existing `assets/mono/` artwork. No colors or background fills are baked
into the font. Corner badges and their transparent cutouts remain part of
each glyph, so they work on light, dark and translucent bars.

| Code point | Glyph     | Source SVG           |
|------------|-----------|----------------------|
| `U+E000`   | `default` | `status-default.svg` |
| `U+E001`   | `notify`  | `status-notify.svg`  |
| `U+E002`   | `sync`    | `status-sync.svg`    |

The default is the familiar Syncthing mark. `notify` adds the bottom-right
exclamation mark; `sync` adds the refresh arrows. All have the same advance
width, so changing state does not shift the adjacent text. These are static
glyphs, not an animation. Other states can retain a glyph and use explicit
text; do not present stale or paused state as healthy.

## Waybar contract

The [module configuration](../config.jsonc) uses the Go status producer's
`alt`, `class`, `text` and `tooltip` fields.
It targets Waybar 0.15.0's existing text/markup interface, without
Quickshell, CFFI, image options or an icon-theme dependency.

The installed font must be discoverable by Fontconfig as `Syncshell Icons`.
The bar is icon-only; counts and state descriptions belong in the tooltip.
The static format selects the icon family only around `{icon}`, not tooltip
text. `escape: true` protects dynamic text and tooltips, since the font-family
markup lives in the trusted static format.
Do not use `tooltip-format: {icon}` unless that format also selects the font.

By default the whole icon inherits the module's foreground. Optional CSS may
color error state red and active state yellow using the user's theme palette.
Waybar does not define a universal "system red". Palette mappings belong to
the user's stylesheet, not Go or the font. Monochrome styling remains valid:
the badge shapes and status text convey meaning without colors.

One glyph has one foreground color. Its exclamation mark cannot independently
receive a CSS color. We deliberately color the entire glyph rather than add
layered glyphs, fixed-color markup or theme-reading helpers. A CSS rule on
`#custom-syncshell.error` also colors any adjacent text in that module; Pango
spans are not separate CSS nodes. Independently colored counts would require
separate module widgets, not a change to this font.

## Rebuild and verify

From the repository root, with Go and librsvg's `rsvg-convert` available:

```sh
cd hosts/waybar/fonts
go run .
go run . -check
go test ./...
fc-scan SyncshellIcons.ttf
```

The build-only Go tool uses the standard library. Its separate module keeps
the independent font-decoder test dependencies out of the production core.
Users need only the generated font; Python is not required for rebuilding,
testing or runtime use.

`glyphs.json` holds normalized quadratic contours from the source SVGs, with
strokes expanded, masks subtracted and geometry clipped to the SVG canvas.
It is the editable font outline source, not an automatic SVG importer. Tests
decode the generated font independently and compare its rendered outlines
against all three original SVGs. When changing the artwork, update these
contours too; the render tests catch drift.

The outlines and generated font retain the existing icon attribution and
MPL-2.0 licensing; see [the icon notice](../../../assets/LICENSE.md). Preserve
that notice and the corresponding SVG sources with distribution. Packaging
and installation integration are a later step; this change installs nothing
into the current user's font directories or desktop.
