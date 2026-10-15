"use client";

import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import type { Dictionary } from "@/i18n/dictionaries";

// The hero demo: Mara's floating captions window, used by a pointer, the same scene as the promo
// video (promo/src/MainPromo.tsx) rebuilt as live DOM. The pointer starts a session, a meeting is
// captioned word by word, the list is scrolled back and jumps to the new lines, and the window is
// resized while the captions keep coming. Then the meeting goes quiet and Mara goes on standby, as
// the app does after a stretch without audio: the moon opens large and faint in the middle of the
// window, then settles at the top in place of the sound bars, and the pointer passes over the
// window, bringing up the controls, until someone speaks again. Everything is drawn in macOS points and scaled as a whole with one fixed scale per
// viewport size: animating the scale would make the text shimmer.

type Copy = Dictionary["demo"];

const FPS = 30;
const LOOP = 1106; // frames, from the window appearing to it fading out
const H = 210; // window height in points before it is resized
const BLOCK = 46; // one caption block (translation, original and gap), in points
const STILL = 380; // the frame shown without animation (reduced motion, before hydration)
const ACCENT = "#b8a4f8";
const FAINT = "rgba(250,250,250,0.38)";
const system = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif';

const T = { start: 62, scrollFrom: 405, scrollTo: 428, arrow: 430, label: 490, jump: 535, exit: 1081 };
// The standby: it starts after the quiet that follows the seventh line, the moon rises to the top
// a moment later, and it ends when sound comes back, just before the last line.
const STANDBY = { on: 772, rise: 827, off: 980 };
const STARTS = [112, 182, 252, 322, 466, 572, 652, 992];
const LATE = 4; // the line that arrives while the list is scrolled back

// ——— Timing helpers ———

const clamp01 = (value: number) => Math.min(1, Math.max(0, value));
const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);
const easeIn = (t: number) => t * t * t;
const easeInOut = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
const easeOutBack = (t: number) => 1 + 2.70158 * Math.pow(t - 1, 3) + 1.70158 * Math.pow(t - 1, 2);
const progress = (frame: number, start: number, length = 14, ease = easeOut) => ease(clamp01((frame - start) / length));

// Interpolates through keyframes [frame, ...values], easing each leg.
function track(frame: number, keys: number[][]): number[] {
  const index = keys.findIndex((key) => key[0] > frame);
  if (index === -1) return keys[keys.length - 1].slice(1);
  if (index === 0) return keys[0].slice(1);
  const [from, to] = [keys[index - 1], keys[index]];
  const t = progress(frame, from[0], to[0] - from[0]);
  return from.slice(1).map((value, i) => value + (to[i + 1] - value) * t);
}

// When each word is spoken and each translated word shows up: the translation trails the speech
// by two words and catches up when the sentence ends, as in the app.
function timeline(copy: Copy) {
  return copy.phrases.map((phrase, index) => {
    const spoken = phrase.source.split(" ");
    const translated = phrase.target.split(" ");
    const saidAt: number[] = [];
    let t = STARTS[index];
    for (const word of spoken) {
      saidAt.push(t);
      t += 3 + word.length * 0.7 + (/[,.?]$/.test(word) ? 5 : 0);
    }
    const shownAt: number[] = [];
    spoken.forEach((_, i) => {
      const count = Math.floor((Math.max(i - 1, 0) / spoken.length) * translated.length);
      while (shownAt.length < count) shownAt.push(saidAt[i]);
    });
    const end = saidAt[saidAt.length - 1];
    for (let step = 1; shownAt.length < translated.length; step++) shownAt.push(end + 3 * step);
    return { spoken, translated, saidAt, shownAt, quietAt: end + 10, doneAt: shownAt[shownAt.length - 1] + 12 };
  });
}

type Line = ReturnType<typeof timeline>[number];

// Window height in points: dragging the bottom edge shrinks it, then grows it.
const HEIGHT = [
  [580, H],
  [604, 128],
  [616, 128],
  [650, 264],
];
const heightAt = (frame: number) => track(frame, HEIGHT)[0];

// The play button's center in window points (6 pt padding, the 24 pt globe, 2 pt gap).
const PLAY = { x: 44, y: 16 };
// A click as macOS draws it: the button darkens while the mouse is down, and the action happens on
// release. The pointer itself never changes size.
const pressedAt = (frame: number, at: number) => frame >= at - 3 && frame < at + 2;

