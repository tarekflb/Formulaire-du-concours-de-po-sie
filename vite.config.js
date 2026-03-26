import { defineConfig } from 'vite'

export default defineConfig({
  root: '.',
  server: {
    port: 8080,
    host: '0.0.0.0'
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true
  }
})
