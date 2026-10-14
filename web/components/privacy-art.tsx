// Line illustrations for the privacy section: strokes in the text color and a single lavender
// accent. The art-* classes (in globals.css) animate each piece when the card is hovered.
const stroke = {
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};
const accent = { ...stroke, stroke: "var(--accent-line)", strokeWidth: 2 };
const tinted = { fill: "var(--accent-soft)", stroke: "var(--accent-line)", strokeWidth: 1.6 };

const ART = {
  // A MacBook with a call on screen and sound waves coming out of it.
  listen: (
    <>
      {/* screen, with the camera notch */}
      <rect x="24" y="10" width="68" height="46" rx="5" {...stroke} />
      <path d="M53 10v2.500a1.5 1.5 0 0 0 1.5 1.500h7a1.5 1.5 0 0 0 1.5-1.500V10" {...stroke} />
      {/* two participants on the call; the one speaking is highlighted */}
      <rect x="32" y="22" width="24" height="24" rx="4" {...stroke} opacity="0.5" />
      <rect x="60" y="22" width="24" height="24" rx="4" {...tinted} />
      {/* laptop base */}
      <path d="M14 56h88l-3.5 6.500a3 3 0 0 1-2.6 1.500H20.100a3 3 0 0 1-2.6-1.500L14 56Z" {...stroke} />
      <path d="M50 60h16" {...stroke} opacity="0.5" />
      {/* sound waves */}
      <path d="M106 26a10 10 0 0 1 0 16" {...accent} className="art-ripple" />
      <path d="M113 20a19 19 0 0 1 0 28" {...accent} className="art-ripple" style={{ animationDelay: "0.18s" }} />
      <path d="M120 14a28 28 0 0 1 0 40" {...accent} className="art-ripple" style={{ animationDelay: "0.36s" }} />
    </>
  ),
  // Speech turning into text, with the cursor on the last line.
  transcribe: (
    <>
      <rect x="30" y="10" width="80" height="66" rx="8" {...stroke} />
      <path d="M42 26h50M42 38h56" {...stroke} opacity="0.5" />
      <path d="M42 50h34" {...accent} className="art-draw" />
      <path d="M82 45v10" {...accent} className="art-cursor" />
      <path d="M42 62h18" {...stroke} opacity="0.25" />
    </>
  ),
  // Two bubbles: the original speech and the translated caption, arriving while the other is still talking.
  subtitle: (
    <>
      <path d="M24 16h54a6 6 0 0 1 6 6v16a6 6 0 0 1-6 6H40l-10 8v-8h-6a6 6 0 0 1-6-6V22a6 6 0 0 1 6-6Z" {...stroke} />
      <path d="M30 27h40M30 35h24" {...stroke} opacity="0.5" />
      <path
        d="M62 42h54a6 6 0 0 1 6 6v16a6 6 0 0 1-6 6h-6v8l-10-8H62a6 6 0 0 1-6-6V48a6 6 0 0 1 6-6Z"
        {...tinted}
        className="art-bob"
      />
      <path d="M66 53h42M66 61h26" {...accent} className="art-draw" />
    </>
  ),
  // A Mac with the voice wave inside the screen.
  transcription: (
    <>
      <rect x="34" y="12" width="72" height="46" rx="6" {...stroke} />
      <path d="M24 66h92" {...stroke} />
      {[
        [52, 34, 36],
        [60, 29, 41],
        [68, 24, 46],
        [76, 30, 40],
        [84, 33, 37],
      ].map(([x, top, bottom], index) => (
        <path
          key={x}
          d={`M${x} ${top}V${bottom}`}
          {...accent}
          className="art-wave"
          style={{ animationDelay: `${index * 0.12}s` }}
        />
      ))}
    </>
  ),
  // The original speech on top and the translated caption below.
  translation: (
    <>
      <rect x="26" y="10" width="88" height="24" rx="6" {...stroke} />
      <path d="M36 22h44" {...stroke} opacity="0.5" />
      <path d="M70 39v8m-4-4 4 4 4-4" {...accent} className="art-bob" />
      <rect x="26" y="52" width="88" height="24" rx="6" {...tinted} />
      <path d="M36 64h56" {...accent} className="art-draw" />
    </>
  ),
  // An on/off switch with the GPT sparkle next to it.
  optional: (
    <>
      <rect x="30" y="28" width="52" height="28" rx="14" {...tinted} />
      <circle cx="68" cy="42" r="9" fill="var(--accent-line)" className="art-knob" />
      <path d="M102 26c1 7 3 9 10 10-7 1-9 3-10 10-1-7-3-9-10-10 7-1 9-3 10-10Z" {...stroke} className="art-spark" />
      <path
        d="M112 54c.5 3 1.5 4 4.5 4.5-3 .5-4 1.5-4.5 4.5-.5-3-1.5-4-4.5-4.5 3-.5 4-1.5 4.5-4.500Z"
        {...stroke}
        className="art-spark"
        style={{ animationDelay: "0.3s" }}
      />
    </>
  ),
  // A padlock that closes, with the key turning inside.
  keychain: (
    <>
      <path d="M54 36V28a16 16 0 0 1 32 0v8" {...stroke} className="art-move art-shackle" />
      <rect x="44" y="36" width="52" height="38" rx="8" {...stroke} fill="var(--bg)" />
      <g className="art-move art-key">
        <circle cx="70" cy="51" r="5" {...tinted} strokeWidth="2" />
        <path d="M70 56v8m0-3h4" {...accent} />
      </g>
    </>
  ),
  // A folder with a document coming out of it.
  files: (
    <>
      <g className="art-move art-doc">
        <rect x="50" y="14" width="40" height="44" rx="4" {...stroke} fill="var(--bg)" />
        <path d="M58 25h24M58 33h24M58 41h14" {...accent} />
      </g>
      <path
        d="M28 40a6 6 0 0 1 6-6h16l6 8h50a6 6 0 0 1 6 6v20a6 6 0 0 1-6 6H34a6 6 0 0 1-6-6V40Z"
        {...stroke}
        fill="var(--bg)"
      />
    </>
  ),
  // A bar chart with today's bar growing, highlighted.
  usage: (
    <>
      <path d="M28 72h84" {...stroke} />
      <rect x="38" y="48" width="12" height="24" rx="3" {...stroke} />
      <rect x="58" y="36" width="12" height="36" rx="3" {...stroke} />
      <rect x="78" y="20" width="12" height="52" rx="3" {...tinted} className="art-move art-grow" />
      <rect x="98" y="42" width="12" height="30" rx="3" {...stroke} />
      <path d="M32 30c12-2 20 6 30 2s14-18 28-20" {...accent} strokeDasharray="1 5" className="art-march" />
    </>
  ),
};

export type PrivacyArtName = keyof typeof ART;

export function PrivacyArt({ name }: { name: PrivacyArtName }) {
  return (
    <svg viewBox="0 0 140 86" aria-hidden="true" className="art h-[114px] w-[186px] overflow-visible text-fg/70">
      {ART[name]}
    </svg>
  );
}
