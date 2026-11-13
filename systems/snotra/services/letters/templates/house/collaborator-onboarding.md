# Shape — a collaborator joins the work

**Subject:** Your place in <the work> — the login, and what it opens

---

Hi <name>,

<One line: what they can do now that they could not before, and that this letter is the whole of the setup.>

**What you get.** <The one credential, and the doors it opens, in the order they will meet them — the sign-in, then the
first surface. Say plainly that it is one login for the suite, because a person who expects six passwords stops at two.>

CHECKPOINT: <What a correct first sign-in looks like in words they can check themselves — the page, the thing on the page,
and nothing to install.>

**What you are.** <Their place in the work, named: a collaborator on <thing>, with the rights that match it (read, draw,
comment, edit), and the person who answers when a right is wrong.>

**What you are not.** <The boundaries as design, not distrust: the surfaces not open to them yet and the one-line reason,
the data they will not see, what stays behind the gate. Close with *say the word and it opens* — an access boundary is a
decision someone can reverse, not a wall.>

**If the key fails.** <The reset path, named: which page resets it, which address it arrives at, and what to send you if
nothing arrives. A credential with no way back is a support ticket waiting.>

**The one first step.** <One bounded act in the first session, on real work, chosen so a mistake is cheap and visible — the
scene they open and draw on with you, the card they move, the sentence they write. Never "have a look around".>

<Sign.>

---

## After sending

`bin/mail/ledger.sh out --to <address> --subject "<subject>" --gmail <id>`.

Two records, not one: the ledger line for the letter, and a line in the house's collaboration record naming what was
opened, for whom, and when (`hodd/data/collaboration.yaml`). The credential itself lives in the vault
(`hodd/secrets/`), never in either record.

## Rules this shape holds

1. **One credential, one letter.** A second login is a second letter; a letter with two keys gets half-used.
2. **The letter is the only place the person reads the key** — the vault holds it for us, the letter for them, and nothing is read aloud.
3. **The first step is on real work**, because an invitation to "explore" is answered by closing the tab.
4. **One address, the door they sign in at.** The suite's own address is what a person needs; a path into the home is never
   in a letter, and `private-guard --surface email` refuses it for that reason.
5. **What is not open is written down.** A boundary nobody named is read as an oversight, and the next letter is an apology.

## CHANGE LOG

- **2026-11-13** — Carved from a real letter: a client's suite login re-enabled and sent (the whiteboard, one key, the
  board and the desk page deliberately left closed and said so). The shape existed as a row in this shelf's index for
  weeks and as no file; the index is now true.
