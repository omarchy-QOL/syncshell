local Palette = {}

-- The host has no success, warning or information roles, and its accents differ
-- per theme. Each meaning takes the accent nearest Omarchy's hue for it.
Palette.roles = {
    success = "tertiary", warning = "secondary", error = "error",
    info = "primary", muted = "on_surface_variant",
}

local function hue(color)
    if type(color) ~= "string" or not string.match(color, "^#%x%x%x%x%x%x$") then return nil end
    local r = tonumber(string.sub(color, 2, 3), 16) / 255
    local g = tonumber(string.sub(color, 4, 5), 16) / 255
    local b = tonumber(string.sub(color, 6, 7), 16) / 255
    local high, low = math.max(r, g, b), math.min(r, g, b)
    if high - low < 0.08 then return nil end
    local value
    if high == r then value = (g - b) / (high - low)
    elseif high == g then value = 2 + (b - r) / (high - low)
    else value = 4 + (r - g) / (high - low) end
    return (value * 60) % 360
end

function Palette.refresh(host)
    local hues = {}
    for _, role in { "primary", "secondary", "tertiary" } do
        hues[role] = hue(host.getColor(role))
        if not hues[role] then return end
    end
    for _, meaning in { { "warning", 50 }, { "success", 130 }, { "info", 190 } } do
        local best, distance = nil, math.huge
        for role, value in hues do
            local gap = math.abs(value - meaning[2])
            gap = math.min(gap, 360 - gap)
            if gap < distance then best, distance = role, gap end
        end
        Palette.roles[meaning[1]] = best
        hues[best] = nil
    end
end

function Palette.read(host)
    Palette.refresh(host)
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
