# Contributing to Mara AI

Thanks for helping! This guide covers how to set up the project, what we expect from a change and
how to get it merged.

## Setup

1. macOS 26 or later with Swift 6.2+ (Xcode 26, or the Command Line Tools 26.1+).
2. Clone the repository and build once: `./build.sh`.
3. Optional but recommended: `scripts/create-signing-cert.sh`, so macOS keeps the screen-recording
   permission between your builds (see the README).
4. Run the tests: `scripts/test.sh`.

You don't need API keys to work on most of the app: captions, on-device translation, standby and
the UI all run without them. GPT refinement and summaries need an OpenAI key; the Linear features
need a Linear personal API key. Use your own keys, and never commit them.

## Making a change

- **Open an issue first** for anything bigger than a small fix, so we can agree on the approach.
- **Keep pull requests focused**: one change per PR, with a description of what and why.
- **Match the surrounding code**: SwiftUI views, `@MainActor` model, small helpers, and comments
  that explain *why*, not *what*. Code and comments are in English; the app's UI text is in
  Brazilian Portuguese.
- **Add or update tests** for logic you touch. The suite uses Swift Testing (`import Testing`).
  If a helper needs Foundation or AVFoundation, put it in `Tests/MaraAITests/Fixtures.swift`:
  with only the Command Line Tools installed, a file that imports both `Testing` and `Foundation`
  does not compile.
- **Check it builds and the tests pass**: `swift build` and `scripts/test.sh`. For UI changes,
  include a screenshot or a short recording in the PR.
- **Privacy is a feature**: meeting audio must never leave the Mac, and nothing may be sent to an
  external service without the user turning it on. Call out any change that sends data anywhere.

## Commit messages

Use the [Conventional Commits](https://www.conventionalcommits.org) style, in English, for example
`feat: add Spanish (Mexico) to the language menu` or `fix(linear): read every page of the cycle`.
No co-author or "generated with" trailers.

`scripts/ship.sh` does the whole round and checks the convention at each step:

```bash
scripts/ship.sh setup                                   # once: check every commit message
scripts/ship.sh branch fix/caption-punctuation
git add -p
scripts/ship.sh commit "fix: keep punctuation on the right line" body.txt
scripts/ship.sh push
scripts/ship.sh pr                                      # title and description from the commit
scripts/ship.sh merge 42                                # maintainers: squash once checks pass
```

## Website

The site in `web/` is a Next.js app. `npm install`, then `npm run dev`. If you change
`app/globals.css` and the page doesn't update, stop the dev server, delete `web/.next` and start it
again.

## Reporting bugs

Use the bug report template and attach the relevant lines of `~/Library/Logs/MaraAI/sessao.log`
(remove any meeting content you don't want to share).
