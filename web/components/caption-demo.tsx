"use client";

import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";

type Phrase = { speaker: number; source: string; target: string };

const PHRASES: Phrase[] = [
  {
    speaker: 0,
    source: "And I think the delivery timeline is realistic for our team.",
    target: "E acho que o prazo de entrega é realista para o nosso time.",
  },
  {
    speaker: 1,
    source: "Could you walk us through the pricing for the enterprise plan?",
    target: "Você pode nos explicar os preços do plano empresarial?",
  },
  {
    speaker: 3,
    source: "Let's schedule a follow-up for next Tuesday morning.",
    target: "Vamos marcar uma continuação para terça-feira de manhã.",
  },
  {
    speaker: 0,
    source: "We need to close the quarter with twenty percent growth.",
    target: "Precisamos fechar o trimestre com vinte por cento de crescimento.",
  },
];

const SPEAKERS = [
  { initials: "SK", name: "Sarah Kim", tone: "bg-[#3a3550]" },
  { initials: "JM", name: "James Miller", tone: "bg-[#2d3a3a]" },
  { initials: "VOCÊ", name: "Você", tone: "bg-[#3a302d]" },
  { initials: "AL", name: "Anna Lindqvist", tone: "bg-[#2d3340]" },
];

type Line = { id: number; phrase: number; shown: number; done: boolean };

const wordsOf = (text: string) => text.split(" ");
const EASE = [0.22, 1, 0.36, 1] as const;
const WORD_SHOWN = { opacity: 1, y: 0, filter: "blur(0px)" };
const WORD_HIDDEN = { opacity: 0, y: 4, filter: "blur(5px)" };

// Initial state, and also what's shown to people who asked for reduced motion.
const RESTING: Line[] = [
  { id: -2, phrase: 3, shown: wordsOf(PHRASES[3].target).length, done: true },
  { id: -1, phrase: 0, shown: wordsOf(PHRASES[0].target).length, done: false },
];

