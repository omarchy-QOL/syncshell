local Settings = {}

function Settings.read(host)
    local settings = {}
    for _, key in { "configPath", "endpoint", "credentialFile", "tlsCertificate", "expectedDeviceId",
        "insecureTls", "lifecycleAuthorized", "lifecycleUnit", "lifecycleConfig", "refreshSeconds",
        "probeSeconds", "serviceState", "webUi", "brandedIcon" } do
        settings[key] = host.getConfig(key)
    end
    return settings
end

function Settings.arguments(settings, pluginDir)
    local args = { "--desktop-authorized", "--web-profile-authorized", "--web-profile-owner", "noctalia",
        "--web-profile-bundle", pluginDir .. "/webui" }
    for key, flag in {
        configPath = "--config", endpoint = "--endpoint", credentialFile = "--credential-file",
        tlsCertificate = "--tls-certificate", expectedDeviceId = "--expected-device-id",
    } do
        if settings[key] and settings[key] ~= "" then
            table.insert(args, flag)
            table.insert(args, settings[key])
        end
    end
    if settings.insecureTls then table.insert(args, "--insecure-tls") end
    if settings.lifecycleAuthorized then
        for _, arg in { "--lifecycle-authorized", "--lifecycle-kind", "systemd-user",
            "--lifecycle-unit", settings.lifecycleUnit, "--lifecycle-config", settings.lifecycleConfig } do
            table.insert(args, arg)
        end
    end
    return args
end

return Settings