// The pointer's path in window points, for a window `w` points wide.
const pointerPath = (w: number) => [
  [18, w + 80, 300],
  [52, PLAY.x, PLAY.y],
  [T.start + 10, PLAY.x, PLAY.y],
  [T.start + 40, w + 60, 250],
  [T.scrollFrom - 12, w + 60, 250],
  [T.scrollFrom, w * 0.54, 118],
  [T.label + 12, w * 0.54, 118],
  [T.jump - 8, w - 24, 186],
  [T.jump + 14, w - 24, 186],
  [570, w / 2, H],
  [580, w / 2, H],
  [604, w / 2, 128],
  [616, w / 2, 128],
  [650, w / 2, 264],
  [662, w / 2, 264],
  [700, w + 80, 340],
  // Back once the standby badge has risen. It shows up still, in the margin beside the window, and
  // only then moves in, so the controls clearly come up as it crosses the edge; then out again.
  [851, w + 18, 170],
  [860, w + 18, 170],
  [890, w * 0.64, 150],
  [906, w * 0.64, 150],
  [930, w + 18, 175],
];
const RESIZING = [570, 664];
const pointerVisible = (frame: number) => (frame >= 26 && frame < 694) || (frame >= 851 && frame < 940);

// ——— The component ———

export function CaptionWindowDemo({ copy }: { copy: Copy }) {
  const stage = useRef<HTMLDivElement>(null);
  const [frame, setFrame] = useState(STILL);
  const [width, setWidth] = useState(1100);
  const [lines] = useState(() => timeline(copy));

  // Fits the scene to the stage; the scale only changes when the layout does.
  useEffect(() => {
    const element = stage.current;
    if (!element) return;
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width));
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  // Plays at 30 fps from the still frame onwards, looping; pauses off screen and in background tabs.
  // In development, ?frame=800 holds the scene on that frame and ?start=800 plays it from there, to
  // review a moment without waiting for the loop to reach it.
  useEffect(() => {
    const element = stage.current;
    const review = process.env.NODE_ENV === "development" ? new URLSearchParams(location.search) : null;
    const pinned = review?.get("frame");
    if (pinned) {
      setFrame(Number(pinned) % LOOP);
      return;
    }
    const first = Number(review?.get("start") ?? STILL) % LOOP;
    if (!element || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let visible = true;
    const observer = new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
    });
    observer.observe(element);
    let elapsed = (first / FPS) * 1000;
    let previous = performance.now();
    let shown = first;
    let raf = requestAnimationFrame(function tick(now) {
      const delta = Math.min(now - previous, 100);
      previous = now;
      if (visible && !document.hidden) elapsed += delta;
      const next = Math.floor((elapsed / 1000) * FPS) % LOOP;
      if (next !== shown) {
        shown = next;
        setFrame(next);
      }
      raf = requestAnimationFrame(tick);
    });
    return () => {
      cancelAnimationFrame(raf);
      observer.disconnect();
    };
  }, []);

  // Wide screens show the window at 560 points; phones get a narrower window at a readable scale.
  const scale = Math.min(1.75, Math.max(0.8, (width - 48) / 560));
  const w = Math.min(560, (width - 24) / scale);
  const appear = progress(frame, 0, 16);
  const exit = progress(frame, T.exit, 24, easeIn);
  const path = pointerPath(w);
  const [px, py] = track(frame, path);
  const pointer = frame < 760
    ? Math.min(progress(frame, 18, 8), 1 - progress(frame, 694, 8))
    : Math.min(progress(frame, 851, 8), 1 - progress(frame, 930, 8));
  const resizing = frame >= RESIZING[0] && frame < RESIZING[1];

  return (
    <div className="relative mx-auto mt-16 max-w-[1440px] overflow-hidden rounded-3xl bg-linear-160 from-stage-from to-stage-to sm:rounded-[32px]">
      <div
        ref={stage}
        role="img"
        aria-label={copy.label}
        className="relative mx-3 sm:mx-6"
        style={{ height: (264 + 64) * scale, fontFamily: system }}
      >
        <div
          aria-hidden="true"
          style={{
            position: "absolute",
            left: (width - w * scale) / 2,
            top: 32 * scale,
            width: w,
            height: heightAt(frame),
            transformOrigin: "0 0",
            transform: `scale(${scale})`,
            opacity: appear * (1 - exit),
            filter: exit > 0 ? `blur(${exit * 10}px)` : undefined,
            color: "#fafafa",
          }}
        >
          <CaptionsWindow frame={frame} lines={lines} copy={copy} w={w} />
          {pointer > 0 &&
            (resizing ? (
              <ResizePointer x={px} y={py} />
            ) : (
              <Pointer x={px} y={py} opacity={pointer} />
            ))}
        </div>
      </div>
    </div>
  );
}