export function CaptionDemo() {
  const reduced = useReducedMotion();
  const nextId = useRef(1);
  const [lines, setLines] = useState<Line[]>(RESTING.slice(0, 1));
  const [speaker, setSpeaker] = useState(-1);
  const [source, setSource] = useState({ phrase: 0, shown: 0 });

  useEffect(() => {
    if (reduced) {
      setLines(RESTING);
      setSource({ phrase: 0, shown: wordsOf(PHRASES[0].source).length });
      return;
    }

    let cancelled = false;
    const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
    const update = (id: number, patch: Partial<Line>) =>
      setLines((current) => current.map((line) => (line.id === id ? { ...line, ...patch } : line)));

    (async () => {
      await wait(600);
      for (let index = 0; !cancelled; index = (index + 1) % PHRASES.length) {
        const phrase = PHRASES[index];
        const spokenWords = wordsOf(phrase.source);
        const total = wordsOf(phrase.target).length;
        const id = nextId.current++;

        setSpeaker(phrase.speaker);
        setSource({ phrase: index, shown: 0 });
        setLines((current) => [
          ...current.filter((line) => line.done).slice(-1),
          { id, phrase: index, shown: 0, done: false },
        ]);

        // The translation trails the speech by two words, like in the app, and always comes in
        // one word at a time, at even intervals, so it never appears as a block.
        let shown = 0;
        const reveal = async (goal: number, within: number) => {
          const steps = goal - shown;
          if (steps <= 0) return wait(within);
          for (; shown < goal; ) {
            update(id, { shown: ++shown });
            await wait(within / steps);
            if (cancelled) return;
          }
        };

        for (let spoken = 1; spoken <= spokenWords.length; spoken++) {
          setSource({ phrase: index, shown: spoken });
          // Speech rhythm: long words take longer and punctuation gets a pause.
          const word = spokenWords[spoken - 1];
          const duration = 150 + word.length * 32 + (/[,.?]$/.test(word) ? 220 : 0);
          await reveal(Math.floor((Math.max(spoken - 2, 0) / spokenWords.length) * total), duration);
          if (cancelled) return;
        }

        await reveal(total, (total - shown) * 110);
        if (cancelled) return;
        await wait(750);
        if (cancelled) return;
        setSpeaker(-1);
        setSource({ phrase: index, shown: 0 });
        update(id, { done: true });
        await wait(1000);
        if (cancelled) return;
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [reduced]);

  const sourceWords = wordsOf(PHRASES[source.phrase].source);

  return (
    <div className="relative mx-auto mt-16 max-w-[1440px] rounded-3xl bg-linear-160 from-stage-from to-stage-to px-3 pt-6 pb-52 sm:rounded-[32px] sm:px-6 sm:pt-14 sm:pb-24">
      <div aria-hidden="true" className="mx-auto max-w-[820px] overflow-hidden rounded-2xl bg-[#1c1c1e] text-left shadow-[0_30px_60px_rgba(40,20,100,0.25)]">
        <div className="flex items-center gap-[7px] px-3.5 py-3 text-xs text-white/55">
          <i className="size-[11px] rounded-full bg-white/20" />
          <i className="size-[11px] rounded-full bg-white/20" />
          <i className="size-[11px] rounded-full bg-white/20" />
          <span className="ml-2.5">Quarterly review — Acme Corp</span>
        </div>
        <div className="grid grid-cols-2 gap-2 px-2 pb-2">
          {SPEAKERS.map((person, index) => {
            const speaking = index === speaker;
            return (
              <div
                key={person.name}
                className={`relative grid aspect-video place-items-center rounded-[10px] text-white/85 outline-2 -outline-offset-2 transition-[outline-color] duration-500 ${person.tone} ${speaking ? "outline-accent" : "outline-transparent"}`}
              >
                <b className="text-[15px] font-medium tracking-wider sm:text-[22px]">{person.initials}</b>
                <small className="absolute bottom-2 left-2.5 text-[11px] opacity-70">{person.name}</small>
                <span
                  className={`absolute right-2.5 bottom-2 flex h-3.5 items-center gap-[3px] transition-opacity duration-500 ${speaking ? "opacity-100" : "opacity-0"}`}
                >
                  {[0, 0.25, 0.1, 0.35].map((delay) => (
                    <i key={delay} className="voice-bar h-full w-[3px] rounded-full bg-accent" style={{ animationDelay: `${delay}s` }} />
                  ))}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      <div
        role="img"
        aria-label="Janela da Mara AI mostrando legendas traduzidas para português"
        className="absolute bottom-5 left-1/2 flex h-[196px] w-[calc(100%-24px)] max-w-[720px] -translate-x-1/2 flex-col justify-end overflow-hidden rounded-2xl bg-ink/90 px-4 py-4 text-center shadow-[0_20px_50px_rgba(0,0,0,0.35)] backdrop-blur-md sm:bottom-10 sm:h-[156px] sm:w-[calc(100%-48px)] sm:px-6"
      >
        <AnimatePresence initial={false} mode="popLayout">
          {lines.map((line) => {
            const words = wordsOf(PHRASES[line.phrase].target);
            return (
              <motion.p
                key={line.id}
                layout="position"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0, color: line.done ? "#fafafa" : "#b8a4f8" }}
                exit={{ opacity: 0, y: -14, filter: "blur(3px)" }}
                transition={{
                  layout: { type: "spring", stiffness: 170, damping: 28 },
                  color: { duration: 0.9, ease: "easeInOut" },
                  default: { duration: 0.6, ease: EASE },
                }}
                className="mt-1.5 text-[clamp(16px,2.2vw,22px)] leading-[1.3] font-medium"
              >
                {/* Every word already holds its place; only the opacity changes, so the line doesn't
                    re-center with each new word. */}
                {words.map((word, index) => (
                  <motion.span
                    key={index}
                    initial={false}
                    animate={index < line.shown ? WORD_SHOWN : WORD_HIDDEN}
                    transition={{ duration: 0.7, ease: EASE }}
                    className="inline-block whitespace-pre"
                  >
                    {index < words.length - 1 ? `${word} ` : word}
                  </motion.span>
                ))}
              </motion.p>
            );
          })}
        </AnimatePresence>
        <p className="mt-2 h-10 shrink-0 text-[13px] leading-5 sm:h-5 text-paper/45 italic">
          {sourceWords.map((word, index) => (
            <motion.span
              key={`${source.phrase}-${index}`}
              initial={false}
              animate={{ opacity: index < source.shown ? 1 : 0 }}
              transition={{ duration: 0.5, ease: "easeOut" }}
              className="inline-block whitespace-pre"
            >
              {`${word} `}
            </motion.span>
          ))}
        </p>
      </div>
    </div>
  );
}
