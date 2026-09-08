import {defineConfig} from 'vite';
import preact from '@preact/preset-vite';
export default defineConfig({base: './', publicDir: false, plugins: [preact()], build: {outDir: 'dist', assetsDir: 'assets/compiled', target: 'es2022'}});
