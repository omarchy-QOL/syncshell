local Palette = {}

function Palette.read(host)
    local colors = {}
    for key, role in { background = "surface", surface = "surface", surfaceVariant = "surface_variant",
        foreground = "on_surface", muted = "on_surface_variant", accent = "primary", success = "tertiary",
        warning = "secondary", danger = "error", border = "outline", info = "primary" } do
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

function Palette.signature(colors)
    local parts = {}
    for _, key in { "mode", "background", "surface", "surfaceVariant", "foreground", "muted",
        "accent", "success", "warning", "danger", "border", "info" } do table.insert(parts, colors[key]) end
    return table.concat(parts, ":")
end

return Palette
