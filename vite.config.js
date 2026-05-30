import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'

// Multi-page setup: every HTML page is its own entry point so that
// `npm run build` outputs all of them into dist/.
export default defineConfig({
  plugins: [tailwindcss()],
  build: {
    rollupOptions: {
      input: {
        main: 'index.html',
        about: 'about_me.html',
        contact: 'contact.html',
        projects: 'project.html',
        resume: 'resume.html',
      },
    },
  },
})
