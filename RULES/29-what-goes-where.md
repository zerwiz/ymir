# 29 — What goes where: five classes, and a workspace is a boundary with people on one side

**Appended 2026-10-22** at the Allfather's word: *"the NDA must go into private … if I invite somebody else
to come into whynot they will have the secrets … we MUST BE SUPER SECURE ON WHAT DATA GOES WHERE: WHO CAN
SEE WHAT."*

**Why it exists, from this day's own wounds.** A team suite was stood up — a hall, a board, documents, a
whiteboard, a desk, an agent bus — and every one of them could see everything, because none of them had been
told what "everything" was. A workspace is not a folder: **it is a boundary with people on one side of it.**
Anything placed inside is visible to everyone who may enter, so the only useful question before a card, a
quote or a document is not *"is this sensitive?"* but **"who exactly would see this, if I invited the next
person tomorrow?"**

```
classification[5]{class,examples,may_live_in}:
  "0 · public","the lore site, marketing, the repo's own documents","anywhere, including the open web"
  "1 · team","project names, board cards, due dates, decisions of the makers","a team workspace; the desk; the agent bus, for a member of that workspace"
  "2 · client-confidential","a client's delivery work, their prices, their people, their meeting records","**only that client's own workspace**, and only for its members"
  "3 · NDA / contracted","NDAs, patent material, contracted terms, the confidential register","**the vault only** — and to a named party, a derived summary that quotes nothing"
  "4 · the vault","keys, tokens, `hodd/secrets`, Hnitbjörg","**the encrypted vault only**"
```

```
law[8]{rule,what_it_means}:
  "EVERY DOCUMENT, CARD AND MESSAGE CARRIES A CLASS","if nobody wrote it down, it is class 3 by default — the safe answer is that it may not be shared"
  "A WORKSPACE IS NOT A FOLDER","it is a boundary with people on one side. Placing a thing is admitting everyone who may enter"
  "ONE WORKSPACE PER HOUSE, ONE PROJECT PER THING","a company or a private scope is the workspace; a piece of work is the project. Mixing houses is how one client reads another"
  "CLASS 3 NEVER PROJECTS","an NDA, a patent, a contracted term does not appear on a board, in a document store, in a card, in a chat, in an email, or in a model's context. It is read where it lives, by a person entitled to it"
  "CLASS 2 DOES NOT CROSS HOUSES","a client's work lives in that client's project and nowhere else — not on a shared board, not in a common desk, not in a summary for the team"
  "A MEMBERSHIP IS A DISCLOSURE","adding a person to a space is disclosing everything in it, past and future. Invite to the smallest space that does the work, never to the app"
  "PRIVATE LIVES IN THE PRIVATE WORKSPACE","the operator's own studies, notes and personal plans live where no invitation can reach; a company workspace holds company work"
  "AN AGENT ACTS AS ITS PERSON","an agent may read only what its person may read, in the same space, and every call says who asked"
```

```
structures[4]{space,what_it_is_for,who_enters}:
  "`ymirhome` (private)","the operator's own: personal plans, studies, the home's records","the operator alone — an invitation is never sent"
  "`<house>` (e.g. `whynotproductions`, `wayof`, `synteon`)","one company's work, its products and its projects","that company's members"
  "`<client>` (e.g. `optikat`)","one client's project, one place","that client and the people delivering for it"
  "the vault","class 3 and class 4 only","the operator, while the vault is open"
```

```
enforcement[6]{point,what_it_must_do}:
  "the identity provider","a group per house; a rule per application naming the group that may enter — an account is not a key to every door"
  "the board","one workspace per house; private projects for work in progress; membership per workspace, never per app"
  "the document store","one workspace per house; a client's documents never in a shared instance view"
  "the desk","renders only the places the signed-in person belongs to; everything else is not rendered at all"
  "the agent bus (MCP)","a token names its person **and its places**; a call outside them is refused **and recorded**; no write tool ships before this"
  "the projector","reads the meeting's classification and refuses class 3 entirely; class 2 quotes are reduced to the decision, never the words"
```

**The test, in one line:** *before anything is placed — a card, a quote, a document, an invitation — name the
person who would see it tomorrow, and if the answer is "whoever joins next", it is in the wrong place.*

**Enforced by:** the workspace structure above; the gate's groups and per-application rules; the desk's and the
MCP's place checks; the projector's classification gate; and `bin/gates/guards/confidential-guard.sh` for the
repository side of the same law.
