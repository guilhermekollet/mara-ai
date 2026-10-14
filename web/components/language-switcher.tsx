"use client";

import Link from "next/link";
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
    <nav aria-label={label} className="flex h-9 shrink-0 items-center rounded-full bg-fog px-1 text-xs font-medium">
      {locales.map((locale) => (
        <Link
          key={locale}
          href={`/${locale}`}
          hrefLang={localeInfo[locale].htmlLang}
          lang={localeInfo[locale].htmlLang}
          title={localeInfo[locale].name}
          aria-current={locale === current ? "page" : undefined}
          onClick={() => remember(locale)}
          className={`grid h-7 place-items-center rounded-full px-1.5 transition-colors sm:px-2 ${locale === current ? "bg-bg text-fg" : "text-fg/55 hover:text-fg"}`}
        >
          {localeInfo[locale].short}
        </Link>
      ))}
    </nav>
  );
}
