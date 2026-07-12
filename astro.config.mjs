import { defineConfig } from 'astro/config';

const repository = process.env.GITHUB_REPOSITORY?.split('/')[1];
const owner = process.env.GITHUB_REPOSITORY_OWNER;
const projectBase = repository && !repository.endsWith('.github.io') ? `/` : '/';
const site = process.env.SITE_URL || (owner ? `https://.github.io` : 'http://localhost:4321');
const base = process.env.BASE_PATH || (process.env.GITHUB_ACTIONS ? projectBase : '/');

export default defineConfig({ site, base, output: 'static', trailingSlash: 'always' });
