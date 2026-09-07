import {defineConfig} from 'vite';
import preact from '@preact/preset-vite';
export default defineConfig({base: './', publicDir: false, plugins: [preact()], build: {outDir: 'dist', target: 'es2022'}});
