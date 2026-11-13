/**
 * The tools the assistant may hold — and the boundary that decides.
 *
 * His word, twice: *"it should only have tools inside whitebord."* So this file
 * holds the whole permitted surface, and the surface is exactly what a person can
 * already do from the whiteboard's own menus. Nothing here reaches the hall, the
 * plan ledger, a mailbox, a record or the internet, and there is no tier 2 to
 * grow into: a tool that needs any of those is not a whiteboard tool.
 *
 * The bridge does not EXECUTE a tool. It declares the surface to the model and
 * relays the model's intent to the panel, which runs it against the room the
 * person is already looking at, and relays the result back. That is deliberate:
 * the tool that touches a canvas is the client's own code, so the assistant can
 * never act on a room nobody is looking at.
 *
 * `tickets/open/feature-0037-uw-converse-before-the-diagram.md`.
 */

/**
 * The five board-local tools from the ticket, plus the two the whiteboard owns
 * outright (its own save and its own share). `read_canvas` is feature-0025's own
 * road; it is listed so the model knows it may look before it speaks.
 */
export const BOARD_TOOLS = [
  {
    type: "function",
    function: {
      name: "read_canvas",
      description:
        "Read the elements of the room this person is looking at, as data: id, type, label, position and size. Read it before you propose a diagram, so a new figure joins what is there instead of drawing over it.",
      parameters: { type: "object", properties: {}, additionalProperties: false },
    },
  },
  {
    type: "function",
    function: {
      name: "add_elements",
      description:
        "Place nodes and edges structurally — a list of shapes and the connections between them — instead of returning Mermaid text. One call is one undo step, and a structured call cannot produce a parse error.",
      parameters: {
        type: "object",
        properties: {
          nodes: {
            type: "array",
            items: {
              type: "object",
              properties: {
                id: { type: "string", description: "a name you will use in edges" },
                label: { type: "string" },
                shape: { type: "string", enum: ["rectangle", "ellipse", "diamond"] },
              },
              required: ["id"],
            },
          },
          edges: {
            type: "array",
            items: {
              type: "object",
              properties: { from: { type: "string" }, to: { type: "string" } },
              required: ["from", "to"],
            },
          },
        },
        required: ["nodes"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "update_elements",
      description:
        "Move, relabel or recolour elements YOU created in this same turn. Never an element the person drew: their own strokes are immutable to you.",
      parameters: {
        type: "object",
        properties: {
          updates: {
            type: "array",
            items: {
              type: "object",
              properties: {
                id: { type: "string" },
                x: { type: "number" },
                y: { type: "number" },
                label: { type: "string" },
                strokeColor: { type: "string" },
              },
              required: ["id"],
            },
          },
        },
        required: ["updates"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "validate_diagram",
      description:
        "Check a diagram before offering it: every edge names two nodes that exist, and every node has a label or is deliberately empty. A refusal here is a sentence the person can read, not a parse failure.",
      parameters: {
        type: "object",
        properties: {
          nodes: { type: "array", items: { type: "object" } },
          edges: { type: "array", items: { type: "object" } },
        },
        required: ["nodes"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "focus",
      description:
        "Frame or highlight a region of the canvas you are discussing, so 'this bit' means the same to both of you. A viewport change, never a content change.",
      parameters: {
        type: "object",
        properties: {
          ids: { type: "array", items: { type: "string" } },
          x: { type: "number" },
          y: { type: "number" },
          width: { type: "number" },
          height: { type: "number" },
        },
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "save_room",
      description:
        "Save this board to the person's own shelf on the server, exactly as the Save to server action does. The save belongs to the signed-in person — the server decides that, not you.",
      parameters: { type: "object", properties: {}, additionalProperties: false },
    },
  },
  {
    type: "function",
    function: {
      name: "share_room",
      description:
        "Produce this room's own invite link, exactly as the Share menu does. Ownership and expiry are the server's rules, not yours.",
      parameters: {
        type: "object",
        properties: { displayName: { type: "string" } },
        additionalProperties: false,
      },
    },
  },
];

/** The names this bridge will relay — a model naming anything else is refused. */
export const ALLOWED_TOOL_NAMES = new Set(BOARD_TOOLS.map((tool) => tool.function.name));

/**
 * Tools reachable from `converse`.
 *
 * `generate` gets none, ever: its contract is bare Mermaid, and a tool call in a
 * route whose client parses the reply as a diagram is a regression.
 */
export const toolsFor = (mode) => (mode === "converse" ? BOARD_TOOLS : []);

/**
 * Refuses a client-supplied tool surface. The panel may not widen what the
 * assistant holds — the only accepted value is a subset filter, never an addition.
 */
export const narrowToAllowed = (requested) => {
  if (!Array.isArray(requested)) {
    return null;
  }
  const wanted = requested
    .map((entry) => (typeof entry === "string" ? entry : entry?.function?.name))
    .filter((name) => typeof name === "string" && ALLOWED_TOOL_NAMES.has(name));
  if (wanted.length === 0) {
    return null;
  }
  return BOARD_TOOLS.filter((tool) => wanted.includes(tool.function.name));
};
