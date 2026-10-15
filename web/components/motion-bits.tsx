"use client";

import { useEffect } from "react";

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
