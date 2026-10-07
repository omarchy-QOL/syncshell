import Caelestia.Plugins

SettingsObject {
    property int schemaVersion: 1
    property string icon: "sync"
    property int probeSeconds: 15
    property int refreshSeconds: 60
    property string webUiStyle: "default"
    property bool lifecycleAuthorized: false
    property string lifecycleUnit: "syncthing.service"
    property string lifecycleConfig: ""
    property string configPath: ""
    property string endpoint: ""
    property string credentialFile: ""
    property string tlsCertificate: ""
    property string expectedDeviceId: ""
}
