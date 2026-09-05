# Keep presentation and platform behavior in host adapters

The native core owns host-neutral Syncthing state and actions. Each host adapter
owns its native presentation, settings, package behavior, notifications,
pickers, URLs, paths, and removal flow. Root `Panel.qml` and `Service.qml`
remain the stable Omarchy entry boundary so the plugin retains its native
manifest and bar placement. Plugin updates take effect after the user's
ordinary shell restart. The current panel and service evolve together without
supporting mixed versions during the interval before restart.

A shared view model or generic platform abstraction is rejected for 0.1.8
because only Omarchy is supported and forwarding layers would create a second
owner without adding behavior.
