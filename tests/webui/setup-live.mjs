import {mkdir, readFile, writeFile, access} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';

const root = resolve(process.argv[2]);
const instances = ['svelte', 'preact'];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const clients = [];

for (const [index, framework] of instances.entries()) {
    const base = resolve(root, framework);
    const home = resolve(base, 'home');
    const marker = resolve(base, '.syncshell-port-fixture');
    await mkdir(base, {recursive: true});
    try {
        await access(home);
        await access(marker);
    } catch {
        try { await access(home); throw new Error('Existing unmarked home'); }
        catch (error) { if (error.code !== 'ENOENT') throw error; }
        execFileSync('syncthing', ['generate', '--home', home, '--no-port-probing'],
            {stdio: 'ignore'});
        await writeFile(marker, 'disposable Syncthing framework parity fixture\n');
        let xml = await readFile(resolve(home, 'config.xml'), 'utf8');
        xml = xml.replace(/<gui\b[\s\S]*?<\/gui>/, gui => gui.replace(
            /<address>.*?<\/address>/, `<address>127.0.0.1:${18401 + index}</address>`));
        for (const tag of ['globalAnnounceEnabled', 'localAnnounceEnabled',
            'relaysEnabled', 'natEnabled', 'startBrowser']) {
            xml = xml.replace(new RegExp(`<${tag}>.*?</${tag}>`, 'g'), `<${tag}>false</${tag}>`);
        }
        xml = xml.replace(/<listenAddress>.*?<\/listenAddress>/g,
            `<listenAddress>tcp://127.0.0.1:${18411 + index}</listenAddress>`);
        xml = xml.replace(/<urAccepted>.*?<\/urAccepted>/, '<urAccepted>-1</urAccepted>');
        await writeFile(resolve(home, 'config.xml'), xml, {mode: 0o600});
    }
    const unit = `syncshell-port-${framework}`;
    let active = false;
    try { active = execFileSync('systemctl', ['--user', 'is-active', unit],
        {encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore']}).trim() === 'active'; }
    catch {}
    if (!active) execFileSync('systemd-run', ['--user', `--unit=${unit}`, '--collect',
        '--property=Restart=on-failure', '--setenv=STGUIASSETS=' + resolve(base, 'gui'),
        '/usr/bin/syncthing', 'serve', '--home', home, '--no-browser', '--no-restart',
        '--no-upgrade'], {stdio: 'ignore'});
    const xml = await readFile(resolve(home, 'config.xml'), 'utf8');
    const key = xml.match(/<apikey>(.*?)<\/apikey>/)[1];
    const url = `http://127.0.0.1:${18401 + index}`;
    const api = async (path, body) => {
        const response = await fetch(url + '/rest/' + path, {method: body ? 'PUT' : 'GET',
            headers: {'X-API-Key': key, 'Content-Type': 'application/json'},
            body: body ? JSON.stringify(body) : undefined});
        if (!response.ok) throw new Error(`${framework} ${path}: ${response.status}`);
        const text = await response.text();
        return text ? JSON.parse(text) : null;
    };
    let status;
    for (let attempt = 0; attempt < 50; attempt++) {
        try { status = await api('system/status'); break; } catch { await delay(100); }
    }
    if (!status) throw new Error(`${framework} did not start`);
    clients.push({api, id: status.myID, base, url});
}

for (const [index, client] of clients.entries()) {
    const other = clients[1 - index];
    const config = await client.api('config');
    const path = resolve(client.base, 'files');
    await mkdir(path, {recursive: true});
    if (!config.devices.some(device => device.deviceID === other.id)) {
        const device = await client.api('config/defaults/device');
        config.devices.push({...device, deviceID: other.id,
            name: instances[1 - index] + '-test',
            addresses: [`tcp://127.0.0.1:${18411 + 1 - index}`]});
    }
    if (!config.folders.some(folder => folder.id === 'port-verification')) {
        const folder = await client.api('config/defaults/folder');
        config.folders.push({...folder, id: 'port-verification', label: 'Port verification',
            path, fsWatcherEnabled: false, rescanIntervalS: 3600,
            devices: [{deviceID: client.id}, {deviceID: other.id}]});
    }
    config.devices.find(device => device.deviceID === client.id).name = instances[index] + '-test';
    await client.api('config', config);
    console.log(instances[index] + ': ' + client.url);
}
