import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';

export const referenceCommit = 'ec4e2a83dacb44fffbae376e2034028ddb76ad3d';
export function referenceSource(path) {
    if (process.env.SYNCSHELL_WEBUI_REFERENCE)
        return readFileSync(join(process.env.SYNCSHELL_WEBUI_REFERENCE, path), 'utf8');
    return execFileSync('git', ['show', referenceCommit + ':webui/modern/' + path],
        {cwd: fileURLToPath(new URL('../../', import.meta.url)), encoding: 'utf8'});
}
