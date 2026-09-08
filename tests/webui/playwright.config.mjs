import {defineConfig} from '@playwright/test';

export default defineConfig({
    testDir: '.', testMatch: '*.spec.mjs', workers: 1, timeout: 30000,
    use: {headless: true, viewport: {width: 1908, height: 954},
        launchOptions: process.env.SYNCSHELL_CHROMIUM
            ? {executablePath: process.env.SYNCSHELL_CHROMIUM} : {},
        trace: 'retain-on-failure'},
    projects: [{name: 'webui', use: {
        baseURL: process.env.SYNCSHELL_WEBUI_URL || 'http://127.0.0.1:18401'}}]
});
