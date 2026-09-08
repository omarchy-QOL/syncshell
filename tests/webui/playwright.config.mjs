import {defineConfig} from '@playwright/test';

export default defineConfig({
    testDir: '.', testMatch: '*.spec.mjs', workers: 1, timeout: 30000,
    use: {headless: true, viewport: {width: 1908, height: 954},
        launchOptions: {executablePath: '/usr/bin/chromium'}, trace: 'retain-on-failure'},
    projects: [
        {name: 'svelte', use: {baseURL: 'http://127.0.0.1:18401'}},
        {name: 'preact', use: {baseURL: 'http://127.0.0.1:18402'}}
    ]
});
