/** The long telling — the saga a visitor may open from the gate.
 *  Every capability is introduced through the name whose myth explains its job
 *  (see docs/lore.md; this is the public, feature-bearing retelling). */

export interface LoreName {
  rune: string;
  name: string;
  line: string;
}

export interface LoreSection {
  id: string;
  title: string;
  paras: string[];
  names?: LoreName[];
}

export const LORE_LONG: LoreSection[] = [
  {
    id: 'creation',
    title: 'I · The Birth of the Giant',
    paras: [
      'Before the worlds there was only Ginnungagap — the yawning void, where the frost of Niflheim met the embers of Muspelheim. From that meeting woke Ymir, the first being, the ancestor of all that came after.',
      'When the gods had shaped the world from his body, they did not leave the giant behind. Ymir is the machine beneath the worlds: one repository, one substrate, and from its frame every world of work is carved. Nothing here is painted on — the halls are chiselled from him, steel and rune and bone.',
    ],
    names: [
      { rune: 'ᛉ', name: 'Ymir', line: 'The substrate — one repo, one machine, the body all realms are carved from.' },
      { rune: 'ᚢ', name: 'Ginnungagap', line: 'The void before the build — the empty space a new world is raised in.' },
    ],
  },
  {
    id: 'smiths',
    title: 'II · The Smiths at the Forge',
    paras: [
      'To work the metal, the gods needed smiths, and the greatest were the dwarf brothers. Brokk stands at the bellows, feeding the fire and driving the work to its end; his brother shapes the craft. Together they forged the finest treasures of Asgard.',
      'In Ymir, Brokk is the primary agent — the one who keeps the forge hot and never abandons a task half-struck. The Eindri are his delegated hands: isolated smiths, each struck off into a sealed realm so a single bad casting can never shatter the whole forge. Between them sits Smíðja, the smithy itself — the engine that reads the roster, sets the phases, and carries every errand to its acceptance gate. Its master smith is Völundr, who decides how the shop runs, while Kaia decides what is worth forging.',
    ],
    names: [
      { rune: 'ᛒ', name: 'Brokk', line: 'The primary agent — the bellows that drives every task to an artifact.' },
      { rune: 'ᛖ', name: 'Eindri', line: 'Isolated workers — delegated hands in sealed sandboxes.' },
      { rune: 'ᛊ', name: 'Smíðja', line: 'The smithy — the agent factory: rosters, phases, envelopes, gates.' },
      { rune: 'ᚹ', name: 'Völundr', line: 'The master smith — the smithy’s orchestrator.' },
    ],
  },
  {
    id: 'realms',
    title: 'III · The Tree and the Nine Realms',
    paras: [
      'The worlds do not float apart; they hang in one tree. Yggdrasil binds them, holding each realm aloft. Work in Ymir grows the same way: every branch is a worktree, and parallel hands may shape the same tree without ever colliding.',
      'Beneath the branches lie the halls: the tenant workspaces of Svartalfaheim, each a dwarf-hall that touches no other. Beyond the wall waits Utgard, the realm of giants — a sealed sandbox where untrusted work runs and is unmade, so nothing dangerous ever enters the halls. And gathered between all worlds lies Midgard, the commons: the shared assets that belong to everyone and to no one.',
    ],
    names: [
      { rune: 'ᛇ', name: 'Yggdrasil', line: 'Worktree isolation — parallel branches, zero collision.' },
      { rune: 'ᛋ', name: 'Svartalfaheim', line: 'Tenant workspaces — isolated halls, nothing bleeds between them.' },
      { rune: 'ᚦ', name: 'Utgard', line: 'The sealed sandbox — untrusted work runs there and is destroyed.' },
      { rune: 'ᛗ', name: 'Midgard', line: 'The shared commons — assets that serve every realm.' },
    ],
  },
  {
    id: 'well',
    title: 'IV · The Well of Memory',
    paras: [
      'At the root of the tree runs Mimirsbrunn, the well of wisdom. Even Odin gave an eye for a single drink. Memory here is a well that never runs dry and never blocks the work: drink deep, and act wiser.',
      'From the well speaks Kaia, the oracle and the eye of the fleet. She does not act on faith — before she dispatches a single smith she drinks, recalling everything the project has taught, and then passes every plan through the Veil, the filter that asks: is this grounded in what the well holds, or spun from air? Everything the fleet does is inscribed into Runes, the ledger carved once and never un-carved.',
    ],
    names: [
      { rune: 'ᛗ', name: 'Mimirsbrunn', line: 'Long-term memory — the engram well the fleet drinks from.' },
      { rune: 'ᚲ', name: 'Kaia', line: 'The oracle — recalls before every dispatch; the eye that remembers.' },
      { rune: 'ᚹ', name: 'The Veil', line: 'The anti-hallucination gate — nothing passes without evidence.' },
      { rune: 'ᚱ', name: 'Runes', line: 'The append-only audit ledger — a rune carved stays carved.' },
    ],
  },
  {
    id: 'messenger',
    title: 'V · The Messenger on the Tree',
    paras: [
      'A squirrel named Ratatoskr runs the length of the tree, carrying word between the eagle above and the serpent below. In Ymir, Ratatoskr is how agents speak to one another: the open A2A 1.0 protocol for horizontal delegation, with Redis as the squirrel’s nest beneath it.',
      'Every agent that joins the tree carries a rune of introduction — a signed card naming its skills and its address — so discovery is by capability, never by guessing. And Hermóðr, the messenger who crossed to Hel and back, is the bridge by which an orchestrator delegates sideways to its peers while specialists reach their tools straight down.',
    ],
    names: [
      { rune: 'ᚱ', name: 'Ratatoskr', line: 'A2A collaboration — agents delegating across the tree.' },
      { rune: 'ᚨ', name: 'Runes of introduction', line: 'Signed agent cards — discovery by capability, never by address.' },
      { rune: 'ᚺ', name: 'Hermóðr', line: 'The MCP/A2A bridge — sideways delegation, vertical tools.' },
    ],
  },
  {
    id: 'seat',
    title: 'VI · The High Seat and the Gate',
    paras: [
      'From Hlidskjalf, Odin’s high seat, the Allfather sees every realm at once. It is the control plane: one operator’s window onto every agent, task, rune, and run — the fleet graph, the task stream, the well, and the reviews.',
      'Every crossing into this world passes over Bifrost, the burning bridge; at its foot stands Heimdall, the watchman who vouches for every traveller — the guard that signs each agent’s rune of introduction, so no forged identity crosses. Gjallarhorn, Heimdall’s horn, carries the signal outward through the cloud. And when a change is ready it comes to Glitnir, the shining hall of judgement, where no merge passes without a human word.',
    ],
    names: [
      { rune: 'ᚠ', name: 'Hlidskjalf', line: 'The control plane — the sovereign’s view of the whole fleet.' },
      { rune: 'ᛒ', name: 'Bifrost', line: 'The ingress gateway — every crossing passes over it.' },
      { rune: 'ᚺ', name: 'Heimdall', line: 'The security guard — signs every agent’s rune of introduction.' },
      { rune: 'ᚷ', name: 'Gjallarhorn', line: 'The outbound tunnel — the horn that carries Ymir to the world.' },
      { rune: 'ᚷ', name: 'Glitnir', line: 'The human review gate — no merge without judgement.' },
    ],
  },
  {
    id: 'artifacts',
    title: 'VII · The Artifacts',
    paras: [
      'The smiths forged the gods’ weapons, and Ymir ships the same by analogy. Gungnir is Odin’s spear that never misses its mark — the skill-synthesis engine: a new capability is forged, proven in Utgard, and then it strikes true every time. Mjölnir is the hammer that returns to the hand — the issue-to-pull-request pipeline: it strikes an issue and comes back carrying a pull request.',
      'Skrymir is the giant’s huge and silent hand reaching into the halls — the file browser. And Valhalla is the hall of the slain, where every hero is watched: the process monitor that keeps each daemon’s soul alive and in sight.',
    ],
    names: [
      { rune: 'ᚷ', name: 'Gungnir', line: 'Skill synthesis — forged, validated, then it hits its mark.' },
      { rune: 'ᛗ', name: 'Mjölnir', line: 'The issue→PR pipeline — strikes, and returns with a pull request.' },
      { rune: 'ᛋ', name: 'Skrymir', line: 'The file browser — the huge hand reaching into the halls.' },
      { rune: 'ᚹ', name: 'Valhalla', line: 'The process monitor — every daemon kept alive and watched.' },
    ],
  },
  {
    id: 'forge-rule',
    title: 'VIII · The Rule of the Forge',
    paras: [
      'The greatest smiths do not hammer every nail themselves; they take up proven anvils. Ymir forges only what makes it Ymir — the seat, the smiths, and the messenger — while everything beneath is a validated open-source engine given a Norse name and a Norn-carved shell.',
      'The giant is first carved in light metals — the working metals the smiths know best — so the whole of Ymir can be raised and proven end to end. When every gate answers, the forging is not done; it is reforged in heavier steel, one piece at a time. Never redesigned — only re-forged.',
    ],
    names: [
      { rune: 'ᛉ', name: 'The forge rule', line: 'Open-source first — name the proven anvil, smith only what Ymir is.' },
      { rune: 'ᛞ', name: 'The Reforging', line: 'Light metal first, then Rut steel — same contract, heavier metal.' },
    ],
  },
];
