import {cp, mkdir, readFile, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, 'dist');
for (const path of ['assets', 'vendor/bootstrap/css', 'vendor/fork-awesome']) {
    await cp(resolve(root, 'modern', path), resolve(output, path), {recursive: true});
}
await cp(resolve(root, 'LICENSE.syncthing'), resolve(output, 'LICENSE.syncthing'));
await cp(resolve(root, 'licenses'), resolve(output, 'licenses'), {recursive: true});
for (const theme of ['dark', 'light']) {
    const target = resolve(output, 'assets/css', `syncshell-${theme}.css`);
    await mkdir(resolve(output, 'assets/css'), {recursive: true});
    await cp(resolve(root, 'themes', `${theme}.css`), target);
}
const css = await readFile(resolve(root, 'modern/assets/css/theme.css'), 'utf8');
await writeFile(resolve(output, 'assets/css/theme.css'), css.replaceAll(
    /\.\.\/\.\.\/theme-assets\/(dark|light)\/assets\/css\/theme.css/g,
    'syncshell-$1.css'));
