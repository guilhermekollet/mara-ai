"use client";

import Link from "next/link";
import { useEffect, useId, useRef, useState, type ReactNode } from "react";
import { localeInfo, locales, type Dictionary, type Locale } from "@/i18n/dictionaries";
import { languageStorageKey } from "@/i18n/detect";

type Theme = "light" | "dark";

// The header's menu: the page language (round flags) and the light or dark appearance, in a small
// popover. Picking a language goes to that page and is remembered, so the root URL sends this
// visitor straight to it next time; picking an appearance is remembered too.
export function HeaderMenu({ current, copy, label }: { current: Locale; copy: Dictionary["menu"]; label: string }) {
  const [open, setOpen] = useState(false);
  const [theme, setTheme] = useState<Theme>("light");
  const root = useRef<HTMLDivElement>(null);
  const panel = useId();

  // The theme is set before hydration by the script in the layout; read it when the menu opens.
  useEffect(() => {
    if (open) setTheme(document.documentElement.dataset.theme === "dark" ? "dark" : "light");
  }, [open]);

  // Closes on a click outside or on Escape.
  useEffect(() => {
    if (!open) return;
    const onPointer = (event: PointerEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("pointerdown", onPointer);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const remember = (key: string, value: string) => {
    try {
      localStorage.setItem(key, value);
    } catch {
      // No storage (private window): the choice only lasts for this visit.
    }
  };

  const chooseTheme = (next: Theme) => {
    document.documentElement.dataset.theme = next;
    remember("theme", next);
    setTheme(next);
  };

  return (
    <div ref={root} className="relative">
      <button
        type="button"
        aria-label={label}
        title={label}
        aria-expanded={open}
        aria-controls={panel}
        onClick={() => setOpen((value) => !value)}
        className="grid size-9 shrink-0 cursor-pointer place-items-center rounded-full bg-fog text-fg transition-opacity hover:opacity-85"
      >
        <svg viewBox="0 0 16 16" aria-hidden="true" className="size-4" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
          <path d="M2.5 4.5h11M2.5 8h11M2.5 11.5h11" />
        </svg>
      </button>

      <div
        id={panel}
        role="group"
        aria-label={label}
        inert={!open}
        className={`absolute top-11 right-0 z-20 w-60 origin-top-right rounded-2xl border border-fg/10 bg-surface p-1.5 text-left shadow-[0_18px_50px_rgba(0,0,0,0.18)] transition-[opacity,transform] duration-150 ease-out ${open ? "scale-100 opacity-100" : "pointer-events-none scale-95 opacity-0"}`}
      >
        <p className="px-2.5 pt-1.5 pb-1 text-xs font-medium text-fg/55">{copy.language}</p>
        {locales.map((locale) => {
          const active = locale === current;
          return (
            <Link
              key={locale}
              href={`/${locale}`}
              hrefLang={localeInfo[locale].htmlLang}
              lang={localeInfo[locale].htmlLang}
              aria-current={active ? "page" : undefined}
              onClick={() => {
                remember(languageStorageKey, locale);
                setOpen(false);
              }}
              className="flex h-9 items-center gap-2.5 rounded-xl px-2.5 text-sm hover:bg-fog"
            >
              <Flag locale={locale} />
              <span className="flex-1">{localeInfo[locale].name}</span>
              {active && (
                <svg viewBox="0 0 16 16" aria-hidden="true" className="size-3.5 text-accent-line" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                  <path d="m3.5 8.5 3 3 6-7" />
                </svg>
              )}
            </Link>
          );
        })}

        <div className="mx-2.5 my-1.5 h-px bg-fg/10" />

        <p className="px-2.5 pt-0.5 pb-1.5 text-xs font-medium text-fg/55">{copy.appearance}</p>
        <div className="mx-1 mb-1 grid grid-cols-2 gap-1 rounded-full bg-fog p-1">
          {(["light", "dark"] as const).map((option) => {
            const active = theme === option;
            return (
              <button
                key={option}
                type="button"
                aria-pressed={active}
                onClick={() => chooseTheme(option)}
                className={`flex h-8 cursor-pointer items-center justify-center gap-1.5 rounded-full text-sm transition-colors ${active ? "bg-bg font-medium text-fg shadow-[0_1px_3px_rgba(0,0,0,0.12)]" : "text-fg/60 hover:text-fg"}`}
              >
                {option === "light" ? <Sun /> : <Moon />}
                {copy[option]}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

const Sun = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true" className="size-3.5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4" />
  </svg>
);

const Moon = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true" className="size-3.5 fill-current">
    <path d="M20.3 14.4A8.5 8.5 0 0 1 9.6 3.7a.7.7 0 0 0-.9-.8 9.8 9.8 0 1 0 12.4 12.4.7.7 0 0 0-.8-.9Z" />
  </svg>
);

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

function Flag({ locale }: { locale: Locale }) {
  const clip = `flag-${locale}`;
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" className="size-[18px] shrink-0 rounded-full ring-1 ring-fg/15">
      <defs>
        <clipPath id={clip}>
          <circle cx="10" cy="10" r="10" />
        </clipPath>
      </defs>
      <g clipPath={`url(#${clip})`}>{FLAGS[locale]}</g>
    </svg>
  );
}
