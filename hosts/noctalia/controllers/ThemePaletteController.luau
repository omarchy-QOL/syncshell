local Palette = {}

-- The pinned host has no dedicated success, warning or information tokens.
Palette.roles = {
    success = "tertiary", warning = "secondary", error = "error",
    info = "primary", muted = "on_surface_variant",
}

function Palette.read(host)
    local colors = {}
    for key, role in { background = "surface", surface = "surface", surfaceVariant = "surface_variant",
        foreground = "on_surface", muted = Palette.roles.muted, accent = "primary",
        success = Palette.roles.success, warning = Palette.roles.warning,
        danger = Palette.roles.error, border = "outline", info = Palette.roles.info } do
        local color = host.getColor(role)
        if type(color) ~= "string" or not string.match(color, "^#%x%x%x%x%x%x$") then
            return nil, "Noctalia did not provide the required palette role: " .. role
        end
        colors[key] = color
    end
    local rgb = colors.background
    local brightness = tonumber(string.sub(rgb, 2, 3), 16) * 0.2126
        + tonumber(string.sub(rgb, 4, 5), 16) * 0.7152 + tonumber(string.sub(rgb, 6, 7), 16) * 0.0722
    colors.mode = brightness > 128 and "light" or "dark"
    return colors
end

-- Omarchy tints its mono icon; images have no tint here, so a themed copy is kept.
function Palette.statusIcon(host, variant)
    local base = host.pluginDir() .. "/assets/"
    if host.getConfig("brandedIcon") then return base .. "status-" .. variant .. ".svg" end
    local source = base .. "mono/status-" .. variant .. ".svg"
    local color, directory = host.getColor("on_surface"), host.pluginDataDir()
    if type(color) ~= "string" or not directory then return source end
    local path = directory .. "/icon-" .. string.sub(color, 2) .. "-" .. variant .. ".svg"
    if host.fileExists(path) then return path end
    local svg = host.readFile(source)
    if not svg or not host.writeFile(path, (string.gsub(svg, "#fff", color))) then return source end
    return path
end

function Palette.signature(colors)
    local parts = {}
    for _, key in { "mode", "background", "surface", "surfaceVariant", "foreground", "muted",
        "accent", "success", "warning", "danger", "border", "info" } do table.insert(parts, colors[key]) end
    return table.concat(parts, ":")
end

return Palette
