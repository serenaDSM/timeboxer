import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const stripCrossOriginForFileEmbedding = {
  name: 'timeboxer-strip-crossorigin-for-file-embedding',
  enforce: 'post',
  transformIndexHtml: {
    order: 'post',
    handler(html) {
      return html.replace(/\s+crossorigin(?=[\s>])/g, '')
    },
  },
}

// https://vite.dev/config/
export default defineConfig({
  // Relative assets allow the production build to run inside a macOS WKWebView.
  base: './',
  plugins: [react(), tailwindcss({ optimize: false }), stripCrossOriginForFileEmbedding],
  build: {
    cssMinify: false,
  },
})
