"use client";

import { useEffect, useRef } from "react";

// Hero background: a few thin, nearly transparent wavy lines drifting slowly from left to
// right. One of them is lavender. Stays still for people who ask for reduced motion, pauses
// when off screen and follows light/dark theme changes.
export function HeroWaves() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let ink = "#0d0d0d";
    let accent = "#b8a4f8";
    const readColors = () => {
      const styles = getComputedStyle(document.documentElement);
      ink = styles.getPropertyValue("--fg").trim() || ink;
      accent = styles.getPropertyValue("--color-accent").trim() || accent;
    };
    readColors();

    let width = 0;
    let height = 0;
    const resize = () => {
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      width = canvas.clientWidth;
      height = canvas.clientHeight;
      canvas.width = Math.round(width * ratio);
      canvas.height = Math.round(height * ratio);
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
    };
    resize();

    // Each line: relative height, amplitude, wavelength, speed and whether it's the accent one.
    const lines = [
      { y: 0.34, amplitude: 22, length: 1.15, speed: 0.05, accent: false },
      { y: 0.42, amplitude: 30, length: 0.9, speed: -0.035, accent: false },
      { y: 0.66, amplitude: 26, length: 1.35, speed: 0.042, accent: true },
      { y: 0.58, amplitude: 34, length: 1.05, speed: -0.028, accent: false },
      { y: 0.5, amplitude: 20, length: 1.6, speed: 0.032, accent: false },
    ];

    const draw = (time: number) => {
      context.clearRect(0, 0, width, height);
      const seconds = time / 1000;
      for (const line of lines) {
        context.beginPath();
        for (let x = 0; x <= width; x += 6) {
          const progress = x / width;
          // Summing two sine waves makes the wave look organic rather than a repeating pattern.
          const y =
            line.y * height +
            Math.sin(progress * Math.PI * 2 * line.length + seconds * line.speed * 6) * line.amplitude +
            Math.sin(progress * Math.PI * 5 * line.length - seconds * line.speed * 4) * line.amplitude * 0.25;
          if (x === 0) context.moveTo(x, y);
          else context.lineTo(x, y);
        }
        context.strokeStyle = line.accent ? accent : ink;
        context.globalAlpha = line.accent ? 0.55 : 0.09;
        context.lineWidth = line.accent ? 1.4 : 1;
        context.stroke();
      }
      context.globalAlpha = 1;
    };

    let frame = 0;
    let visible = true;
    const loop = (time: number) => {
      draw(time);
      frame = visible && !reduced ? requestAnimationFrame(loop) : 0;
    };
    const start = () => {
      if (!frame) frame = requestAnimationFrame(loop);
    };

    const observer = new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting && document.visibilityState === "visible";
      if (visible) start();
    });
    observer.observe(canvas);
    const onVisibility = () => {
      visible = document.visibilityState === "visible";
      if (visible) start();
    };
    document.addEventListener("visibilitychange", onVisibility);
    const themeWatcher = new MutationObserver(() => {
      readColors();
      if (reduced) draw(0);
    });
    themeWatcher.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
    const onResize = () => {
      resize();
      if (reduced) draw(0);
    };
    window.addEventListener("resize", onResize);

    if (reduced) draw(0);
    else start();

    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
      themeWatcher.disconnect();
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("resize", onResize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className="pointer-events-none absolute inset-x-0 top-0 h-[560px] w-full mask-[linear-gradient(to_bottom,transparent_0%,#000_18%,#000_62%,transparent_100%)]"
    />
  );
}
