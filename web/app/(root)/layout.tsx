import type { Metadata } from "next";
import { detectLocaleExpression } from "@/i18n/detect";
import { basePath, languageAlternates } from "@/lib/document";

export const metadata: Metadata = {
  title: "Mara AI",
  alternates: languageAlternates("/"),
};

// A plain inline script, not next/script: that one waits for the framework's JavaScript to load
// before it runs, and this has to leave for the visitor's language before anything else loads.
const redirectScript = `location.replace(${JSON.stringify(basePath)}+"/"+${detectLocaleExpression}+"/"+location.search+location.hash)`;

// The root URL only sends visitors to their language, so it has its own bare layout.
export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <head>
        <script id="language-redirect" dangerouslySetInnerHTML={{ __html: redirectScript }} />
        <meta name="color-scheme" content="light dark" />
      </head>
      <body>{children}</body>
    </html>
  );
}
