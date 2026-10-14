import { notFound } from "next/navigation";
import { CaptionDemo } from "@/components/caption-demo";
import { PrivacyArt, type PrivacyArtName } from "@/components/privacy-art";
import { CountUp, RevealObserver } from "@/components/motion-bits";
import { HeroWaves } from "@/components/hero-waves";
import { ThemeToggle } from "@/components/theme-toggle";
import { Brand } from "@/components/brand";
import { AppleLogo, LinearLogo, Mark } from "@/components/mark";
import { LanguageSwitcher } from "@/components/language-switcher";
import { getDictionary, hasLocale, locales, type Dictionary } from "@/i18n/dictionaries";

const pill =
  "press inline-flex h-9 items-center justify-center gap-2 rounded-full px-4 text-sm font-medium whitespace-nowrap hover:opacity-90";

// Entrance delay, in milliseconds, read by the animation CSS.
const after = (ms: number) => ({ "--d": `${ms}ms` }) as React.CSSProperties;
const pillLarge = "h-12 px-6 text-base";
const sectionTitle = "text-[clamp(28px,4vw,36px)] leading-[1.15] font-semibold tracking-tight";
const card = "rounded-2xl border border-fg/10 bg-surface p-6";

// Section anchors, in the order of the navigation. The ids stay the same in every language.
const NAV: { href: string; key: keyof Dictionary["nav"] }[] = [
  { href: "#como-funciona", key: "howItWorks" },
  { href: "#modulos", key: "modules" },
  { href: "#demandas", key: "tasks" },
  { href: "#privacidade", key: "privacy" },
  { href: "#faq", key: "faq" },
];

// Illustrations, in the order of the matching items in the dictionary.
const STEP_ART: PrivacyArtName[] = ["listen", "transcribe", "subtitle"];
const MODULE_ICONS = ["captions", "linear"];
const PRIVACY_ART: PrivacyArtName[] = ["transcription", "translation", "optional", "keychain", "files", "usage"];

// Public repository address. While it is empty, the "Contribute" section shows no GitHub button.
const REPO_URL = "https://github.com/guilhermekollet/mara-ai";

// Logos from the Simple Icons set, drawn in the text color, in the order of `contribute.badges`.
const OPEN_SOURCE = [
  {
    path: "M7.508 0c-.287 0-.573 0-.86.002-.241.002-.483.003-.724.01-.132.003-.263.009-.395.015A9.154 9.154 0 0 0 4.348.15 5.492 5.492 0 0 0 2.85.645 5.04 5.04 0 0 0 .645 2.848c-.245.48-.4.972-.495 1.5-.093.52-.122 1.05-.136 1.576a35.2 35.2 0 0 0-.012.724C0 6.935 0 7.221 0 7.508v8.984c0 .287 0 .575.002.862.002.24.005.481.012.722.014.526.043 1.057.136 1.576.095.528.25 1.02.495 1.5a5.03 5.03 0 0 0 2.205 2.203c.48.244.97.4 1.498.495.52.093 1.05.124 1.576.138.241.007.483.009.724.01.287.002.573.002.86.002h8.984c.287 0 .573 0 .86-.002.241-.001.483-.003.724-.01a10.523 10.523 0 0 0 1.578-.138 5.322 5.322 0 0 0 1.498-.495 5.035 5.035 0 0 0 2.203-2.203c.245-.48.4-.972.495-1.5.093-.52.124-1.05.138-1.576.007-.241.009-.481.01-.722.002-.287.002-.575.002-.862V7.508c0-.287 0-.573-.002-.86a33.662 33.662 0 0 0-.01-.724 10.5 10.5 0 0 0-.138-1.576 5.328 5.328 0 0 0-.495-1.5A5.039 5.039 0 0 0 21.152.645 5.32 5.32 0 0 0 19.654.15a10.493 10.493 0 0 0-1.578-.138 34.98 34.98 0 0 0-.722-.01C17.067 0 16.779 0 16.492 0H7.508zm6.035 3.41c4.114 2.47 6.545 7.162 5.549 11.131-.024.093-.05.181-.076.272l.002.001c2.062 2.538 1.5 5.258 1.236 4.745-1.072-2.086-3.066-1.568-4.088-1.043a6.803 6.803 0 0 1-.281.158l-.02.012-.002.002c-2.115 1.123-4.957 1.205-7.812-.022a12.568 12.568 0 0 1-5.64-4.838c.649.48 1.35.902 2.097 1.252 3.019 1.414 6.051 1.311 8.197-.002C9.651 12.73 7.101 9.67 5.146 7.191a10.628 10.628 0 0 1-1.005-1.384c2.34 2.142 6.038 4.83 7.365 5.576C8.69 8.408 6.208 4.743 6.324 4.86c4.436 4.47 8.528 6.996 8.528 6.996.154.085.27.154.36.213.085-.215.16-.437.224-.668.708-2.588-.09-5.548-1.893-7.992z",
  },
  {
    path: "M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701",
  },
  {
    path: "M11.959.447A11.938 11.938 0 000 12.407c0 5.576 3.874 10.097 7.783 11.114.193.05.392-.05.467-.234l2.771-6.822a.396.396 0 00-.246-.528C9.365 15.47 8.53 14.32 8.48 12.4c-.024-1.828 1.5-3.45 3.561-3.447 1.931.003 3.479 1.632 3.479 3.453 0 .966-.203 1.687-.575 2.238-.371.552-.922.951-1.695 1.239a.396.396 0 00-.23.515l2.685 6.903a.396.396 0 00.465.24C20.163 22.534 24 18.062 24 12.406 24 5.804 18.603.447 11.959.447zm0 .791c6.22 0 11.25 4.997 11.25 11.168 0 5.138-3.423 9.208-6.895 10.272L13.9 16.47c.703-.308 1.302-.79 1.702-1.384.477-.708.709-1.602.709-2.68 0-2.266-1.898-4.24-4.27-4.244-2.48-.004-4.382 1.976-4.352 4.25.023 1.995.934 3.492 2.451 4.13L7.648 22.66C4.251 21.592.791 17.458.791 12.406A11.13 11.13 0 0111.959 1.238z",
  },
  {
    path: "M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12",
  },
];

