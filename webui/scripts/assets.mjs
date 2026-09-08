import {cp, mkdir, readFile, writeFile, rm, readdir} from 'node:fs/promises';
import {resolve, relative} from 'node:path';
import {createHash} from 'node:crypto';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, 'dist');
const shipped = resolve(root, 'modern');
for (const path of ['assets', 'vendor/bootstrap/css', 'vendor/bootstrap/fonts', 'vendor/fork-awesome',
    'vendor/HumanizeDuration.js/humanize-duration.js', 'vendor/HumanizeDuration.js/LICENSE.txt']) {
    await cp(resolve(shipped, path), resolve(output, path), {recursive: true});
}
await cp(resolve(root, 'LICENSE.syncthing'), resolve(output, 'LICENSE.syncthing'));
await cp(resolve(root, 'licenses'), resolve(output, 'licenses'), {recursive: true});
for (const theme of ['dark', 'light']) {
    const target = resolve(output, 'assets/css', `syncshell-${theme}.css`);
    await mkdir(resolve(output, 'assets/css'), {recursive: true});
    await cp(resolve(root, 'themes', `${theme}.css`), target);
}
const css = await readFile(resolve(shipped, 'assets/css/theme.css'), 'utf8');
await writeFile(resolve(output, 'assets/css/theme.css'), css.replaceAll(
    /\.\.\/\.\.\/theme-assets\/(dark|light)\/assets\/css\/theme.css/g,
    'syncshell-$1.css'));
// Only generated chunks are replaced; static sources stay in one shipped tree.
await rm(resolve(shipped, 'compiled'), {recursive: true, force: true});
await cp(resolve(output, 'compiled'), resolve(shipped, 'compiled'), {recursive: true});
await cp(resolve(output, 'index.html'), resolve(shipped, 'index.html'));
async function files(directory) {
    const result = [];
    for (const entry of await readdir(directory, {withFileTypes: true})) {
        const path = resolve(directory, entry.name);
        if (entry.isDirectory()) result.push(...await files(path));
        else if (entry.isFile()) result.push(path);
        else throw new Error('Unexpected asset link: ' + path);
    }
    return result;
}
const paths = [resolve(root, 'LICENSE.syncthing'), ...await files(shipped),
    ...await files(resolve(root, 'themes')), ...await files(resolve(root, 'licenses'))];
const sums = [];
for (const path of paths.sort()) {
    const digest = createHash('sha256').update(await readFile(path)).digest('hex');
    sums.push(digest + '  ' + relative(root, path));
}
await writeFile(resolve(root, 'SHA256SUMS'), sums.join('\n') + '\n');
