import { localeInfo, locales } from "@/i18n/dictionaries";

const base = process.env.PAGES_BASE_PATH ?? "";

// Shown only without JavaScript; otherwise the layout's script has already redirected.
export default function RootPage() {
  return (
    <noscript>
      <ul>
        {locales.map((locale) => (
          <li key={locale}>
            <a href={`${base}/${locale}`} lang={localeInfo[locale].htmlLang}>
              Mara AI — {localeInfo[locale].name}
            </a>
          </li>
        ))}
      </ul>
    </noscript>
  );
}
