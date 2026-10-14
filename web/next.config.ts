import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The site is published as static files on GitHub Pages: `next build` writes them to `out/`.
  output: "export",
  // On GitHub Pages the site lives under /mara-ai. The deploy workflow passes that path in;
  // locally it stays empty, so `npm run dev` still serves the site at the root.
  basePath: process.env.PAGES_BASE_PATH ?? "",
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