function CaptionsWindow({ frame, lines, copy, w }: { frame: number; lines: Line[]; copy: Copy; w: number }) {
  const started = lines.filter((line) => frame >= line.saidAt[0]);

  // Scrolling back drags the list down; the line that arrives meanwhile is added below without
  // moving what is being read; the jump button brings the list back to the bottom. Each other new
  // line slides in from below and pushes the older ones up, like the app's scroll.
  const dragged = 1.2 * BLOCK * progress(frame, T.scrollFrom, T.scrollTo - T.scrollFrom);
  const kept = frame >= lines[LATE].saidAt[0] ? BLOCK : 0;
  const back = progress(frame, T.jump, 16, easeInOut);
  const arriving = [...started].reverse().find((line) => line !== lines[LATE]);
  const slide = arriving ? BLOCK * (1 - progress(frame, arriving.saidAt[0], 14)) : 0;
  const offset = (dragged + kept) * (1 - back) + slide;

  const running = frame >= T.start;
  const barsIn = progress(frame, T.start + 2, 12);
  const toTop = progress(frame, lines[0].saidAt[0], 16);
  const speaking = lines.some((line) => frame >= line.saidAt[0] && frame < line.quietAt);
  // The standby badge opens in the middle, as the bars do when a session starts, with the captions
  // stepping back behind it; then it rises to the top in place of the bars, until sound returns.
  const standby = progress(frame, STANDBY.on, 14) * (1 - progress(frame, STANDBY.off, 10));
  const rise = progress(frame, STANDBY.rise, 18, easeInOut);
  const centered = standby * (1 - rise);
  const middle = heightAt(frame) / 2 - 13;

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        borderRadius: 18,
        overflow: "hidden",
        textAlign: "left",
        background: "rgba(10,10,12,0.86)",
        boxShadow: "0 40px 90px rgba(0,0,0,0.45), inset 0 0 0 1px rgba(250,250,250,0.09)",
      }}
    >
      <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", opacity: 0.45 * (1 - progress(frame, T.start, 10)) }}>
        <DotMark frame={frame} />
      </div>

      <div
        style={{
          position: "absolute",
          left: 16,
          right: 16,
          top: 0,
          bottom: 10,
          display: "flex",
          flexDirection: "column",
          justifyContent: "flex-end",
          maskImage: "linear-gradient(to bottom, transparent 0%, #000 28%, #000 100%)",
          opacity: 1 - 0.88 * centered,
        }}
      >
        <div style={{ display: "flex", flexDirection: "column", gap: 10, transform: `translateY(${offset}px)` }}>
          {started.map((line, index) => (
            <CaptionBlock key={index} frame={frame} line={line} next={started[index + 1]} />
          ))}
        </div>
      </div>

      {barsIn > 0 && (
        <div
          style={{
            position: "absolute",
            left: "50%",
            top: H / 2 - 13 + (3 - (H / 2 - 13)) * toTop,
            transform: `translateX(-50%) scale(${(1 - 0.5 * toTop) * (0.8 + 0.2 * barsIn)})`,
            transformOrigin: "center top",
            opacity: barsIn,
          }}
        >
          <div style={{ opacity: 1 - standby, transform: `scale(${1 - 0.15 * standby})` }}>
            <SoundBars frame={frame} level={speaking ? 0.45 + 0.35 * Math.abs(Math.sin(frame * 0.41)) * (0.6 + 0.4 * Math.sin(frame * 0.13)) : 0} />
          </div>
        </div>
      )}

      {standby > 0 && (
        <div
          style={{
            position: "absolute",
            left: "50%",
            top: middle + (3 - middle) * rise,
            transform: `translateX(-50%) scale(${(1 - 0.5 * rise) * (0.9 + 0.1 * standby)})`,
            transformOrigin: "center top",
            opacity: standby,
            filter: standby < 1 ? `blur(${(1 - standby) * 3}px)` : undefined,
          }}
        >
          <StandbyBadge label={copy.standby} />
        </div>
      )}

      <ControlBar frame={frame} running={running} w={w} />
      <JumpButton frame={frame} label={copy.jump} />
    </div>
  );
}

