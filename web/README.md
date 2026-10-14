# Mara AI website

Live at **https://guilhermekollet.github.io/mara-ai/**.

The marketing site for [Mara AI](../README.md), built with Next.js (App Router), TypeScript,
Tailwind CSS 4 and Motion.

```bash
npm install
npm run dev      # http://localhost:3000
npm run build    # static export to out/
```

## Deploy

Every push to `main` that touches `web/` publishes the site to GitHub Pages through
`.github/workflows/pages.yml`. The site is a static export (`output: "export"`), so it needs no
server; the workflow sets `PAGES_BASE_PATH` so links work under `/mara-ai`.

- Page content lives in `app/page.tsx`; the copy is in Brazilian Portuguese.
- Design tokens (colors, fonts, light and dark themes) are in `app/globals.css`.
- Components: `components/` (caption demo, brand mark, illustrations, background waves).
- If a change to `app/globals.css` doesn't show up, stop the dev server, delete `.next` and start it
  again — the dev server doesn't always reload that file.
