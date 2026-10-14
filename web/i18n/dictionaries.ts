// Every piece of copy on the site, in each language it is published in. The page picks the
// dictionary from the URL (/en, /pt, /es); the root URL sends visitors to the one that matches
// their browser, falling back to English.
//
// The captions shown inside the demos stay in Portuguese in every language: the app translates
// meetings into Brazilian Portuguese, so that is what it really displays.

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
      "Mara AI captions and translates your meetings into Portuguese in real time, right on your Mac, summarizes the conversation and turns action items into Linear issues.",
  },
  a11y: {
    sections: "Sections",
    footer: "Footer",
    language: "Language",
    toggleTheme: "Switch between light and dark theme",
    toggleThemeShort: "Toggle theme",
    captionDemo: "Mara AI window showing captions translated into Portuguese",
  },
  nav: {
    howItWorks: "How it works",
    modules: "Modules",
    tasks: "Tasks",
    privacy: "Privacy",
    faq: "FAQ",
  },
  download: "Download for macOS",
  getStarted: "Get started free",
  hero: {
    eyebrow: "Mara AI for macOS",
    title: "Meetings, without barriers.",
    text: "Real-time translated captions, right on your Mac. Understand every word while it is still being spoken.",
    seeHow: "See how it works",
  },
  demo: { you: "You", youInitials: "YOU" },
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
        text: "The Portuguese caption takes shape in real time and is refined at the end of each sentence.",
      },
    ],
  },
  modules: {
    title: "Built for developers",
    text: "From the English stand-up with the team abroad to the issues in Linear: Mara follows the meeting from start to finish.",
    available: "Available",
    items: [
      {
        title: "Meetings in other languages",
        text: "Live captions in a discreet window over the call, and a summary ready when the meeting ends.",
        points: ["Instant translation on your Mac", "Optional GPT refinement", "Summary with key points, decisions and action items"],
      },
      {
        title: "Tasks in Linear",
        text: "The action items from each meeting become Linear issues, and your cycle is one click away, in the menu bar.",
        points: ["Summary action items become issues", "Your cycle in the menu bar", "Team deliveries per day"],
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
  tasks: {
    eyebrow: "Tasks",
    title: "What was said becomes what needs to be done.",
    text: "When the meeting ends, Mara summarizes the conversation and picks out the action items. Each one becomes a Linear issue, with assignee, due date and priority, after you review it.",
    points: [
      {
        title: "Team deliveries, per day",
        text: "A chart of what each person completed over the last few days, each in their own color, right in the panel and, in detail, by day or by week.",
      },
      {
        title: "Your cycle in the menu bar",
        text: "One click shows the highest-priority task in progress and how many are open, in progress, in review and done.",
      },
      {
        title: "Without leaving the meeting",
        text: "Action items become issues in the team you choose, with assignee, due date and priority. Nothing is created until you review it.",
      },
    ],
    mock: {
      deliveries: "Deliveries ›",
      send: "Send",
      status: { progress: "In Progress", review: "In Review", todo: "Todo", done: "Done" },
      stats: { open: "Open", progress: "In progress", review: "Review", done: "Done" },
      items: [
        { title: "Send the revised proposal", due: "Thursday" },
        { title: "Confirm the delivery date", due: "Today" },
        { title: "Schedule the follow-up with the tech team", due: "Tuesday" },
      ],
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
          "No. Apple's local translation works without a key and at no cost. The key is only needed if you want GPT refinement at the end of each sentence.",
      },
      {
        question: "Which languages are supported?",
        answer:
          "The meeting can be in any language that Apple's speech recognition and translator offer on your Mac, such as English, Spanish, German, French, Chinese and Japanese. Captions are shown in Brazilian Portuguese. You pick the meeting language before you start.",
      },
      {
        question: "How do action items become issues?",
        answer:
          "When the meeting ends you ask for the summary, and each action item it finds appears with an assignee and due date when they were mentioned. You review the title, assignee, due date and priority and send them to Linear, one by one.",
      },
      {
        question: "Do I need to use Linear?",
        answer:
          "For tasks, yes: Linear is where they live. Captions, translation and the summary work without it. With Linear connected, the panel shows the current cycle and the team's deliveries, and nothing is sent until you review it.",
      },
      {
        question: "Is Mara open source?",
        answer:
          "Yes, under the MIT license. The app is written in Swift and SwiftUI, with no server of its own: calls go straight from your Mac to OpenAI and Linear, with your own keys. Contributions are welcome.",
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
};

export type Dictionary = typeof en;

const pt: Dictionary = {
  meta: {
    title: "Mara AI — Reuniões em qualquer idioma",
    description:
      "Mara AI legenda e traduz suas reuniões em tempo real, direto no Mac, resume a conversa e transforma as pendências em issues no Linear.",
  },
  a11y: {
    sections: "Seções",
    footer: "Rodapé",
    language: "Idioma",
    toggleTheme: "Alternar entre tema claro e escuro",
    toggleThemeShort: "Alternar tema",
    captionDemo: "Janela da Mara AI mostrando legendas traduzidas para português",
  },
  nav: {
    howItWorks: "Como funciona",
    modules: "Módulos",
    tasks: "Demandas",
    privacy: "Privacidade",
    faq: "Perguntas",
  },
  download: "Baixar para macOS",
  getStarted: "Começar grátis",
  hero: {
    eyebrow: "Mara AI para macOS",
    title: "Reuniões, sem barreira.",
    text: "Legendas traduzidas em tempo real, direto no seu Mac. Entenda cada palavra enquanto ela ainda está sendo dita.",
    seeHow: "Ver como funciona",
  },
  demo: { you: "Você", youInitials: "VOCÊ" },
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
    text: "Da daily em inglês com o time de fora às issues no Linear: a Mara acompanha a reunião do começo ao fim.",
    available: "Disponível",
    items: [
      {
        title: "Reuniões em outros idiomas",
        text: "Legendas ao vivo numa janela discreta sobre a chamada e um resumo pronto quando a reunião termina.",
        points: ["Tradução instantânea no Mac", "Refinamento opcional por GPT", "Resumo com pontos, decisões e pendências"],
      },
      {
        title: "Demandas no Linear",
        text: "As pendências de cada reunião viram issues no Linear, e a sua cycle fica a um clique, na barra de menus.",
        points: ["Pendências do resumo viram issues", "Sua cycle na barra de menus", "Entregas do time por dia"],
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
  tasks: {
    eyebrow: "Demandas",
    title: "O que foi dito vira o que precisa ser feito.",
    text: "Quando a reunião termina, a Mara resume a conversa e separa as pendências. Cada uma vira uma issue no Linear, com responsável, prazo e prioridade, depois que você confere.",
    points: [
      {
        title: "Entregas do time, por dia",
        text: "Um gráfico com o que cada pessoa concluiu nos últimos dias, cada uma com a sua cor, direto no painel e, em detalhe, por dia ou por semana.",
      },
      {
        title: "Sua cycle na barra de menus",
        text: "Um clique mostra a demanda em progresso de maior prioridade e quantas estão abertas, em progresso, em review e concluídas.",
      },
      {
        title: "Sem sair da reunião",
        text: "As pendências viram issues no time que você escolher, já com responsável, prazo e prioridade. Nada é criado sem você conferir.",
      },
    ],
    mock: {
      deliveries: "Entregas ›",
      send: "Enviar",
      status: { progress: "Em progresso", review: "Em review", todo: "A fazer", done: "Concluída" },
      stats: { open: "Abertas", progress: "Progresso", review: "Review", done: "Concluídas" },
      items: [
        { title: "Enviar a proposta revisada", due: "quinta-feira" },
        { title: "Confirmar o prazo de entrega", due: "hoje" },
        { title: "Agendar a continuação com o time técnico", due: "terça" },
      ],
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
          "Não. A tradução local da Apple funciona sem chave e sem custo. A chave só é necessária se você quiser o refinamento por GPT ao fim de cada frase.",
      },
      {
        question: "Quais idiomas são suportados?",
        answer:
          "Os idiomas que o reconhecimento de fala e o tradutor da Apple oferecem no seu Mac, como inglês, espanhol, alemão, francês, chinês e japonês. Você escolhe o idioma da reunião antes de iniciar.",
      },
      {
        question: "Como as pendências viram issues?",
        answer:
          "Ao fim da reunião você pede o resumo, e cada pendência identificada aparece com responsável e prazo quando eles foram mencionados. Você confere título, responsável, prazo e prioridade e envia ao Linear, uma a uma.",
      },
      {
        question: "Preciso usar o Linear?",
        answer:
          "Para as demandas, sim: é no Linear que elas moram. As legendas, a tradução e o resumo funcionam sem ele. Com o Linear conectado, o painel mostra a cycle atual e as entregas do time, e nada é enviado sem você conferir.",
      },
      {
        question: "A Mara é de código aberto?",
        answer:
          "Sim, sob licença MIT. O app é escrito em Swift e SwiftUI, sem servidor próprio: as chamadas vão direto do seu Mac para a OpenAI e o Linear, com as suas chaves. Contribuições são bem-vindas.",
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
};

const es: Dictionary = {
  meta: {
    title: "Mara AI — Reuniones en cualquier idioma",
    description:
      "Mara AI subtitula y traduce tus reuniones al portugués en tiempo real, directamente en tu Mac, resume la conversación y convierte los pendientes en issues de Linear.",
  },
  a11y: {
    sections: "Secciones",
    footer: "Pie de página",
    language: "Idioma",
    toggleTheme: "Cambiar entre tema claro y oscuro",
    toggleThemeShort: "Cambiar tema",
    captionDemo: "Ventana de Mara AI mostrando subtítulos traducidos al portugués",
  },
  nav: {
    howItWorks: "Cómo funciona",
    modules: "Módulos",
    tasks: "Tareas",
    privacy: "Privacidad",
    faq: "Preguntas",
  },
  download: "Descargar para macOS",
  getStarted: "Empezar gratis",
  hero: {
    eyebrow: "Mara AI para macOS",
    title: "Reuniones, sin barreras.",
    text: "Subtítulos traducidos en tiempo real, directamente en tu Mac. Entiende cada palabra mientras todavía se está diciendo.",
    seeHow: "Ver cómo funciona",
  },
  demo: { you: "Tú", youInitials: "TÚ" },
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
        text: "El subtítulo en portugués se va formando en tiempo real y se refina al final de cada frase.",
      },
    ],
  },
  modules: {
    title: "Hecho para quienes desarrollan",
    text: "De la daily en inglés con el equipo de fuera a las issues en Linear: Mara acompaña la reunión de principio a fin.",
    available: "Disponible",
    items: [
      {
        title: "Reuniones en otros idiomas",
        text: "Subtítulos en vivo en una ventana discreta sobre la llamada y un resumen listo cuando termina la reunión.",
        points: ["Traducción instantánea en el Mac", "Refinamiento opcional con GPT", "Resumen con puntos, decisiones y pendientes"],
      },
      {
        title: "Tareas en Linear",
        text: "Los pendientes de cada reunión se convierten en issues de Linear, y tu cycle queda a un clic, en la barra de menús.",
        points: ["Los pendientes del resumen se vuelven issues", "Tu cycle en la barra de menús", "Entregas del equipo por día"],
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
  tasks: {
    eyebrow: "Tareas",
    title: "Lo que se dijo se convierte en lo que hay que hacer.",
    text: "Cuando termina la reunión, Mara resume la conversación y separa los pendientes. Cada uno se convierte en una issue de Linear, con responsable, fecha límite y prioridad, después de que lo revisas.",
    points: [
      {
        title: "Entregas del equipo, por día",
        text: "Un gráfico con lo que cada persona completó en los últimos días, cada una con su color, directamente en el panel y, en detalle, por día o por semana.",
      },
      {
        title: "Tu cycle en la barra de menús",
        text: "Un clic muestra la tarea en progreso de mayor prioridad y cuántas están abiertas, en progreso, en revisión y completadas.",
      },
      {
        title: "Sin salir de la reunión",
        text: "Los pendientes se convierten en issues en el equipo que elijas, con responsable, fecha límite y prioridad. No se crea nada sin que lo revises.",
      },
    ],
    mock: {
      deliveries: "Entregas ›",
      send: "Enviar",
      status: { progress: "En progreso", review: "En revisión", todo: "Por hacer", done: "Completada" },
      stats: { open: "Abiertas", progress: "Progreso", review: "Revisión", done: "Hechas" },
      items: [
        { title: "Enviar la propuesta revisada", due: "jueves" },
        { title: "Confirmar la fecha de entrega", due: "hoy" },
        { title: "Agendar el seguimiento con el equipo técnico", due: "martes" },
      ],
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
          "No. La traducción local de Apple funciona sin clave y sin costo. La clave solo es necesaria si quieres el refinamiento con GPT al final de cada frase.",
      },
      {
        question: "¿Qué idiomas son compatibles?",
        answer:
          "La reunión puede estar en cualquier idioma que el reconocimiento de voz y el traductor de Apple ofrezcan en tu Mac, como inglés, español, alemán, francés, chino y japonés. Los subtítulos se muestran en portugués de Brasil. Eliges el idioma de la reunión antes de empezar.",
      },
      {
        question: "¿Cómo se convierten los pendientes en issues?",
        answer:
          "Al final de la reunión pides el resumen, y cada pendiente identificado aparece con responsable y fecha límite cuando se mencionaron. Revisas el título, el responsable, la fecha y la prioridad y lo envías a Linear, uno por uno.",
      },
      {
        question: "¿Necesito usar Linear?",
        answer:
          "Para las tareas, sí: es en Linear donde viven. Los subtítulos, la traducción y el resumen funcionan sin él. Con Linear conectado, el panel muestra el cycle actual y las entregas del equipo, y no se envía nada sin que lo revises.",
      },
      {
        question: "¿Mara es de código abierto?",
        answer:
          "Sí, bajo la licencia MIT. La app está escrita en Swift y SwiftUI, sin servidor propio: las llamadas van directamente de tu Mac a OpenAI y Linear, con tus propias claves. Las contribuciones son bienvenidas.",
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
};

const dictionaries: Record<Locale, Dictionary> = { en, pt, es };

export const getDictionary = (locale: Locale) => dictionaries[locale];
