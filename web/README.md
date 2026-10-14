# Mara AI website

The marketing site for [Mara AI](../README.md), built with Next.js (App Router), TypeScript,
Tailwind CSS 4 and Motion.

```bash
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
```

- Page content lives in `app/page.tsx`; the copy is in Brazilian Portuguese.
- Design tokens (colors, fonts, light and dark themes) are in `app/globals.css`.
- Components: `components/` (caption demo, brand mark, illustrations, background waves).
- If a change to `app/globals.css` doesn't show up, stop the dev server, delete `.next` and start it
  again — the dev server doesn't always reload that file.
