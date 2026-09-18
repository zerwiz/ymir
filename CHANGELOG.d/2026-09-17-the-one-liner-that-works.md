## 2026-09-17 — the one-liner the README promised, and it sets the PATH

- **`install.sh` did not exist.** The README's first door (\`curl -fsSL …/install.sh | bash\`) led nowhere — which is how a user on another machine ends up typing \`ymir\` in every combination and getting nothing.
- **It exists now, and it removes the whole class of failure:** a prefix the user owns (no \`sudo\`, no \`EACCES\`), the \`export PATH\` written into the shell's rc so it survives the session, and then it **proves the door** with \`ymir --version\` rather than promising it.
- The command was never missing from the package — the published tarball ships \`bin/ymir.js\` and declares \`bin: {ymir, ymir-install}\`. **The shell simply was not looking where npm put it**, and that is the most common "it does not work" in the Node ecosystem.
