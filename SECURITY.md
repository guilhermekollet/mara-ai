# Security Policy

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's **Report a vulnerability** button in the
repository's Security tab to send a private report, and include steps to reproduce.

## What matters most here

Mara handles meeting content and API keys, so we especially care about:

- The OpenAI API key leaking outside the macOS Keychain — for example into logs or files.
- Meeting audio leaving the Mac. It never should.
- Transcript text being sent to a service without the user turning that feature on.
- Session logs and transcripts are plain text files in the user's folders; anything that widens
  who can read them is in scope.
- The updater. It installs a new version only when the downloaded zip carries a valid Ed25519
  signature from the project's update key and the app inside is Mara, at the release's version,
  signed with the project's certificate. Any way to get it to install something else is in scope.
