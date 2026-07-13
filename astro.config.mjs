import { defineConfig } from 'astro/config';

const repository = process.env.GITHUB_REPOSITORY?.split('/')[1];
const owner = process.env.GITHUB_REPOSITORY_OWNER;
const isProjectPage = Boolean(repository && !repository.endsWith('.github.io'));
const projectBase = isProjectPage ? `/${repository}` : '/';
const site =
  process.env.SITE_URL ||
  (owner ? `https://${owner}.github.io` : 'http://localhost:4321');
const base =
  process.env.BASE_PATH ||
  (process.env.GITHUB_ACTIONS ? projectBase : '/');

export default defineConfig({
  site,
  base,
  output: 'static',
  trailingSlash: 'always'
});