// One utterance. Live and final share the same markup, so nothing moves when a line turns final:
// only the color eases from lavender to white, and it dims once the next line starts.
function CaptionBlock({ frame, line, next }: { frame: number; line: Line; next?: Line }) {
  const final = frame >= line.doneAt;
  const dim = next ? progress(frame, next.saidAt[0], 12) : 0;
  const white = progress(frame, line.doneAt, 18);
  const color = final ? `rgb(${[184, 164, 248].map((v) => Math.round(v + (250 - v) * white)).join(",")})` : ACCENT;
  return (
    <div style={{ opacity: 1 - 0.4 * dim }}>
      <div style={{ fontSize: 17, fontWeight: 500, lineHeight: 1.25, color }}>
        {line.translated.map((word, index) => {
          const p = progress(frame, line.shownAt[index], 9);
          return (
            <span
              key={index}
              style={{ display: "inline-block", whiteSpace: "pre", opacity: p, filter: p < 1 ? `blur(${(1 - p) * 4}px)` : undefined, transform: `translateY(${(1 - p) * 3}px)` }}
            >
              {index < line.translated.length - 1 ? `${word} ` : word}
            </span>
          );
        })}
      </div>
      <div style={{ fontSize: 11, color: FAINT, marginTop: 1, fontStyle: final ? "normal" : "italic" }}>
        {line.spoken.map((word, index) => (
          <span key={index} style={{ opacity: progress(frame, line.saidAt[index], 6) }}>{`${word} `}</span>
        ))}
      </div>
    </div>
  );
}

// The app's dotted "M" in the empty window, with its lavender dot: the dots pop in from left to
// right as the window appears, as in the app.
const M_DOTS = ["x...x", "xx.xx", "x.x.x", "x...x", "x...x"];
function DotMark({ frame }: { frame: number }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(5, 4px)", gap: 1.8 }}>
      {M_DOTS.flatMap((row, r) =>
        [...row].map((mark, c) => {
          const p = progress(frame, 6 + c * 1.5 + r * 0.6, 10, easeOutBack);
          return (
            <i
              key={`${r}-${c}`}
              style={{
                width: 4,
                height: 4,
                borderRadius: 2,
                background: r === 2 && c === 2 ? ACCENT : "#fafafa",
                opacity: mark === "x" ? Math.min(1, p) : 0,
                transform: `scale(${0.3 + 0.7 * p})`,
              }}
            />
          );
        }),
      )}
    </div>
  );
}

// The app's standby badge (IdleBadge, large): the moon.zzz.fill symbol and its label, dimmed.
function StandbyBadge({ label }: { label: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 5, height: 26, whiteSpace: "nowrap", color: "rgba(250,250,250,0.45)" }}>
      <svg viewBox="0 0 20 18" style={{ width: 17, height: 15 }} fill="currentColor">
        <path d="M8.6 4.2a6.4 6.4 0 1 0 7.6 7.9 5.2 5.2 0 0 1-7.6-7.9z" />
        <path d="M12.2 1.5h3.4v.9l-2.1 2.4h2.2v1h-3.6v-.9l2.1-2.4h-2z" />
        <path d="M16.8 5.6h2.3v.7l-1.3 1.6h1.4v.8h-2.5v-.7l1.3-1.6h-1.2z" />
      </svg>
      <span style={{ fontSize: 13, fontWeight: 500 }}>{label}</span>
    </div>
  );
}

