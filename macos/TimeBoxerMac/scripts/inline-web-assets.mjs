import path from 'node:path'
import { readFile, writeFile } from 'node:fs/promises'

const webRoot = process.argv[2]

if (!webRoot) {
  throw new Error('Usage: node inline-web-assets.mjs <WebApp directory>')
}

const indexPath = path.join(webRoot, 'index.html')
let html = await readFile(indexPath, 'utf8')

const scriptMatch = html.match(/<script type="module" src="([^"]+)"><\/script>/)
const styleMatch = html.match(/<link rel="stylesheet" href="([^"]+)">/)

if (!scriptMatch || !styleMatch) {
  throw new Error('Could not locate the Vite JavaScript and stylesheet tags')
}

const resolveAsset = (relativePath) => path.join(webRoot, relativePath.replace(/^\.\//, ''))
const javascript = (await readFile(resolveAsset(scriptMatch[1]), 'utf8'))
  .replace(/<\/script/gi, '<\\/script')
const stylesheet = (await readFile(resolveAsset(styleMatch[1]), 'utf8'))
  .replace(/<\/style/gi, '<\\/style')

html = html
  .replace(scriptMatch[0], () => `<script type="module">\n${javascript}\n</script>`)
  .replace(styleMatch[0], () => `<style>\n${stylesheet}\n</style>`)
  .replace(/\s*<link rel="icon"[^>]*>/, '')

if (!html.includes(javascript) || !html.includes(stylesheet)) {
  throw new Error('Inline asset verification failed')
}

await writeFile(indexPath, html)