type Status = "progress" | "review" | "todo" | "done";

// Status colors from Linear's dark theme.
const STATUS_COLOR: Record<Status, string> = {
  progress: "#f2c94c",
  review: "#4cb782",
  todo: "#e2e2e2",
  done: "#5e6ad2",
};

// Priority following Linear's convention: 1 urgent, 2 high, 3 medium, 4 low. `item` points to the
// title and due date in `tasks.mock.items`.
type DemandCard = { id: string; item: number; owner: string; priority: number; sent: boolean };

const DEMAND_GROUPS: { status: Status; items: DemandCard[] }[] = [
  { status: "progress", items: [{ id: "MAR-128", item: 0, owner: "Sarah Kim", priority: 1, sent: true }] },
  { status: "review", items: [{ id: "MAR-127", item: 1, owner: "", priority: 2, sent: true }] },
  { status: "todo", items: [{ id: "MAR-14", item: 2, owner: "James Miller", priority: 3, sent: false }] },
];

const CYCLE_STATS: { value: number; key: keyof Dictionary["tasks"]["mock"]["stats"]; status: Status }[] = [
  { value: 6, key: "open", status: "todo" },
  { value: 3, key: "progress", status: "progress" },
  { value: 2, key: "review", status: "review" },
  { value: 9, key: "done", status: "done" },
];

// Status and priority icons drawn like Linear's.
function StatusIcon({ status, className }: { status: Status; className?: string }) {
  const color = STATUS_COLOR[status];
  return (
    <svg viewBox="0 0 14 14" aria-hidden="true" className={`shrink-0 ${className ?? "size-3"}`}>
      {status === "done" ? (
        <>
          <circle cx="7" cy="7" r="6.75" fill={color} />
          <path d="m4.2 7.2 1.9 1.9 3.8-4.1" fill="none" stroke="#0d0d0d" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
        </>
      ) : (
        <circle cx="7" cy="7" r="6" fill="none" stroke={color} strokeWidth="1.5" />
      )}
      {/* Half filled for "in progress" and three-quarters for "in review". */}
      {status === "progress" && <path d="M7 7V3.500a3.5 3.5 0 0 1 0 7Z" fill={color} />}
      {status === "review" && <path d="M7 7V3.500a3.5 3.5 0 1 1-3.5 3.500Z" fill={color} />}
    </svg>
  );
}