// The app's sound bars: five capsules that ripple in silence and rise with the voice.
function SoundBars({ frame, level }: { frame: number; level: number }) {
  const weights = [0.55, 0.85, 1.0, 0.75, 0.5];
  const speeds = [0.9, 1.3, 0.7, 1.1, 0.8];
  const tick = frame * 0.66;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 4, height: 26 }}>
      {weights.map((weight, index) => {
        const idle = 0.16 + 0.07 * Math.sin(tick * 0.12 + index * 0.9);
        const wobble = 0.65 + 0.35 * Math.sin(tick * speeds[index] + index * 1.7);
        const amount = Math.min(1, Math.max(0.14, idle + level * weight * wobble));
        return <i key={index} style={{ width: 4.7, height: 26 * amount, borderRadius: 99, background: "rgba(184,164,248,0.9)" }} />;
      })}
    </div>
  );
}

// Whether the pointer is over the window, and frames since it last entered or left (capped).
function hoverAt(frame: number, w: number) {
  const inside = (f: number) => {
    const [x, y] = track(f, pointerPath(w));
    return pointerVisible(f) && x >= 0 && x <= w && y >= 0 && y <= heightAt(f);
  };
  const now = inside(frame);
  for (let back = 1; back <= 30; back++) {
    if (inside(frame - back) !== now) return { now, since: back - 1 };
  }
  return { now, since: 30 };
}

// The controls show only while the pointer is over the window: on hover they come in one by one,
// from the left; when it leaves they fade out together.
function ControlBar({ frame, running, w }: { frame: number; running: boolean; w: number }) {
  const { now, since } = hoverAt(frame, w);
  // As in the app: on hover the controls come in one by one, fading in and settling from slightly
  // above, without scaling; when the pointer leaves they go out together, quickly.
  const item = (index: number): CSSProperties => {
    const p = now ? progress(since, index * 1.1, 10) : 1 - progress(since, 0, 4);
    return { opacity: p, transform: `translateY(${(1 - p) * -3}px)` };
  };
  const shade = now ? progress(since, 0, 8) : 1 - progress(since, 0, 5);
  // The play button, as AppKit draws a borderless icon button: a soft circle while the pointer is
  // over it, a darker one while pressed, and the symbol swapping play → stop like SF Symbols'
  // "replace" effect (the old one shrinks away, the new one springs in).
  const onPlay = (f: number) => {
    const [x, y] = track(f, pointerPath(w));
    return pointerVisible(f) && Math.abs(x - PLAY.x) <= 12 && y >= 4 && y <= 28;
  };
  let overSince = -1;
  for (let back = 0; back <= 12 && onPlay(frame - back); back++) overSince = back;
  let leftSince = -1;
  if (overSince < 0) for (let back = 1; back <= 12; back++) if (onPlay(frame - back)) { leftSince = back - 1; break; }
  const hover = overSince >= 0 ? progress(overSince, 0, 5) : leftSince >= 0 ? 1 - progress(leftSince, 0, 6) : 0;
  const down = pressedAt(frame, T.start);
  const playBackground = down ? 0.22 : 0.12 * hover;
  const swap = T.start + 2;
  const out = progress(frame, swap, 5, easeIn);
  const into = progress(frame, swap + 2, 9, easeOutBack);
  const stroke = { fill: "none", stroke: "rgba(250,250,250,0.7)", strokeWidth: 1.3 };
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 32, padding: "0 6px", display: "flex", alignItems: "center", gap: 2 }}>
      <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to bottom, rgba(13,13,13,0.92), rgba(13,13,13,0))", opacity: shade }} />
      <IconButton style={item(0)}>
        <g {...stroke}>
          <circle cx="8" cy="8" r="6.2" />
          <path d="M1.8 8h12.4M8 1.8c1.8 2 1.8 10.4 0 12.4M8 1.8c-1.8 2-1.8 10.4 0 12.4" />
        </g>
      </IconButton>
      <IconButton style={{ ...item(1), background: `rgba(250,250,250,${playBackground})` }}>
        <g style={{ transformOrigin: "8px 8px", opacity: down ? 0.75 : 1 }}>
          {frame < swap + 5 && (
            <path d="M5 3.5v9l7.5-4.5z" fill={ACCENT} style={{ transformOrigin: "8px 8px", transform: `scale(${1 - 0.45 * out})`, opacity: 1 - out }} />
          )}
          {running && frame >= swap + 2 && (
            <rect x="4" y="4" width="8" height="8" rx="1.5" fill={ACCENT} style={{ transformOrigin: "8px 8px", transform: `scale(${0.55 + 0.45 * into})`, opacity: Math.min(1, into * 1.4) }} />
          )}
        </g>
      </IconButton>
      <span style={{ flex: 1 }} />
      <IconButton style={item(2)}>
        <g {...stroke}>
          <rect x="5.5" y="5.5" width="7.5" height="8" rx="1.5" />
          <path d="M3 10.5V4a1.5 1.5 0 0 1 1.5-1.5H10" />
        </g>
      </IconButton>
      <IconButton style={item(3)}>
        <g {...stroke}>
          <circle cx="8" cy="8" r="2.2" />
          <path d="M8 1.8v2M8 12.2v2M1.8 8h2M12.2 8h2M3.6 3.6l1.4 1.4M11 11l1.4 1.4M3.6 12.4 5 11M11 5l1.4-1.4" strokeLinecap="round" />
        </g>
      </IconButton>
      <IconButton style={item(4)}>
        <path d="M4.5 4.5l7 7M11.5 4.5l-7 7" stroke="rgba(250,250,250,0.7)" strokeWidth="1.4" strokeLinecap="round" />
      </IconButton>
    </div>
  );
}

