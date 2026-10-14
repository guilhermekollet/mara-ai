// Every piece of copy on the site, in each language it is published in. The page picks the
// dictionary from the URL (/en, /pt, /es); the root URL sends visitors to the one that matches
// their browser, falling back to English.
//
// The caption demos (`demo`) are captioned in the page's language: English speech becomes
// Portuguese captions on /pt, Spanish speech becomes English on /en, and English speech becomes
// Spanish on /es. The app itself captions in Brazilian Portuguese for now, which the FAQ answer
// about languages states in every language; keep it in step with CaptionModel.swift.

export const locales = ["en", "pt", "es"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "en";

export const hasLocale = (value: string): value is Locale => (locales as readonly string[]).includes(value);

// Values for the <html lang> attribute and the language switcher.
export const localeInfo: Record<Locale, { htmlLang: string; short: string; name: string }> = {
  en: { htmlLang: "en", short: "EN", name: "English" },
  pt: { htmlLang: "pt-BR", short: "PT", name: "Português" },
  es: { htmlLang: "es", short: "ES", name: "Español" },
};

const en = {
  meta: {
    title: "Mara AI — Meetings in any language",
    description:
      "Mara AI captions and translates your meetings in real time, right on your Mac, and summarizes them with AI using your own OpenAI key.",
  },
  a11y: {
    sections: "Sections",
    footer: "Footer",
    menu: "Language and appearance",
  },
  nav: {
    howItWorks: "How it works",
    modules: "Modules",
    summary: "Summary",
    privacy: "Privacy",
    faq: "FAQ",
  },
  download: "Download for macOS",
  menu: { language: "Language", appearance: "Appearance", light: "Light", dark: "Dark" },
  hero: {
    eyebrow: "Mara AI for macOS",
    title: "Meetings, without barriers.",
    text: "Real-time translated captions, right on your Mac. Understand every word while it is still being spoken.",
    seeHow: "See how it works",
  },
  demo: {
    label: "Mara's captions window: a meeting in Spanish, captioned in English word by word",
    // The jump-to-latest button's label in the captions window.
    jump: "New captions",
    // What the hero demo hears and captions, in order.
    phrases: [
      { source: "Creo que el plazo de entrega es realista para nuestro equipo.", target: "I think the delivery timeline is realistic for our team." },
      { source: "¿Puedes enviar la propuesta revisada antes del jueves?", target: "Can you send the revised proposal by Thursday?" },
      { source: "Agendemos una reunión de seguimiento el próximo martes.", target: "Let's schedule a follow-up meeting next Tuesday." },
      { source: "Perfecto, yo preparo la demo para el cliente.", target: "Perfect, I'll prepare the demo for the client." },
      { source: "Y revisamos los números del trimestre al final.", target: "And we'll go over the quarter's numbers at the end." },
      { source: "Lucía, ¿puedes compartir la presentación en el chat?", target: "Lucía, can you share the slides in the chat?" },
      { source: "Claro, la comparto ahora mismo.", target: "Sure, I'll share it right now." },
    ],
    // The still caption in the "incremental translation" band: a confirmed line, a line still
    // forming word by word, and the speech it comes from.
    band: {
      final: "We can review the contract on Thursday.",
      draft: "And I think the delivery timeline",
      source: "E eu acho que o prazo de entrega…",
    },
  },
  steps: {
    title: "How it works",
    text: "Three steps, all happening while the other person speaks.",
    step: "Step",
    items: [
      {
        title: "Listens to your Mac's audio",
        text: "Captures sound from any app: Zoom, Meet, Teams or a video in the browser. No bot joining the call.",
      },
      {
        title: "Transcribes on your Mac",
        text: "Apple's speech recognition runs locally. The meeting audio is never sent to any server.",
      },
      {
        title: "Translates as people speak",
        text: "The translated caption takes shape in real time and is refined at the end of each sentence.",
      },
    ],
  },
  modules: {
    title: "Built for developers",
    text: "From the English stand-up with the team abroad to the summary when the call ends: Mara follows the meeting from start to finish.",
    available: "Available",
    items: [
      {
        title: "Meetings in other languages",
        text: "Live captions in a discreet window over the call, forming word by word as people talk.",
        points: ["Instant translation on your Mac", "Optional GPT refinement", "Free and offline in Mac-only mode"],
      },
      {
        title: "AI summaries",
        text: "When the call ends, GPT reads the transcript and sums up what was talked about, with your own OpenAI key.",
        points: ["Tells a conversation from a talk", "Overview and the topics discussed", "Saved as a file on your Mac"],
      },
    ],
  },
  band: {
    eyebrow: "Incremental translation",
    title: "The caption doesn't wait for the sentence to end.",
    text: "Most tools only translate once the person stops talking. Mara shows the translation taking shape, word by word, and swaps in the final version when the sentence ends.",
    draft: "Draft",
    draftText: "Shown in lavender while the speech is happening.",
    final: "Final",
    finalText: "Turns white, already reviewed with the context of the conversation.",
  },
  summary: {
    eyebrow: "AI summary",
    title: "The meeting ends, the summary is ready.",
    text: "With your own OpenAI key, Mara reads the transcript and tells you what was talked about: the topics, what each side brought up and what was decided.",
    points: [
      { title: "Knows what kind of talk it was", text: "A meeting between several people or someone speaking alone, like a class or a talk: the summary adapts to what happened." },
      { title: "What was talked about", text: "A short overview and the topics that came up, each with what was said and decided." },
      { title: "Yours, on your Mac", text: "The summary is saved as a file in Documents and copied in one click. The transcript only goes to OpenAI when you ask." },
    ],
    // The summary card illustrated next to the copy: what was talked about, not a task list.
    mock: {
      heading: "Summary",
      kind: "Conversation between several people",
      overviewTitle: "Overview",
      overview: "The team went over the delivery timeline and the client presentation, and agreed the current deadline is realistic.",
      topicsTitle: "Topics",
      topics: [
        { title: "Delivery timeline", text: "Seen as realistic; the team keeps the current date." },
        { title: "Revised proposal", text: "Goes out by Thursday, before the client demo." },
        { title: "Quarter's numbers", text: "Left for the end of the meeting." },
      ],
      decisionsTitle: "Decisions",
      decisions: ["Keep the current deadline."],
      copy: "Copy",
      open: "Open file",
    },
  },
  privacy: {
    title: "Your audio stays on your Mac.",
    text: "Mara was designed to work locally. The cloud is optional, and you see exactly how much you use.",
    items: [
      { title: "Local transcription", text: "Done by Apple's speech recognition, on the device." },
      { title: "Local translation", text: "Apple's translator produces the caption without using the internet." },
      { title: "Optional GPT", text: "When on, only the transcribed text is sent. When off, nothing leaves your Mac." },
      { title: "Key in the Keychain", text: "Your OpenAI key lives in the macOS vault, never in a file." },
      { title: "Your files", text: "Transcripts and summaries are saved as files on your Mac." },
      { title: "Measured usage", text: "Tokens and estimated cost of every call, per session, day and month." },
    ],
  },
  faq: {
    title: "Frequently asked questions",
    items: [
      {
        question: "Do the other participants know I'm using Mara?",
        answer:
          "Mara doesn't join the call: it listens to the audio already coming out of your Mac. Letting participants know and following your company's rules on meeting transcription is up to the person using it.",
      },
      {
        question: "Do I need an OpenAI key?",
        answer:
          "No. Apple's local translation works without a key and at no cost. The key is only needed for the AI summary and, if you want it, GPT refinement of each sentence.",
      },
      {
        question: "Which languages are supported?",
        answer:
          "Meetings can be in English or Spanish, and for now the captions are shown in Brazilian Portuguese. Meetings in Portuguese work too: Mara transcribes and summarizes them, without translating. You pick the meeting language before you start.",
      },
      {
        question: "How does the summary work?",
        answer:
          "When the meeting ends you ask for the summary. The transcript goes to OpenAI with your key, and GPT works out whether it was a conversation between several people or a talk, then tells you what was said: an overview, the topics and the decisions. Nothing is sent unless you ask.",
      },
      {
        question: "Is Mara open source?",
        answer:
          "Yes, under the MIT license. The app is written in Swift and SwiftUI, with no server of its own: calls go straight from your Mac to OpenAI, with your own key. Contributions are welcome.",
      },
      {
        question: "Which computers does it run on?",
        answer:
          "Macs running macOS 26 or later. The first time, macOS asks for permission to record system audio.",
      },
      {
        question: "How much does GPT cost?",
        answer:
          "OpenAI bills your own key, and it usually comes to a few cents of a dollar per hour of meetings. Mara shows usage in real time in the settings.",
      },
    ],
  },
  contribute: {
    badges: ["Native Swift", "Made for macOS", "Open source, MIT", "Pull requests on GitHub"],
    title: "Contribute",
    text: "Mara is open source, under the MIT license. Read it, audit it, adapt it to your workflow, open an issue or send a pull request.",
    github: "View on GitHub",
  },
  final: {
    title: "Start today.",
    text: "Open Mara, pick the language and join the meeting.",
  },
  footer: "© 2026 Mara AI. Made for macOS.",
  notFound: {
    eyebrow: "Error 404",
    title: "Page not found.",
    text: "The page you are looking for doesn't exist or has moved.",
    home: "Back to home",
  },
};

export type Dictionary = typeof en;

const pt: Dictionary = {
  meta: {
    title: "Mara AI — Reuniões em qualquer idioma",
    description:
      "Mara AI legenda e traduz suas reuniões em tempo real, direto no Mac, e resume a conversa com IA usando a sua chave da OpenAI.",
  },
  a11y: {
    sections: "Seções",
    footer: "Rodapé",
    menu: "Idioma e aparência",
  },
  nav: {
    howItWorks: "Como funciona",
    modules: "Módulos",
    summary: "Resumo",
    privacy: "Privacidade",
    faq: "Perguntas",
  },
  download: "Baixar para macOS",
  menu: { language: "Idioma", appearance: "Aparência", light: "Claro", dark: "Escuro" },
  hero: {
    eyebrow: "Mara AI para macOS",
    title: "Reuniões, sem barreira.",
    text: "Legendas traduzidas em tempo real, direto no seu Mac. Entenda cada palavra enquanto ela ainda está sendo dita.",
    seeHow: "Ver como funciona",
  },
  demo: {
    label: "Janela de legendas da Mara: uma reunião em inglês legendada em português, palavra a palavra",
    // The jump-to-latest button's label in the captions window.
    jump: "Falas novas",
    // What the hero demo hears and captions, in order.
    phrases: [
      { source: "I think the delivery timeline is realistic for our team.", target: "Acho que o prazo de entrega é realista para o nosso time." },
      { source: "Can you send the revised proposal by Thursday?", target: "Você pode enviar a proposta revisada até quinta-feira?" },
      { source: "Let's schedule a follow-up meeting next Tuesday.", target: "Vamos marcar uma reunião de acompanhamento na próxima terça." },
      { source: "Perfect, I'll prepare the demo for the client.", target: "Perfeito, eu preparo a demo para o cliente." },
      { source: "And we'll go over the quarter's numbers at the end.", target: "E no final revisamos os números do trimestre." },
      { source: "Lucía, can you share the slides in the chat?", target: "Lucía, você pode compartilhar os slides no chat?" },
      { source: "Sure, I'll share it right now.", target: "Claro, vou compartilhar agora mesmo." },
    ],
    band: {
      final: "Podemos revisar o contrato na quinta-feira.",
      draft: "E eu acho que o prazo de entrega",
      source: "And I think the delivery timeline…",
    },
  },
  steps: {
    title: "Como funciona",
    text: "Três etapas, todas acontecendo enquanto a pessoa fala.",
    step: "Etapa",
    items: [
      {
        title: "Escuta o áudio do Mac",
        text: "Captura o som de qualquer aplicativo: Zoom, Meet, Teams ou um vídeo no navegador. Sem bot entrando na chamada.",
      },
      {
        title: "Transcreve no próprio Mac",
        text: "O reconhecimento de fala da Apple roda localmente. O áudio da reunião não é enviado para nenhum servidor.",
      },
      {
        title: "Traduz enquanto falam",
        text: "A legenda em português vai se formando em tempo real e é refinada ao fim de cada frase.",
      },
    ],
  },
  modules: {
    title: "Feito para quem desenvolve",
    text: "Da daily em inglês com o time de fora ao resumo pronto quando a chamada termina: a Mara acompanha a reunião do começo ao fim.",
    available: "Disponível",
    items: [
      {
        title: "Reuniões em outros idiomas",
        text: "Legendas ao vivo numa janela discreta sobre a chamada, formadas palavra a palavra enquanto as pessoas falam.",
        points: ["Tradução instantânea no Mac", "Refinamento opcional por GPT", "Grátis e offline no modo Só no Mac"],
      },
      {
        title: "Resumo com IA",
        text: "Quando a chamada termina, o GPT lê a transcrição e resume o que foi conversado, com a sua chave da OpenAI.",
        points: ["Entende se foi conversa ou apresentação", "Visão geral e assuntos discutidos", "Salvo como arquivo no seu Mac"],
      },
    ],
  },
  band: {
    eyebrow: "Tradução incremental",
    title: "A legenda não espera a frase acabar.",
    text: "A maioria das ferramentas só traduz depois que a pessoa para de falar. A Mara mostra a tradução se formando, palavra a palavra, e troca pela versão final quando a frase termina.",
    draft: "Provisória",
    draftText: "Aparece em lavanda, enquanto a fala acontece.",
    final: "Confirmada",
    finalText: "Fica em branco, já revisada com o contexto da conversa.",
  },
  summary: {
    eyebrow: "Resumo com IA",
    title: "A reunião acaba, o resumo já está pronto.",
    text: "Com a sua chave da OpenAI, a Mara lê a transcrição e conta o que foi conversado: os assuntos, o que cada lado trouxe e o que ficou decidido.",
    points: [
      { title: "Entende o tipo de conversa", text: "Reunião entre várias pessoas ou alguém falando sozinho, como uma aula ou palestra: o resumo se adapta ao que aconteceu." },
      { title: "O que foi conversado", text: "Uma visão geral em poucas linhas e os assuntos que surgiram, cada um com o que foi dito e decidido." },
      { title: "Seu, no seu Mac", text: "O resumo fica salvo como arquivo em Documentos e é copiado com um clique. A transcrição só vai para a OpenAI quando você pede." },
    ],
    // The summary card illustrated next to the copy: what was talked about, not a task list.
    mock: {
      heading: "Resumo",
      kind: "Conversa entre várias pessoas",
      overviewTitle: "Visão geral",
      overview: "O time revisou o prazo da entrega e a apresentação para o cliente, e concordou que o prazo atual é realista.",
      topicsTitle: "Assuntos",
      topics: [
        { title: "Prazo de entrega", text: "Considerado realista; o time mantém a data atual." },
        { title: "Proposta revisada", text: "Vai até quinta-feira, antes da demo para o cliente." },
        { title: "Números do trimestre", text: "Ficaram para o fim da reunião." },
      ],
      decisionsTitle: "Decisões",
      decisions: ["Manter o prazo atual."],
      copy: "Copiar",
      open: "Abrir arquivo",
    },
  },
  privacy: {
    title: "Seu áudio fica no seu Mac.",
    text: "A Mara foi desenhada para funcionar localmente. A nuvem é opcional, e você vê exatamente quanto usa.",
    items: [
      { title: "Transcrição local", text: "Feita pelo reconhecimento de fala da Apple, no aparelho." },
      { title: "Tradução local", text: "O tradutor da Apple gera a legenda sem usar a internet." },
      { title: "GPT opcional", text: "Ligado, só o texto transcrito é enviado. Desligado, nada sai do Mac." },
      { title: "Chave no Keychain", text: "Sua chave da OpenAI fica no cofre do macOS, nunca em arquivo." },
      { title: "Arquivos seus", text: "Transcrições e resumos ficam salvos como arquivos no seu Mac." },
      { title: "Consumo medido", text: "Tokens e custo estimado de cada chamada, por sessão, dia e mês." },
    ],
  },
  faq: {
    title: "Perguntas frequentes",
    items: [
      {
        question: "Os outros participantes sabem que estou usando a Mara?",
        answer:
          "A Mara não entra na chamada: ela escuta o áudio que já está saindo do seu Mac. Avisar os participantes e seguir as regras da sua empresa sobre transcrição de reuniões é responsabilidade de quem usa.",
      },
      {
        question: "Preciso de uma chave da OpenAI?",
        answer:
          "Não. A tradução local da Apple funciona sem chave e sem custo. A chave só é necessária para o resumo com IA e, se você quiser, para o refinamento de cada frase pelo GPT.",
      },
      {
        question: "Quais idiomas são suportados?",
        answer:
          "Reuniões em inglês ou espanhol, com a legenda em português. Reuniões em português também funcionam: a Mara transcreve e resume, sem traduzir. Você escolhe o idioma da reunião antes de iniciar.",
      },
      {
        question: "Como funciona o resumo?",
        answer:
          "Quando a reunião termina, você pede o resumo. A transcrição vai para a OpenAI com a sua chave, e o GPT identifica se foi uma conversa entre várias pessoas ou uma apresentação e conta o que foi falado: visão geral, assuntos e decisões. Nada é enviado sem você pedir.",
      },
      {
        question: "A Mara é de código aberto?",
        answer:
          "Sim, sob licença MIT. O app é escrito em Swift e SwiftUI, sem servidor próprio: as chamadas vão direto do seu Mac para a OpenAI, com a sua chave. Contribuições são bem-vindas.",
      },
      {
        question: "Em quais computadores funciona?",
        answer:
          "Em Macs com macOS 26 ou mais recente. Na primeira vez, o macOS pede a permissão de gravação do áudio do sistema.",
      },
      {
        question: "Quanto custa usar o GPT?",
        answer:
          "O custo é cobrado pela OpenAI na sua própria chave e costuma ficar em centavos de dólar por hora de reunião. A Mara mostra o consumo em tempo real nos ajustes.",
      },
    ],
  },
  contribute: {
    badges: ["Swift nativo", "Feito para macOS", "Código aberto, MIT", "Pull requests no GitHub"],
    title: "Contribua",
    text: "A Mara é código aberto, sob licença MIT. Leia, audite, adapte ao seu fluxo, abra uma issue ou mande um pull request.",
    github: "Ver no GitHub",
  },
  final: {
    title: "Comece hoje.",
    text: "Abra a Mara, escolha o idioma e entre na reunião.",
  },
  footer: "© 2026 Mara AI. Feito para macOS.",
  notFound: {
    eyebrow: "Erro 404",
    title: "Página não encontrada.",
    text: "A página que você procura não existe ou mudou de endereço.",
    home: "Voltar ao início",
  },
};

const es: Dictionary = {
  meta: {
    title: "Mara AI — Reuniones en cualquier idioma",
    description:
      "Mara AI subtitula y traduce tus reuniones en tiempo real, directamente en tu Mac, y las resume con IA usando tu propia clave de OpenAI.",
  },
  a11y: {
    sections: "Secciones",
    footer: "Pie de página",
    menu: "Idioma y apariencia",
  },
  nav: {
    howItWorks: "Cómo funciona",
    modules: "Módulos",
    summary: "Resumen",
    privacy: "Privacidad",
    faq: "Preguntas",
  },
  download: "Descargar para macOS",
  menu: { language: "Idioma", appearance: "Apariencia", light: "Claro", dark: "Oscuro" },
  hero: {
    eyebrow: "Mara AI para macOS",
    title: "Reuniones, sin barreras.",
    text: "Subtítulos traducidos en tiempo real, directamente en tu Mac. Entiende cada palabra mientras todavía se está diciendo.",
    seeHow: "Ver cómo funciona",
  },
  demo: {
    label: "Ventana de subtítulos de Mara: una reunión en inglés subtitulada en español, palabra por palabra",
    // The jump-to-latest button's label in the captions window.
    jump: "Nuevas frases",
    // What the hero demo hears and captions, in order.
    phrases: [
      { source: "I think the delivery timeline is realistic for our team.", target: "Creo que el plazo de entrega es realista para nuestro equipo." },
      { source: "Can you send the revised proposal by Thursday?", target: "¿Puedes enviar la propuesta revisada antes del jueves?" },
      { source: "Let's schedule a follow-up meeting next Tuesday.", target: "Agendemos una reunión de seguimiento el próximo martes." },
      { source: "Perfect, I'll prepare the demo for the client.", target: "Perfecto, yo preparo la demo para el cliente." },
      { source: "And we'll go over the quarter's numbers at the end.", target: "Y al final revisamos los números del trimestre." },
      { source: "Lucía, can you share the slides in the chat?", target: "Lucía, ¿puedes compartir las diapositivas en el chat?" },
      { source: "Sure, I'll share it right now.", target: "Claro, las comparto ahora mismo." },
    ],
    band: {
      final: "Podemos revisar el contrato el jueves.",
      draft: "Y creo que el plazo de entrega",
      source: "And I think the delivery timeline…",
    },
  },
  steps: {
    title: "Cómo funciona",
    text: "Tres pasos, todos ocurriendo mientras la otra persona habla.",
    step: "Paso",
    items: [
      {
        title: "Escucha el audio del Mac",
        text: "Captura el sonido de cualquier aplicación: Zoom, Meet, Teams o un video en el navegador. Sin bots entrando en la llamada.",
      },
      {
        title: "Transcribe en tu propio Mac",
        text: "El reconocimiento de voz de Apple funciona localmente. El audio de la reunión no se envía a ningún servidor.",
      },
      {
        title: "Traduce mientras hablan",
        text: "El subtítulo traducido se va formando en tiempo real y se refina al final de cada frase.",
      },
    ],
  },
  modules: {
    title: "Hecho para quienes desarrollan",
    text: "De la daily en inglés con el equipo de fuera al resumen listo cuando termina la llamada: Mara acompaña la reunión de principio a fin.",
    available: "Disponible",
    items: [
      {
        title: "Reuniones en otros idiomas",
        text: "Subtítulos en vivo en una ventana discreta sobre la llamada, formados palabra por palabra mientras las personas hablan.",
        points: ["Traducción instantánea en el Mac", "Refinamiento opcional con GPT", "Gratis y sin conexión en el modo Solo en el Mac"],
      },
      {
        title: "Resumen con IA",
        text: "Cuando termina la llamada, GPT lee la transcripción y resume de qué se habló, con tu propia clave de OpenAI.",
        points: ["Distingue una conversación de una charla", "Visión general y temas tratados", "Guardado como archivo en tu Mac"],
      },
    ],
  },
  band: {
    eyebrow: "Traducción incremental",
    title: "El subtítulo no espera a que termine la frase.",
    text: "La mayoría de las herramientas solo traduce cuando la persona deja de hablar. Mara muestra la traducción formándose, palabra por palabra, y la reemplaza por la versión final cuando termina la frase.",
    draft: "Provisional",
    draftText: "Aparece en lavanda mientras se habla.",
    final: "Confirmada",
    finalText: "Se vuelve blanca, ya revisada con el contexto de la conversación.",
  },
  summary: {
    eyebrow: "Resumen con IA",
    title: "La reunión termina y el resumen ya está listo.",
    text: "Con tu propia clave de OpenAI, Mara lee la transcripción y cuenta de qué se habló: los temas, lo que aportó cada parte y lo que se decidió.",
    points: [
      { title: "Entiende el tipo de conversación", text: "Una reunión entre varias personas o alguien hablando solo, como una clase o una charla: el resumen se adapta a lo que pasó." },
      { title: "Lo que se conversó", text: "Una visión general en pocas líneas y los temas que surgieron, cada uno con lo que se dijo y se decidió." },
      { title: "Tuyo, en tu Mac", text: "El resumen se guarda como archivo en Documentos y se copia con un clic. La transcripción solo va a OpenAI cuando lo pides." },
    ],
    // The summary card illustrated next to the copy: what was talked about, not a task list.
    mock: {
      heading: "Resumen",
      kind: "Conversación entre varias personas",
      overviewTitle: "Visión general",
      overview: "El equipo revisó el plazo de entrega y la presentación para el cliente, y acordó que el plazo actual es realista.",
      topicsTitle: "Temas",
      topics: [
        { title: "Plazo de entrega", text: "Considerado realista; el equipo mantiene la fecha actual." },
        { title: "Propuesta revisada", text: "Sale antes del jueves, antes de la demo para el cliente." },
        { title: "Números del trimestre", text: "Quedaron para el final de la reunión." },
      ],
      decisionsTitle: "Decisiones",
      decisions: ["Mantener el plazo actual."],
      copy: "Copiar",
      open: "Abrir archivo",
    },
  },
  privacy: {
    title: "Tu audio se queda en tu Mac.",
    text: "Mara fue diseñada para funcionar localmente. La nube es opcional, y ves exactamente cuánto usas.",
    items: [
      { title: "Transcripción local", text: "La hace el reconocimiento de voz de Apple, en el dispositivo." },
      { title: "Traducción local", text: "El traductor de Apple genera el subtítulo sin usar internet." },
      { title: "GPT opcional", text: "Activado, solo se envía el texto transcrito. Desactivado, nada sale del Mac." },
      { title: "Clave en el Llavero", text: "Tu clave de OpenAI se guarda en la bóveda de macOS, nunca en un archivo." },
      { title: "Tus archivos", text: "Las transcripciones y los resúmenes se guardan como archivos en tu Mac." },
      { title: "Consumo medido", text: "Tokens y costo estimado de cada llamada, por sesión, día y mes." },
    ],
  },
  faq: {
    title: "Preguntas frecuentes",
    items: [
      {
        question: "¿Los demás participantes saben que estoy usando Mara?",
        answer:
          "Mara no entra en la llamada: escucha el audio que ya sale de tu Mac. Avisar a los participantes y seguir las reglas de tu empresa sobre la transcripción de reuniones es responsabilidad de quien la usa.",
      },
      {
        question: "¿Necesito una clave de OpenAI?",
        answer:
          "No. La traducción local de Apple funciona sin clave y sin costo. La clave solo es necesaria para el resumen con IA y, si quieres, para el refinamiento de cada frase con GPT.",
      },
      {
        question: "¿Qué idiomas son compatibles?",
        answer:
          "Las reuniones pueden ser en inglés o en español y, por ahora, los subtítulos se muestran en portugués de Brasil. Las reuniones en portugués también funcionan: Mara las transcribe y resume, sin traducir. Eliges el idioma de la reunión antes de empezar.",
      },
      {
        question: "¿Cómo funciona el resumen?",
        answer:
          "Cuando termina la reunión, pides el resumen. La transcripción va a OpenAI con tu clave, y GPT identifica si fue una conversación entre varias personas o una presentación y cuenta lo que se habló: visión general, temas y decisiones. No se envía nada sin que lo pidas.",
      },
      {
        question: "¿Mara es de código abierto?",
        answer:
          "Sí, bajo la licencia MIT. La app está escrita en Swift y SwiftUI, sin servidor propio: las llamadas van directamente de tu Mac a OpenAI, con tu propia clave. Las contribuciones son bienvenidas.",
      },
      {
        question: "¿En qué computadoras funciona?",
        answer:
          "En Macs con macOS 26 o posterior. La primera vez, macOS pide permiso para grabar el audio del sistema.",
      },
      {
        question: "¿Cuánto cuesta usar GPT?",
        answer:
          "OpenAI cobra el costo en tu propia clave y suele quedar en centavos de dólar por hora de reunión. Mara muestra el consumo en tiempo real en los ajustes.",
      },
    ],
  },
  contribute: {
    badges: ["Swift nativo", "Hecho para macOS", "Código abierto, MIT", "Pull requests en GitHub"],
    title: "Contribuye",
    text: "Mara es de código abierto, bajo la licencia MIT. Léela, audítala, adáptala a tu flujo, abre una issue o envía un pull request.",
    github: "Ver en GitHub",
  },
  final: {
    title: "Empieza hoy.",
    text: "Abre Mara, elige el idioma y entra en la reunión.",
  },
  footer: "© 2026 Mara AI. Hecho para macOS.",
  notFound: {
    eyebrow: "Error 404",
    title: "Página no encontrada.",
    text: "La página que buscas no existe o cambió de dirección.",
    home: "Volver al inicio",
  },
};

const dictionaries: Record<Locale, Dictionary> = { en, pt, es };

export const getDictionary = (locale: Locale) => dictionaries[locale];
