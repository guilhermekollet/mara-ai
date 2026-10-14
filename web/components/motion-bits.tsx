"use client";

import { useEffect, useRef, useState } from "react";

// Reveals, on scroll, every element marked with data-reveal (the CSS lives in globals.css).
// Without JavaScript nothing stays hidden: the CSS only hides things once this component adds the class.
export function RevealObserver() {
  useEffect(() => {
    const elements = Array.from(document.querySelectorAll<HTMLElement>("[data-reveal]"));
    const show = (element: HTMLElement) => {
      element.classList.add("is-visible");
      // After the entrance, the element goes back to using only its own transitions (hover etc.).
      const delay = parseFloat(getComputedStyle(element).getPropertyValue("--d")) || 0;
      window.setTimeout(() => {
        element.removeAttribute("data-reveal");
        element.classList.remove("is-visible");
      }, 1100 + delay);
    };
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          show(entry.target as HTMLElement);
          observer.unobserve(entry.target);
        }
      },
      { rootMargin: "0px 0px -70px 0px" },
    );
    // Whatever is already on screen shows up right away, without flickering.
    for (const element of elements) {
      if (element.getBoundingClientRect().top < window.innerHeight) element.removeAttribute("data-reveal");
      else observer.observe(element);
    }
    document.documentElement.classList.add("reveal-ready");
    return () => observer.disconnect();
  }, []);
  return null;
}

// A number that counts up from zero to its value when it enters the screen.
export function CountUp({ value }: { value: number }) {
  const ref = useRef<HTMLSpanElement>(null);
  const [shown, setShown] = useState(value);

  useEffect(() => {
    const element = ref.current;
    if (!element || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    setShown(0);
    let frame = 0;
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return;
      observer.disconnect();
      const startedAt = performance.now();
      const tick = (now: number) => {
        const progress = Math.min(1, (now - startedAt) / 900);
        setShown(Math.round(value * (1 - Math.pow(1 - progress, 3))));
        if (progress < 1) frame = requestAnimationFrame(tick);
      };
      frame = requestAnimationFrame(tick);
    });
    observer.observe(element);
    return () => {
      observer.disconnect();
      cancelAnimationFrame(frame);
    };
  }, [value]);

  return <span ref={ref}>{shown}</span>;
}
