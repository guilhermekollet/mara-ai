"use client";

import { useEffect, useRef } from "react";
import { Mark } from "@/components/mark";

// The logo in the header and footer: the dotted "M" with the name beside it. On hover, a shimmer
// wave runs across the M's dots, just like
// the app's menu bar icon: it builds up on enter and, on leave, fades out until the dots are
// back to normal, without a hard cut. It links to the top of the page unless given another `href`.
export function Brand({ href = "#topo" }: { href?: string }) {
  const link = useRef<HTMLAnchorElement>(null);
  const active = useRef(false);
  const frame = useRef(0);

  useEffect(() => () => cancelAnimationFrame(frame.current), []);

  const run = () => {
    const svg = link.current?.querySelector("svg");
    if (!svg || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const width = svg.viewBox.baseVal.width;
    const dots = Array.from(svg.querySelectorAll("circle")).map((circle) => ({
      circle,
      // The dot's position in the wave: left to right, slightly top to bottom.
      position: (circle.cx.baseVal.value + circle.cy.baseVal.value * 0.35) / width,
    }));
    let depth = 0;
    let previous = performance.now();
    const startedAt = previous;

    const step = (now: number) => {
      const elapsed = (now - previous) / 1000;
      previous = now;
      // Fades in over about 0.4 s and out over just under 1 s.
      depth = active.current ? Math.min(1, depth + elapsed / 0.4) : Math.max(0, depth - elapsed / 0.9);
      const phase = ((now - startedAt) / 1300) % 1;
      for (const { circle, position } of dots) {
        const wave = Math.pow(Math.max(0, Math.cos((phase - position * 0.9) * 2 * Math.PI)), 2);
        const dim = 0.32 + 0.68 * wave;
        circle.style.opacity = String(1 - (1 - dim) * depth);
      }
      if (depth > 0 || active.current) {
        frame.current = requestAnimationFrame(step);
      } else {
        for (const { circle } of dots) circle.style.opacity = "";
        frame.current = 0;
      }
    };
    frame.current = requestAnimationFrame(step);
  };

  return (
    <a
      ref={link}
      href={href}
      aria-label="Mara AI"
      className="inline-flex items-center gap-2 py-2"
      onMouseEnter={() => {
        active.current = true;
        if (!frame.current) run();
      }}
      onMouseLeave={() => {
        active.current = false;
      }}
    >
      <Mark className="size-[22px] text-fg" />
      <span className="text-[17px] font-semibold tracking-tight text-fg">Mara</span>
    </a>
  );
}
