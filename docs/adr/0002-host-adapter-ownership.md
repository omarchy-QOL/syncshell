# Keep presentation and platform behavior in host adapters

The native core owns host-neutral Syncthing state and actions. Each host adapter
owns its native presentation, settings, package behavior, notifications,
pickers, URLs, paths, and removal flow. Root `Panel.qml` and `Service.qml`
remain the stable Omarchy entry boundary so the plugin retains its native
manifest and bar placement. Plugin updates take effect after the user's
ordinary shell restart. The current panel and service evolve together without
supporting mixed versions during the interval before restart.

`shared/CoreProcess.qml` owns the child-process contract.
`shared/AdapterService.qml` and `shared/DeviceWorkflow.qml` provide common
state and actions for DMS, Illogical Impulse, Caelestia, and Waybar. Their
views remain host-native. Omarchy keeps its richer facade and settings because
those behaviors are specific to its plugin contract.

Shared code stops at process, state, action, and compact workflow behavior.
Layout and shell controls remain in each adapter instead of being forced
through a generic visual abstraction.
