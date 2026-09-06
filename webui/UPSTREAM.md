# Bundled Web UI

`modern/` starts from the complete Syncthing v2.1.3 `gui/default/` tree at
commit `946e2b83a1f6c6ae119427c09e0a5802940b82ff`:

https://github.com/syncthing/syncthing/tree/946e2b83a1f6c6ae119427c09e0a5802940b82ff/gui/default

Local changes in `modern/index.html` and `modern/assets/css/modern.css`
arrange the main page into Folders, Devices, and Notifications columns.
Device headers identify the local and remote devices. The original
notification templates and conditional actions are retained. Folder cards group
activity, configuration, and identification. A compact count filter truncates
summary totals to one decimal; a controller helper exposes exact comparison
rows when the folder is not up to date or its local/global totals differ.
Count tooltips show files, folders, and total size; the Shared menu opens
the existing device editor. The ignore-pattern information icon opens the
existing folder ignore editor.

`themes/` contains the unchanged `gui/{black,dark,light}/assets/css/theme.css`
files from the same commit. The default stylesheet imports dark/light CSS;
preparation redirects those imports to the bundled files.

It contains application code, templates, translations, fonts, images, and
vendor libraries. Syncthing serves these static files alongside its own
REST API, authentication, `meta.js`, QR endpoints, and `themes.json`.
Do not capture those live endpoints or credentials into this directory.

The browser assets are shared across operating systems. The daemon supplies
platform-specific values such as path separators. Omarchy's installer and
palette are separate from this portable frontend. The initial bundled UI
is tested against Syncthing v2.1.3; this is not a compatibility claim for every
older or future daemon version.

## Verification and updates

`SHA256SUMS` records the current shipped files. Verify it from this directory:

```bash
sha256sum --quiet --check SHA256SUMS
```

For an upstream update, check out an explicit release commit, compare its
complete `gui/default/` tree with our previous import, and apply our local
UI changes separately. Preserve vendor notices and review API differences.
Regenerate the shipped manifest after intentional asset changes:

```bash
find modern themes -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS
```

The initial import is preserved in Git history. Keep one maintained source
copy; generated runtime theme directories are not separate frontend forks.

## Licenses

Syncthing source is MPL-2.0; see `LICENSE.syncthing`. Its authors and software
attribution remain in the original About view and source headers. Retain those
notices and distribute modifications to covered files under their license.

Vendor notices remain under `modern/vendor/`. Raleway and Fork Awesome fonts
are unmodified and use SIL OFL-1.1; the full text and embedded-font attribution
are under `licenses/`. The plugin's MIT license does not replace these terms.
