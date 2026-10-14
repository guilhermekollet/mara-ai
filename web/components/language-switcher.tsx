"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { localeInfo, locales, type Locale } from "@/i18n/dictionaries";

// Links to the same page in the other languages and remembers the choice, so the root URL sends
// this visitor straight to it next time instead of following the browser's language.
export function LanguageSwitcher({ current, label }: { current: Locale; label: string }) {
  const remember = (locale: Locale) => {
    try {
      localStorage.setItem("lang", locale);
    } catch {
      // No storage (private window): the root URL falls back to the browser's language.
    }
  };

  return (
    <nav aria-label={label} className="flex h-9 shrink-0 items-center gap-0.5 rounded-full bg-fog px-1">
      {locales.map((locale) => {
        const active = locale === current;
        return (
          <Link
            key={locale}
            href={`/${locale}`}
            hrefLang={localeInfo[locale].htmlLang}
            lang={localeInfo[locale].htmlLang}
            title={localeInfo[locale].name}
            aria-label={localeInfo[locale].name}
            aria-current={active ? "page" : undefined}
            onClick={() => remember(locale)}
            className={`grid size-7 place-items-center rounded-full transition-opacity ${active ? "bg-bg" : "opacity-55 hover:opacity-100"}`}
          >
            <Flag locale={locale} active={active} />
          </Link>
        );
      })}
    </nav>
  );
}

// Round flags drawn as SVG (emoji flags don't render on Windows): the United States for English,
// Brazil for Portuguese, Spain for Spanish. Simplified to read at 18 px.
const FLAGS: Record<Locale, ReactNode> = {
  en: (
    <>
      {[0, 1, 2, 3, 4, 5, 6].map((band) => (
        <rect key={band} x="0" y={(band * 20) / 7} width="20" height={20 / 7 + 0.05} fill={band % 2 ? "#ffffff" : "#b22234"} />
      ))}
      <rect x="0" y="0" width="10" height={(20 / 7) * 4} fill="#3c3b6e" />
      {[2.4, 5, 7.6].flatMap((cx) =>
        [2.6, 5.7, 8.8].map((cy) => <circle key={`${cx}-${cy}`} cx={cx} cy={cy} r="0.75" fill="#ffffff" />),
      )}
    </>
  ),
  pt: (
    <>
      <rect width="20" height="20" fill="#009b3a" />
      <path d="M1.5 10 10 3.6 18.5 10 10 16.4z" fill="#fedf00" />
      <circle cx="10" cy="10" r="4.1" fill="#002776" />
      <path d="M5.95 9.2c2.7-.5 5.6-.1 8.05 1.3" fill="none" stroke="#ffffff" strokeWidth="0.9" />
    </>
  ),
  es: (
    <>
      <rect width="20" height="20" fill="#c60b1e" />
      <rect y="5" width="20" height="10" fill="#ffc400" />
    </>
  ),
};

function Flag({ locale, active }: { locale: Locale; active: boolean }) {
  const clip = `flag-${locale}`;
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" className={`size-[18px] rounded-full ${active ? "ring-2 ring-accent" : "ring-1 ring-fg/15"}`}>
      <defs>
        <clipPath id={clip}>
          <circle cx="10" cy="10" r="10" />
        </clipPath>
      </defs>
      <g clipPath={`url(#${clip})`}>{FLAGS[locale]}</g>
    </svg>
  );
}
