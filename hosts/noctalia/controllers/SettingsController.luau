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
    if settings.lifecycleAuthorized and settings.lifecycleUnit and settings.lifecycleUnit ~= "" then
        for _, arg in { "--lifecycle-authorized", "--lifecycle-kind", "systemd-user", "--lifecycle-unit", settings.lifecycleUnit } do
            table.insert(args, arg)
        end
        if settings.lifecycleConfig and settings.lifecycleConfig ~= "" then
            table.insert(args, "--lifecycle-config")
            table.insert(args, settings.lifecycleConfig)
        end
    end
    return args
end

-- Noctalia merges every *.toml in its config folder, so this adapter can own one
-- file, as Omarchy's plugin does. Noctalia's settings window takes precedence.
function Settings.filePath(host)
    local home = host.getenv("NOCTALIA_CONFIG_HOME") or host.getenv("XDG_CONFIG_HOME")
        or ((host.getenv("HOME") or "") .. "/.config")
    return home .. "/noctalia/syncshell.toml"
end

function Settings.template(host)
    return '# Syncshell for Noctalia. Saved changes apply right away. Values changed in\n'
        .. "# Noctalia's own settings window take precedence over this file.\n"
        .. '[plugin_settings."syncshell/syncshell"]\n\n'
        .. '# Use the branded icon instead of the plain theme-colored one.\n'
        .. 'brandedIcon = ' .. tostring(host.getConfig("brandedIcon") == true) .. '\n\n'
        .. '# Web UI: "default", "modern" or "themed" (follows Noctalia\'s colors).\n'
        .. 'webUi = "' .. tostring(host.getConfig("webUi") or "default") .. '"\n\n'
        .. '# Start and stop control for this systemd user unit.\n'
        .. '# lifecycleAuthorized = true\n# lifecycleUnit = "syncthing.service"\n\n'
        .. '# Run the service at login: "enabled" or "disabled".\n# serviceState = "enabled"\n\n'
        .. '# Seconds between refreshes (60-3600) and service probes (1-3600).\n# refreshSeconds = 60\n# probeSeconds = 15\n'
end

return Settings
