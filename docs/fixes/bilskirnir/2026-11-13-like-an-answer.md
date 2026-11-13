# Bilskirnir: like an answer, and the agent knows

**Status:** built and tested in Bilskirnir's window on nidavellir, 2026-11-13 (plan 275), at the Allfather's word:
*"I want to be able to like messages in the chat so the AI knows I liked the answer outputted."*

| Part | Change |
|---|---|
| The room | A like button under each finished answer of the agent (quiet until hovered, filled once liked); a second click takes it back |
| The server | `POST /api/bots/:id/rows/:seq/like {liked}` marks the message (`liked` on the message body); only an agent's answer can be liked |
| The agent | Its standing instructions carry "Answers he liked": the last five liked answers in its room, with the ask to notice what they share and lean toward it. No extra model call |

**Proven on nidavellir:** ten answers carried the button; liking "48" saved the mark; asked "Which of your answers have
I marked as liked?", Nanna answered in 18 s: "The answer you marked as liked is: 48". The test like was then taken
back with the same button (0 liked rows left).
