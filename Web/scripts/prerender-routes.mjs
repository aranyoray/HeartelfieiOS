// Emit real static HTML for each client-side route so a direct URL load
// (e.g. App Store / Play Store opening /privacy) returns 200 without relying
// on Vercel rewrite config. Copies the built SPA shell (dist/index.html) into
// dist/<route>/index.html; React Router then renders the correct page from the
// URL. Static files are served by Vercel's filesystem ahead of any rewrite.
import { mkdir, copyFile, access } from 'node:fs/promises'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const dist = join(dirname(fileURLToPath(import.meta.url)), '..', 'dist')
const routes = ['privacy', 'support', 'terms']
const shell = join(dist, 'index.html')

await access(shell) // fail the build loudly if the SPA shell is missing

for (const route of routes) {
  const dir = join(dist, route)
  await mkdir(dir, { recursive: true })
  await copyFile(shell, join(dir, 'index.html'))
  console.log(`prerender: /${route} -> dist/${route}/index.html`)
}
