import { defaultLocale, locales } from "./dictionaries";

// Where the header switcher remembers the visitor's choice of language.
export const languageStorageKey = "lang";

// The body of a function that picks the visitor's language: the one chosen in the header
// switcher, if any; otherwise the first of the browser's languages, in the visitor's order of
// preference, that the site has, matched by its primary subtag (pt-PT and pt-BR are pt, es-MX is
// es, en-GB is en); otherwise English. The site is static, so this can only run in the browser,
// and it has to be plain ES5 to run inline before anything else on the page.
const detectLocaleBody = `var s=${JSON.stringify(locales)},l;
try{l=localStorage.getItem(${JSON.stringify(languageStorageKey)})}catch(e){}
if(s.indexOf(l)>=0)return l;
var n=[];try{n=navigator.languages&&navigator.languages.length?navigator.languages:[navigator.language]}catch(e){}
for(var i=0;i<n.length;i++){var p=String(n[i]||"").split(/[-_]/)[0].toLowerCase();if(s.indexOf(p)>=0)return p}
return ${JSON.stringify(defaultLocale)}`.replace(/\n/g, "");

// A JavaScript expression, for inline scripts, that evaluates to the visitor's language.
export const detectLocaleExpression = `(function(){${detectLocaleBody}})()`;
