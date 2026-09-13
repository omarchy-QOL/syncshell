# 0.1.8 release notes

- A native Go core for Syncthing monitoring and service controls.
- A Preact Web UI with grouped details, notifications and Omarchy theme support.
- Conflict review (beta), with local folder opening and guarded renaming.
- Settings migration with validation, a preview and an exact backup.
- SyncThingy Flatpak detection alongside native Syncthing installations.
- Stable folder status through zero-work Syncthing preparation transitions.
- A refined 400-pixel panel with fixed interface actions, consistent tooltips
  and visible status-refresh feedback.

## Thanks

Thanks to [@baranskyi](https://github.com/baranskyi) for the themed bar icon
contrast and rendering improvements in
[#47](https://github.com/omarchy-QOL/syncshell/pull/47).

Thanks also to [@whelanh](https://github.com/whelanh) for contributing
SyncThingy Flatpak detection in
[#48](https://github.com/omarchy-QOL/syncshell/pull/48). His full commit is
retained, with a separate adaptation to the Go core. SyncThingy manages its
own startup; desktop file actions remain unsupported inside Flatpak.

Thanks to [@dawez](https://github.com/dawez) for removing transient
`sync-preparing` status flicker in
[#101](https://github.com/omarchy-QOL/syncshell/pull/101).