function IconButton({ children, style }: { children: ReactNode; style?: CSSProperties }) {
  return (
    <span style={{ position: "relative", width: 24, height: 24, borderRadius: 12, display: "grid", placeItems: "center", ...style }}>
      <svg viewBox="0 0 16 16" style={{ width: 13, height: 13 }}>
        {children}
      </svg>
    </span>
  );
}

// Back to the latest captions: just the arrow in the corner; after a pause the pill widens to the
// left and the label fades in beside the arrow.
function JumpButton({ frame, label }: { frame: number; label: string }) {
  if (frame < T.arrow) return null;
  const away = frame < T.jump;
  const shown = away ? progress(frame, T.arrow, 10) : 1 - progress(frame, T.jump, 8);
  if (shown <= 0) return null;
  const grow = away ? progress(frame, T.label, 16) : 1 - progress(frame, T.jump, 8);
  const text = away ? progress(frame, T.label + 6, 12) : 1 - progress(frame, T.jump, 5);
  return (
    <div
      style={{
        position: "absolute",
        right: 12,
        bottom: 12,
        height: 24,
        display: "flex",
        alignItems: "center",
        borderRadius: 12,
        background: ACCENT,
        color: "#0d0d0d",
        overflow: "hidden",
        opacity: shown,
        filter: pressedAt(frame, T.jump) ? "brightness(0.86)" : undefined,
        transform: `scale(${0.7 + 0.3 * shown})`,
        transformOrigin: "100% 100%",
        boxShadow: "0 6px 18px rgba(0,0,0,0.35)",
      }}
    >
      <span style={{ maxWidth: grow * 120, overflow: "hidden", display: "flex" }}>
        <span
          style={{
            whiteSpace: "nowrap",
            fontSize: 11,
            fontWeight: 500,
            paddingLeft: 10,
            opacity: text,
            transform: `translateX(${(1 - text) * 6}px)`,
          }}
        >
          {label}
        </span>
      </span>
      <svg viewBox="0 0 24 24" style={{ width: 24, height: 24, flexShrink: 0 }}>
        <path d="M12 7.5v9M8.5 13l3.5 3.5 3.5-3.5" fill="none" stroke="#0d0d0d" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </div>
  );
}

function Pointer({ x, y, opacity }: { x: number; y: number; opacity: number }) {
  return (
    <svg
      viewBox="0 0 20 26"
      style={{ position: "absolute", left: x - 2, top: y - 1, width: 17, height: 22, opacity }}
    >
      <path d="M2 1.5v19.2l5-4.8 3.1 7.2 3.3-1.4-3.1-7.1h7z" fill="#000" stroke="#fff" strokeWidth="1.4" strokeLinejoin="round" />
    </svg>
  );
}

// The macOS vertical resize pointer, while the bottom edge is dragged.
function ResizePointer({ x, y }: { x: number; y: number }) {
  return (
    <svg viewBox="0 0 16 24" style={{ position: "absolute", left: x - 6, top: y - 9, width: 12, height: 18 }}>
      <path d="M8 1.5 12.5 7H9.6v10h2.9L8 22.5 3.5 17h2.9V7H3.5z" fill="#000" stroke="#fff" strokeWidth="1.3" strokeLinejoin="round" />
    </svg>
  );
}
