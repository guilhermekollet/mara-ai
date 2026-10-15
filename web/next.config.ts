import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The site is published as static files on GitHub Pages: `next build` writes them to `out/`.
  output: "export",
  // On GitHub Pages the site lives under /mara-ai. The deploy workflow passes that path in;
  // locally it stays empty, so `npm run dev` still serves the site at the root.
  basePath: process.env.PAGES_BASE_PATH ?? "",
  // Each page is written as a folder with an index.html (pt/index.html), which GitHub Pages
  // serves at both /pt and /pt/; a pt.html file would answer only /pt, and /pt/ would be a 404.
  trailingSlash: true,
  // Lets app/global-not-found.tsx be the 404 page: the site has no single root layout (each
  // language has its own <html lang>), so a regular not-found.tsx has nothing to render inside.
  experimental: { globalNotFound: true },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
