import type { Metadata } from "next";
import Script from "next/script";
import { defaultLocale, locales } from "@/i18n/dictionaries";

export const metadata: Metadata = {
  title: "Mara AI",
};

// Same value next.config.ts uses for basePath, so the redirect works on GitHub Pages and locally.
const base = process.env.PAGES_BASE_PATH ?? "";

// The site is static, so the language is picked in the browser: the one chosen in the switcher,
// if any, then the first of the browser's languages the site has, then English.
const redirectScript = `(function(){var s=${JSON.stringify(locales)},l;try{l=localStorage.getItem("lang")}catch(e){}if(s.indexOf(l)<0){l=${JSON.stringify(defaultLocale)};var n=navigator.languages&&navigator.languages.length?navigator.languages:[navigator.language||""];for(var i=0;i<n.length;i++){var p=String(n[i]).slice(0,2).toLowerCase();if(s.indexOf(p)>=0){l=p;break}}}location.replace(${JSON.stringify(base)}+"/"+l+location.hash)})()`;

// The root URL only sends visitors to their language, so it has its own bare layout.
export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <head>
        <meta name="color-scheme" content="light dark" />
      </head>
      <body>
        <Script id="language-redirect" strategy="beforeInteractive">
          {redirectScript}
        </Script>
        {children}
      </body>
    </html>
  );
}
