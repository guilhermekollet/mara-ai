"use client";

// Toggles between light and dark and remembers the choice. The initial theme is set by a script
// in <head> (see layout.tsx), before the first paint, so the page doesn't flash.
export function ThemeToggle() {
  const toggle = () => {
    const root = document.documentElement;
    const next = root.dataset.theme === "dark" ? "light" : "dark";
    root.dataset.theme = next;
    try {
      localStorage.setItem("theme", next);
    } catch {
      // No storage (private window): the choice only lasts until the page reloads.
    }
  };

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label="Alternar entre tema claro e escuro"
      title="Alternar tema"
      className="grid size-9 shrink-0 cursor-pointer place-items-center rounded-full bg-fog text-fg transition-opacity hover:opacity-85"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true" className="only-light size-4 fill-current">
        <path d="M20.3 14.4A8.5 8.5 0 0 1 9.6 3.700a.7.7 0 0 0-.9-.8 9.8 9.8 0 1 0 12.4 12.4.7.7 0 0 0-.8-.9Z" />
      </svg>
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="only-dark size-4 fill-none stroke-current"
        strokeWidth="1.8"
        strokeLinecap="round"
      >
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2.500v2M12 19.500v2M2.5 12h2M19.5 12h2M5.3 5.300l1.4 1.400M17.3 17.300l1.4 1.400M5.3 18.700l1.4-1.400M17.3 6.700l1.4-1.4" />
      </svg>
    </button>
  );
}
