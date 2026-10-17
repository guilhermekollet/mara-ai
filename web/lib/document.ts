import { Instrument_Sans, Instrument_Serif, JetBrains_Mono } from "next/font/google";
import { locales } from "@/i18n/dictionaries";

// Shared by every full HTML document the site renders: the language pages and the 404 page.

// Sans for text, serif for headings, mono for identifiers.
const instrumentSans = Instrument_Sans({
  variable: "--font-instrument-sans",
  subsets: ["latin"],
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains-mono",
  subsets: ["latin"],
});

const instrumentSerif = Instrument_Serif({
  variable: "--font-instrument-serif",
  subsets: ["latin"],
  weight: "400",
});

export const htmlClassName = `${instrumentSans.variable} ${instrumentSerif.variable} ${jetbrainsMono.variable} antialiased`;

// Sets the theme before the first paint: the saved choice or, if there is none, the system's.
export const themeScript = `(function(){try{var t=localStorage.getItem("theme");if(t!=="light"&&t!=="dark"){t=matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light"}document.documentElement.dataset.theme=t}catch(e){document.documentElement.dataset.theme="light"}})()`;

// Same value next.config.ts uses for basePath. Plain links and inline scripts need it spelled out;
// next/link adds it on its own.
export const basePath = process.env.PAGES_BASE_PATH ?? "";

// The published address of the site, for links that have to be absolute (hreflang, canonical).
// The deploy workflow passes the Pages origin in; locally it falls back to the published one.
export const siteUrl = `${process.env.PAGES_ORIGIN ?? "https://guilhermekollet.github.io"}${basePath}`;

// The same page in every language, for search engines: each language page, plus the root URL as
// the x-default, since it sends visitors to the language of their browser.
export function languageAlternates(canonical: string) {
  return {
    canonical: `${siteUrl}${canonical}`,
    languages: {
      ...Object.fromEntries(locales.map((locale) => [locale, `${siteUrl}/${locale}/`])),
      "x-default": `${siteUrl}/`,
    },
  };
}
