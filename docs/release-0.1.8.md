# 0.1.8 release notes (draft)

- A native Go core for Syncthing monitoring and service controls.
- A Preact Web UI with grouped details, notifications and Omarchy theme support.
- Conflict review (beta), with local folder opening and guarded renaming.
- Settings migration with validation, a preview and an exact backup.

## Thanks

Thanks to [@baranskyi](https://github.com/baranskyi) for the themed bar icon
contrast and rendering improvements in
[#47](https://github.com/omarchy-QOL/syncshell/pull/47).

Thanks also to [@whelanh](https://github.com/whelanh) for proposing SyncThingy
Flatpak detection in [#48](https://github.com/omarchy-QOL/syncshell/pull/48).
That integration is pending and is not supported by this candidate yet.

## Before publication

- Confirm whether #48 is included. List Flatpak as supported only after the
  Go adaptation and verification pass.
- Preserve @whelanh's Git authorship when integrating his contribution; keep
  @baranskyi's existing authorship. Mentions alone do not add contributors to
  GitHub's contributor graph.
- Update the Flatpak status and publish these notes with the final release.