function PriorityIcon({ priority }: { priority: number }) {
  if (priority === 1) {
    return (
      <svg viewBox="0 0 16 16" aria-hidden="true" className="size-3.5 shrink-0">
        <rect x="1" y="1" width="14" height="14" rx="3" fill="#fb773f" />
        <path d="M8 4.200v4.600M8 11.400v.2" stroke="#0d0d0d" strokeWidth="1.8" strokeLinecap="round" />
      </svg>
    );
  }
  // High lights three bars, medium two, low one.
  const lit = 5 - priority;
  return (
    <svg viewBox="0 0 16 16" aria-hidden="true" className="size-3.5 shrink-0">
      {[0, 1, 2].map((bar) => (
        <rect key={bar} x={1.5 + bar * 5} y={8 - bar * 3} width="3" height={6 + bar * 3} rx="1" fill="#e2e2e2" opacity={bar < lit ? 1 : 0.3} />
      ))}
    </svg>
  );
}

// Avatar with the assignee's initials, like the one in the corner of Linear's cards.
function Avatar({ name }: { name: string }) {
  const initials = name
    .split(" ")
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
  const hues = [262, 205, 160, 28, 340, 120];
  const hue = hues[[...name].reduce((sum, char) => sum + char.charCodeAt(0), 0) % hues.length];
  return (
    <span
      className="grid size-[18px] place-items-center rounded-full text-[7.5px] font-semibold text-ink"
      style={{ backgroundColor: `hsl(${hue} 55% 72%)` }}
    >
      {initials}
    </span>
  );
}

// Icons for the module cards, drawn as thin strokes in the accent color.
function ModuleIcon({ name }: { name: string }) {
  if (name === "linear") return <LinearLogo className="size-[18px]" />;
  const paths: Record<string, React.ReactNode> = {
    // A caption window with two lines of subtitles.
    captions: (
      <>
        <rect x="3" y="5" width="18" height="14" rx="3" />
        <path d="M7 11h4M14 11h3M7 15h10" />
      </>
    ),
    // Code brackets.
    code: <path d="m8 7-5 5 5 5M16 7l5 5-5 5M14 4l-4 16" />,
  };
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      className="size-5"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {paths[name]}
    </svg>
  );
}

function SectionHead({ title, text }: { title: string; text?: string }) {
  return (
    <div data-reveal className="mx-auto mb-12 max-w-[620px] text-center">
      <h2 className={sectionTitle}>{title}</h2>
      {text && <p className="mt-3 text-[19px] text-fg/70">{text}</p>}
    </div>
  );
}

export function generateStaticParams() {
  return locales.map((lang) => ({ lang }));
}

