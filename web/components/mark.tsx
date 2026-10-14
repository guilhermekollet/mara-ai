// The brand's dot-matrix "M"; the center dot is the lavender accent.
const DOTS = [
  [10, 10], [54, 10],
  [10, 21], [21, 21], [43, 21], [54, 21],
  [10, 32], [54, 32],
  [10, 43], [54, 43],
  [10, 54], [54, 54],
];

// `motion` turns on the shimmer wave across the dots: "live" all the time, "hover" only on hover.
export function Mark({ className, motion }: { className?: string; motion?: "live" | "hover" }) {
  // The delay grows with the column, so the wave runs from left to right.
  const delay = (cx: number) => ({ "--d": `${Math.round((cx / 64) * 600)}ms` }) as React.CSSProperties;
  return (
    <svg
      viewBox="0 0 64 64"
      aria-hidden="true"
      className={`overflow-visible ${motion ? `mark-${motion}` : ""} ${className ?? ""}`}
    >
      <g fill="currentColor">
        {DOTS.map(([cx, cy]) => (
          <circle key={`${cx}-${cy}`} cx={cx} cy={cy} r={4} style={delay(cx)} />
        ))}
      </g>
      <circle cx={32} cy={32} r={4} className="fill-accent" style={delay(32)} />
    </svg>
  );
}

// The name's letters in the same dot matrix as the "M". Only the M is uppercase: the lowercase
// letters are one row shorter (the top row stays empty) and narrower.
const GLYPHS: Record<string, string[]> = {
  M: ["x...x", "xx.xx", "x.o.x", "x...x", "x...x"],
  a: ["....", ".xxx", "x..x", "x..x", ".xxx"],
  r: ["...", "x.x", "xx.", "x..", "x.."],
};

// The full name "Mara" in dots; "o" marks the lavender accent dot, at the center of the M.
export function Wordmark({ className, motion }: { className?: string; motion?: "live" | "in" | "out" }) {
  const pitch = 11;
  const gap = 14; // space between letters
  const dots: { key: string; cx: number; cy: number; accent: boolean }[] = [];
  let left = 10;
  for (const [position, letter] of ["M", "a", "r", "a"].entries()) {
    const rows = GLYPHS[letter];
    rows.forEach((row, y) =>
      [...row].forEach((cell, x) => {
        if (cell !== ".") dots.push({ key: `${position}-${x}-${y}`, cx: left + x * pitch, cy: 10 + y * pitch, accent: cell === "o" });
      }),
    );
    left += (rows[0].length - 1) * pitch + gap + pitch;
  }
  const width = left - gap - pitch + 10;
  return (
    <svg
      viewBox={`0 0 ${width} 64`}
      role="img"
      aria-label="Mara"
      className={`overflow-visible ${motion ? `mark-${motion}` : ""} ${className ?? ""}`}
    >
      {dots.map((dot) => (
        <circle
          key={dot.key}
          cx={dot.cx}
          cy={dot.cy}
          r={4}
          className={dot.accent ? "fill-accent" : "fill-current"}
          style={
            {
              "--d": `${Math.round((dot.cx / width) * 520)}ms`,
              "--d-back": `${Math.round((1 - dot.cx / width) * 520)}ms`,
            } as React.CSSProperties
          }
        />
      ))}
    </svg>
  );
}

// Apple logo for the macOS download buttons.
export function AppleLogo() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className="-mt-0.5 size-[1.05em] shrink-0 fill-current">
      <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701" />
    </svg>
  );
}

// Linear logo (Simple Icons set).
export function LinearLogo({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className={`shrink-0 fill-current ${className ?? "size-3"}`}>
      <path d="M2.886 4.18A11.982 11.982 0 0 1 11.99 0C18.624 0 24 5.376 24 12.009c0 3.64-1.62 6.903-4.18 9.105L2.887 4.18ZM1.817 5.626l16.556 16.556c-.524.33-1.075.62-1.65.866L.951 7.277c.247-.575.537-1.126.866-1.65ZM.322 9.163l14.515 14.515c-.71.172-1.443.282-2.195.322L0 11.358a12 12 0 0 1 .322-2.195Zm-.17 4.862 9.823 9.824a12.02 12.02 0 0 1-9.824-9.824Z" />
    </svg>
  );
}
