import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, relative, resolve, sep } from "node:path";

const [packageRoot, fileList, importMapPath] = process.argv.slice(2);
if (!packageRoot || !fileList || !importMapPath)
  throw Error("usage: assemble-qml.mjs PACKAGE FILE_LIST IMPORT_MAP");
const root = resolve(packageRoot);
const imports = JSON.parse(readFileSync(importMapPath, "utf8"));
const files = readFileSync(fileList, "utf8").trim().split("\n");

for (const file of files) {
  const path = resolve(root, file);
  if (relative(root, path).startsWith(`..${sep}`))
    throw Error(`package path escapes root: ${file}`);
  const text = readFileSync(path, "utf8");
  const mapped = text.replace(/^(\s*\.?import\s+)("[^"\n]+"|[\w.]+)/gm,
    (line, prefix, source) => {
      const mapping = imports[dirname(file)] || imports;
      if (!Object.hasOwn(mapping, source))
        throw Error(`unmapped import in ${file}: ${source}`);
      const target = mapping[source];
      if (target.startsWith('"')) {
        const imported = resolve(dirname(path), JSON.parse(target));
        if (relative(root, imported).startsWith(`..${sep}`) || !existsSync(imported))
          throw Error(`missing or escaped packaged import in ${file}: ${target}`);
      }
      return prefix + target;
    });
  if (mapped !== text)
    writeFileSync(path, mapped);
}