export default async function Home({ params }: PageProps<"/[lang]">) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  const t = getDictionary(lang);
  const mock = t.tasks.mock;

  return (
    <>
      <header className="sticky top-0 z-10 flex h-14 items-center gap-2 bg-bg px-4 sm:gap-8 sm:px-6">
        <Brand />
        <nav aria-label={t.a11y.sections} className="hidden gap-6 text-sm font-medium whitespace-nowrap lg:flex">
          {NAV.map((item) => (
            <a key={item.href} href={item.href} className="hover:text-fg/70">
              {t.nav[item.key]}
            </a>
          ))}
        </nav>
        <div className="ml-auto flex gap-1.5 sm:gap-2">
          <LanguageSwitcher current={lang} label={t.a11y.language} />
          <ThemeToggle label={t.a11y.toggleTheme} title={t.a11y.toggleThemeShort} />
          <a href={`${REPO_URL}/releases`} className={`${pill} bg-pill text-pill-fg max-sm:hidden`}>
            <AppleLogo />
            {t.download}
          </a>
          {/* On the narrowest phones the header keeps only the language and theme controls. */}
          <a href="#comecar" className={`${pill} bg-accent text-ink-soft max-sm:px-3 max-[359px]:hidden`}>
            {t.getStarted}
          </a>
        </div>
      </header>

      <main id="topo">
        <section className="relative overflow-hidden px-4 pt-[72px] text-center md:pt-[104px]">
          <HeroWaves />
          <p className="rise relative mb-5 text-sm font-medium text-fg/70">{t.hero.eyebrow}</p>
          <h1
            className="relative font-serif text-[clamp(44px,7vw,72px)] leading-[1.02] tracking-[-0.035em]"
          >
            {t.hero.title}
          </h1>
          <p className="rise relative mx-auto mt-5 max-w-[520px] text-[19px] text-fg/70" style={after(480)}>
            {t.hero.text}
          </p>
          <div className="rise relative mt-9 flex flex-wrap justify-center gap-3" style={after(620)}>
            <a href={`${REPO_URL}/releases`} className={`${pill} ${pillLarge} bg-pill text-pill-fg`}>
              <AppleLogo />
              {t.download}
            </a>
            <a href="#como-funciona" className={`${pill} ${pillLarge} bg-fog text-fg`}>
              {t.hero.seeHow}
            </a>
          </div>
          <div className="rise relative" style={after(780)}>
            <CaptionDemo labels={{ label: t.a11y.captionDemo, you: t.demo.you, youInitials: t.demo.youInitials }} />
          </div>
        </section>

        <section id="como-funciona" className="mx-auto max-w-[1120px] px-6 py-16 md:py-24">
          <SectionHead title={t.steps.title} text={t.steps.text} />
          <div className="grid gap-4 md:grid-cols-3">
            {t.steps.items.map((step, index) => (
              <article key={step.title} data-reveal style={after(index * 90)} className={`${card} group`}>
                <div className="mb-5 grid h-[168px] place-items-center rounded-xl bg-bg">
                  <PrivacyArt name={STEP_ART[index]} />
                </div>
                <p className="mb-1.5 text-xs font-medium text-fg/50">
                  {t.steps.step} {index + 1}
                </p>
                <h3 className="text-[19px] font-semibold tracking-tight">{step.title}</h3>
                <p className="mt-2 text-fg/70">{step.text}</p>
              </article>
            ))}
          </div>
        </section>

        <section id="modulos" className="mx-auto max-w-[1120px] px-6 py-16 md:py-24">
          <SectionHead title={t.modules.title} text={t.modules.text} />
          <div className="mx-auto grid max-w-[880px] gap-4 md:grid-cols-2">
            {t.modules.items.map((module, index) => (
              <article key={module.title} data-reveal style={after(index * 90)} className={`${card} md:min-h-[250px]`}>
                <div className="mb-5 flex items-center justify-between">
                  <span className="grid size-10 place-items-center rounded-xl bg-accent-soft text-(--accent-line)">
                    <ModuleIcon name={MODULE_ICONS[index]} />
                  </span>
                  <span className="inline-block rounded-full bg-accent px-2.5 py-1 text-xs font-medium text-ink-soft">
                    {t.modules.available}
                  </span>
                </div>
                <h3 className="text-[19px] font-semibold tracking-tight">{module.title}</h3>
                <p className="mt-2 text-fg/70">{module.text}</p>
                {module.points.length > 0 && (
                  <ul className="mt-4 border-t border-fg/10 pt-4 text-sm font-medium">
                    {module.points.map((point) => (
                      <li key={point} className="flex items-center gap-2.5 py-[3px]">
                        <i className="size-[7px] shrink-0 rounded-full bg-accent" />
                        {point}
                      </li>
                    ))}
                  </ul>
                )}
              </article>
            ))}
          </div>
        </section>

        <section className="bg-mist px-6 py-16 md:py-24">
          <div className="mx-auto grid max-w-[1120px] items-center gap-14 md:grid-cols-2">
            <div data-reveal>
              <p className="mb-5 text-sm font-medium text-fg/70">{t.band.eyebrow}</p>
              <h2 className={sectionTitle}>{t.band.title}</h2>
              <p className="mt-4 text-lg text-fg/70">{t.band.text}</p>
              <dl className="mt-7 grid gap-3.5">
                <div>
                  <dt className="font-semibold">{t.band.draft}</dt>
                  <dd className="mt-0.5 text-fg/70">{t.band.draftText}</dd>
                </div>
                <div>
                  <dt className="font-semibold">{t.band.final}</dt>
                  <dd className="mt-0.5 text-fg/70">{t.band.finalText}</dd>
                </div>
              </dl>
            </div>
            <div data-reveal style={after(120)} aria-hidden="true" className="rounded-[32px] bg-linear-160 from-stage-from to-stage-to px-6 py-14">
              <div className="rounded-2xl bg-ink/90 px-6 py-[18px] text-center shadow-[0_20px_50px_rgba(0,0,0,0.35)]">
                <p className="text-[clamp(16px,2.2vw,22px)] leading-[1.3] font-medium text-paper">
                  Podemos revisar o contrato na quinta-feira.
                </p>
                <p className="mt-1.5 text-[clamp(16px,2.2vw,22px)] leading-[1.3] font-medium text-accent">
                  {"E eu acho que o prazo de entrega".split(" ").map((word, index) => (
                    <span key={index}>
                      <span className="word-loop" style={after(index * 260)}>
                        {word}
                      </span>{" "}
                    </span>
                  ))}
                </p>
                <p className="mt-2 text-[13px] text-paper/45 italic">And I think the delivery timeline…</p>
              </div>
            </div>
          </div>
        </section>

        <section id="demandas" className="mx-auto max-w-[1120px] px-6 py-16 md:py-24">
          <div className="grid items-center gap-14 md:grid-cols-2">
            <div data-reveal aria-hidden="true" className="rounded-[32px] bg-linear-160 from-stage-from to-stage-to p-5 sm:p-10">
              <div className="rounded-2xl bg-ink/90 p-4 shadow-[0_20px_50px_rgba(0,0,0,0.35)]">
                <div className="mb-3 flex items-center gap-1.5 px-1 text-[12px] font-semibold text-paper">
                  <LinearLogo className="size-[11px]" />
                  Cycle 42
                  <span className="ml-auto text-[11px] font-normal text-paper/50">{mock.deliveries}</span>
                </div>
                <div className="grid grid-cols-4 gap-1.5">
                  {CYCLE_STATS.map((stat) => (
                    <div key={stat.key} className="rounded-[9px] bg-paper/5 px-2 py-1.5">
                      <p className="flex items-center gap-1 text-[15px] font-semibold text-paper tabular-nums">
                        <StatusIcon status={stat.status} className="size-[9px]" />
                        <CountUp value={stat.value} />
                      </p>
                      <p className="text-[9.5px] text-paper/50">{mock.stats[stat.key]}</p>
                    </div>
                  ))}
                </div>
                <div className="mt-4 grid gap-3">
                  {DEMAND_GROUPS.map((group) => (
                    <div key={group.status}>
                      <p className="mb-1.5 flex h-8 items-center gap-2 rounded-md bg-white/[0.04] pr-2.5 pl-2.5 text-[13px] font-medium text-paper">
                        <StatusIcon status={group.status} className="size-3.5" />
                        {mock.status[group.status]}
                        <span className="font-normal text-[#8a8f98] tabular-nums">{group.items.length}</span>
                        <span className="ml-auto text-[15px] leading-none font-normal text-[#8a8f98]">+</span>
                      </p>
                      <ul className="grid gap-1.5">
                        {group.items.map((demand) => (
                          <li key={demand.id} className="rounded-lg border border-white/[0.08] bg-white/[0.035] px-3 py-2.5">
                            <div className="flex items-center justify-between">
                              <span className="font-mono text-[11px] text-[#8a8f98]">{demand.id}</span>
                              <Avatar name={demand.owner || t.demo.you} />
                            </div>
                            <p className="mt-2 flex items-start gap-[7px] text-[13px] leading-[1.35] font-medium text-paper">
                              <StatusIcon status={group.status} className="mt-[2px] size-3.5" />
                              {mock.items[demand.item].title}
                            </p>
                            <div className="mt-2 flex flex-wrap items-center gap-1.5 text-[11.5px] text-[#8a8f98]">
                              <span className="grid size-[22px] place-items-center rounded-[5px] border border-white/[0.08]">
                                <PriorityIcon priority={demand.priority} />
                              </span>
                              <span className="inline-flex h-[22px] items-center rounded-full border border-white/[0.08] px-[7px]">
                                {mock.items[demand.item].due}
                              </span>
                              <span
                                className={`ml-auto inline-flex h-[22px] items-center gap-1.5 rounded-full px-2 font-medium whitespace-nowrap ${demand.sent ? "border border-white/[0.08] text-paper" : "border border-accent/60 text-accent"}`}
                              >
                                <LinearLogo className="size-[11px]" />
                                {demand.sent ? mock.status[group.status] : mock.send}
                              </span>
                            </div>
                          </li>
                        ))}
                      </ul>
                    </div>
                  ))}
                </div>
              </div>
            </div>
            <div data-reveal style={after(120)}>
              <p className="mb-5 text-sm font-medium text-fg/70">{t.tasks.eyebrow}</p>
              <h2 className={sectionTitle}>{t.tasks.title}</h2>
              <p className="mt-4 text-lg text-fg/70">{t.tasks.text}</p>
              <dl className="mt-7 grid gap-3.5">
                {t.tasks.points.map((point, index) => (
                  <div key={point.title}>
                    <dt className="flex items-center gap-2 font-semibold">
                      {/* The last point is the one about sending to Linear. */}
                      {index === t.tasks.points.length - 1 && <LinearLogo className="size-3.5" />}
                      {point.title}
                    </dt>
                    <dd className="mt-0.5 text-fg/70">{point.text}</dd>
                  </div>
                ))}
              </dl>
            </div>
          </div>
        </section>

        <section id="privacidade" className="mx-auto max-w-[1120px] px-6 py-16 md:py-24">
          <SectionHead title={t.privacy.title} text={t.privacy.text} />
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {t.privacy.items.map((fact, index) => (
              <article
                key={fact.title}
                data-reveal
                style={after((index % 3) * 90)}
                className={`${card} group`}
              >
                <div className="mb-5 grid h-[168px] place-items-center rounded-xl bg-bg">
                  <PrivacyArt name={PRIVACY_ART[index]} />
                </div>
                <h3 className="text-[17px] font-semibold tracking-tight">{fact.title}</h3>
                <p className="mt-1.5 text-[15px] text-fg/70">{fact.text}</p>
              </article>
            ))}
          </div>
        </section>

        <section id="faq" className="mx-auto max-w-[760px] px-6 py-16 md:py-24">
          <SectionHead title={t.faq.title} />
          <div>
            {t.faq.items.map((item) => (
              <details key={item.question} data-reveal className="group border-b border-fg/10">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 py-5 text-[17px] font-medium [&::-webkit-details-marker]:hidden">
                  {item.question}
                  <span className="text-[22px] font-normal text-fg/70 transition-transform duration-300 group-open:rotate-45">
                    +
                  </span>
                </summary>
                <p className="pr-8 pb-5 text-fg/70">{item.answer}</p>
              </details>
            ))}
          </div>
        </section>

        <section id="contribua" className="mx-auto max-w-[760px] px-6 py-16 text-center md:py-24">
          <ul data-reveal className="mb-10 flex flex-wrap items-start justify-center gap-x-10 gap-y-6">
            {OPEN_SOURCE.map((item, index) => (
              <li key={item.path} className="flex w-[92px] flex-col items-center gap-2.5 text-fg/75">
                <svg viewBox="0 0 24 24" aria-hidden="true" className="size-7 fill-current">
                  <path d={item.path} />
                </svg>
                <span className="text-[13px] leading-tight">{t.contribute.badges[index]}</span>
              </li>
            ))}
          </ul>
          <div data-reveal style={after(100)}>
            <h2 className={sectionTitle}>{t.contribute.title}</h2>
            <p className="mx-auto mt-3 max-w-[520px] text-[17px] text-fg/70">{t.contribute.text}</p>
            {REPO_URL && (
              <div className="mt-8 flex justify-center">
                <a href={REPO_URL} className={`${pill} ${pillLarge} bg-pill text-pill-fg`}>
                  {t.contribute.github}
                </a>
              </div>
            )}
          </div>
        </section>

        <section id="comecar" className="px-6 py-[120px] text-center md:py-[200px]">
          <div data-reveal className="mb-8 flex justify-center">
            <Mark className="size-14 text-fg" motion="live" />
          </div>
          <h2 className="font-serif text-[clamp(40px,6vw,56px)] leading-[1.05] tracking-[-0.03em]">{t.final.title}</h2>
          <p className="mt-4 text-[19px] text-fg/70">{t.final.text}</p>
          <div className="mt-9 flex justify-center">
            <a href={`${REPO_URL}/releases`} className={`${pill} ${pillLarge} bg-pill text-pill-fg`}>
              <AppleLogo />
              {t.download}
            </a>
          </div>
        </section>
      </main>

      <RevealObserver />
      <footer className="mx-auto flex max-w-[1120px] flex-wrap items-center gap-x-8 gap-y-4 border-t border-fg/10 px-6 py-10 text-sm">
        <Brand />
        <nav aria-label={t.a11y.footer} className="flex flex-wrap gap-6 font-medium">
          {NAV.map((item) => (
            <a key={item.href} href={item.href} className="hover:text-fg/70">
              {t.nav[item.key]}
            </a>
          ))}
        </nav>
        <p className="text-fg/70 md:ml-auto">{t.footer}</p>
      </footer>
    </>
  );
}
