import type { Metadata } from "next";
import Script from "next/script";
import { Brand } from "@/components/brand";
import { HeroWaves } from "@/components/hero-waves";
import { getDictionary, localeInfo, locales } from "@/i18n/dictionaries";
import { detectLocaleExpression } from "@/i18n/detect";
import { basePath, htmlClassName, themeScript } from "@/lib/document";
import "./globals.css";

export const metadata: Metadata = {
  title: "404 — Mara AI",
};

// An unknown URL has no language in it, so the page carries the copy in every language and this
// script picks the visitor's (the same choice the root URL makes) before the first paint.
const languageScript = `(function(){var l=${detectLocaleExpression},h=${JSON.stringify(
  Object.fromEntries(locales.map((locale) => [locale, localeInfo[locale].htmlLang])),
)};document.documentElement.lang=h[l]})()`;

const pill =
  "press inline-flex h-12 items-center justify-center gap-2 rounded-full px-6 text-base font-medium whitespace-nowrap hover:opacity-90";

export default function GlobalNotFound() {
  return (
    <html lang="en" suppressHydrationWarning className={htmlClassName}>
      <body className="flex min-h-svh flex-col font-sans">
        <Script id="theme" strategy="beforeInteractive">
          {themeScript}
        </Script>
        <Script id="language" strategy="beforeInteractive">
          {languageScript}
        </Script>
        <header className="flex h-14 items-center px-4 sm:px-6">
          <Brand href={`${basePath}/`} />
        </header>
        <main className="relative flex flex-1 flex-col items-center overflow-hidden px-4 pt-[72px] pb-24 text-center md:pt-[104px]">
          <HeroWaves />
          {locales.map((locale) => {
            const copy = getDictionary(locale).notFound;
            return (
              <div key={locale} data-copy={locale} lang={localeInfo[locale].htmlLang} className="relative">
                <p className="mb-5 text-sm font-medium text-fg/70">{copy.eyebrow}</p>
                <h1 className="font-serif text-[clamp(44px,7vw,72px)] leading-[1.02] tracking-[-0.035em]">
                  {copy.title}
                </h1>
                <p className="mx-auto mt-5 max-w-[520px] text-[19px] text-fg/70">{copy.text}</p>
                <div className="mt-9 flex justify-center">
                  <a href={`${basePath}/${locale}`} className={`${pill} bg-pill text-pill-fg`}>
                    {copy.home}
                  </a>
                </div>
              </div>
            );
          })}
        </main>
      </body>
    </html>
  );
}
