import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// DailyDil web frontend. deck.gl renders the choropleth on its own WebGL canvas,
// so no external basemap tiles are required at runtime (fully self-contained).
export default defineConfig({
  plugins: [react()],
  build: {
    target: 'es2021',
    chunkSizeWarningLimit: 1500,
  },
})
