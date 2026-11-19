import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = fileURLToPath(new URL("../", import.meta.url));
const integration = join(root, "integrations/dux-shell");

test("the bounded Nix source selection assembles the same standalone payload", () => {
  const recipe = readFileSync(join(integration, "package.nix"), "utf8");
  const selection = recipe.match(/fileset = lib\.fileset\.unions \[([^]*?)\];/);
  assert.ok(selection, "review source coverage when changing the Nix fileset");
  const paths = selection[1].trim().split(/\s+/);
  const work = mkdtempSync(join(tmpdir(), "syncshell-dux-shell-nix-source-"));
  try {
    const source = join(work, "source");
    for (const entry of paths) {
      assert.match(entry, /^\.\.?\//);
      const original = resolve(integration, entry);
      const path = relative(root, original);
      assert.ok(path && !path.startsWith(".."));
      const destination = join(source, path);
      mkdirSync(dirname(destination), { recursive: true });
      cpSync(original, destination, { recursive: true });
    }
    for (const excluded of [".git", "TODO", "tests", "dist", "assets/01-folder-sync.mp4"])
      assert.equal(existsSync(join(source, excluded)), false);
    const output = join(work, "package");
    execFileSync("bash", [join(source, "integrations/dux-shell/assemble.sh"), output]);
    execFileSync("diff", ["-qr", output, join(root, "dist/dux-shell")]);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});
