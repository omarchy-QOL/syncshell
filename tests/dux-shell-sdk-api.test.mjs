import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = fileURLToPath(new URL("..", import.meta.url));
const host = join(root, "hosts/dux-shell");

function qmlFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const path = join(directory, entry.name);
    if (entry.isDirectory())
      return qmlFiles(path);
    return entry.name.endsWith(".qml") ? [path] : [];
  });
}

const sources = qmlFiles(host).map(path => ({
  name: path.slice(host.length + 1), text: readFileSync(path, "utf8")
}));

// DMS 2.0 keeps these 1.6 names only as deprecated shims that log errors.
const deprecated = /\b(Dank(Button|ActionButton|Icon|SVGIcon|Slider|Toggle|TextField|TabBar|Flickable|ListView|Scrollbar|Dropdown|Tooltip|Modal))\s*\{/;
// The 2.0 surface roles follow user overrides; the raw palette does not.
const rawSurface = /Theme\.(surfaceContainer\w*|surfaceVariant)\b|Theme\.(surfaceText|surfaceVariantText|primaryText)\b|Qt\.alpha\(/;

test("DMS host uses the 2.0 control names", () => {
  for (const { name, text } of sources)
    assert.doesNotMatch(text, deprecated, name);
});

test("DMS controls come from qs.DCommon.Widgets", () => {
  for (const { name, text } of sources) {
    if (/^import qs\.Widgets$/m.test(text))
      assert.equal(name, "DuxShellPanel.qml", `${name} imports shell widgets`);
  }
  const panel = sources.find(source => source.name === "DuxShellPanel.qml").text;
  assert.match(panel, /DTooltip \{/);
});

test("DMS UI uses surface roles instead of the raw palette", () => {
  for (const { name, text } of sources)
    assert.doesNotMatch(text, rawSurface, name);
});

test("DMS manifest requires the 2.0 SDK", () => {
  const manifest = JSON.parse(readFileSync(join(root,
    "integrations/dux-shell/plugin.json"), "utf8"));
  assert.equal(manifest.requires_dms, ">=2.0.0");
});

test("settings set their required plugin ID", () => {
  const manifest = JSON.parse(readFileSync(join(root, "integrations/dux-shell/plugin.json"), "utf8"));
  const settings = sources.find(source => source.name === "ui/SettingsMenu.qml").text;
  assert.match(settings, new RegExp(`^\\s*pluginId: "${manifest.id}"$`, "m"));
});
