# Changelog

Notable changes to Syncthing for Omarchy are documented here.

## Unreleased

- connect local conflict folder opening and guarded renaming to the desktop
  user, without changing permissions or replacing an existing destination
- label conflict resolution as beta and use a themed Syncshell header

- add a Preact Web UI with grouped folders/devices, notifications and
  API-based conflict discovery and rescans
- migrate older plugin settings with a preview and an exact backup while
  preserving valid preferences, comments, permissions and managed symlinks
- show folder error details and theme the selected Web UI address
- stop the rescan wait with an error when Syncthing becomes unavailable
- report rejected service actions immediately and keep their errors visible
- enforce the core crash-retry limit without blocking initial installation
  recovery, and disable unavailable actions after the core stops
- check existing tilde folder paths for overlap using Syncthing's own home
  directory; require absolute paths when their location cannot be determined
- resume file activity when Syncthing's event sequence resets on reconnect
  while preserving unread events from a surviving daemon
- match Syncthing home and config directory options consistently so service
  controls cannot target another instance through short option spellings
- replace the QML Syncthing engine with one parent-bound native Go core
- fix issue 45 by treating healthy external Syncthing instances as online
  without exposing controls for an unrelated inactive user service
- bundle one reproducible static Linux x86_64 executable with a public JSONL
  protocol and keep the panel's credentials, REST, events and lifecycle in Go
- make accepted single and global rescans visible immediately with rotating,
  inert controls and explicit optimistic folder state
- keep long-running accepted rescans from surfacing a false request timeout
- wait until targeted folders leave scanning before reporting rescan
  completion, so notices and the all-folders control follow the last folder
  rather than the HTTP accept
- show the bar sync overlay as soon as a plugin rescan is busy, not only
  after snapshot scanning arrives
- distinguish plain `SCANNING` from concurrent `SCAN+SYNC` during an accepted
  rescan
- require a shell restart after updating to load the current plugin while
  preserving settings and bar placement

## 0.1.7 - 2026-08-31

- reconcile configured and systemd user-service startup states without changing
  the independent runtime start and stop controls (thanks @renews for reporting)
- add a configurable interval for detecting external systemd state changes
- add per-folder and all-folder rescans, a clearer host ID copy control, and
  remembered local host identity while Syncthing is stopped

## 0.1.6 - 2026-08-22

- Make live and indexed file activity accurate for additions, deletions,
  concurrent changes, and active folders.
- Refine folder management with pending offers, copyable Syncthing IDs, and
  explicit link, unlink, and forget actions.
- Add versioned icon preferences, live Omarchy Web UI theming, and clean plugin
  removal that can preserve settings.
- Refresh the preview and add four focused demo videos.

## 0.1.5 - 2026-08-20

- Add an optional theme-colored bar icon while keeping the Syncthing artwork as
  the default (@davidszp, @ilyaZar).

## 0.1.4 - 2026-08-16

- Support Syncthing installations with TLS enabled for the local API.
- Clarify installation state and simplify plugin instructions.

## 0.1.3 - 2026-08-15

- Add a demo video and improve the documentation.

## 0.1.2 - 2026-08-15

- Add folder management to the bar panel.

## 0.1.1 - 2026-08-14

- Keep Syncthing package management explicit and monitor existing installs.
- Show live file activity and refresh status after synchronization.

## 0.1.0 - 2026-08-12

- Initial release.
