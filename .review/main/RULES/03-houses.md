# Rule 03 — Houses (companies)

**Status:** law. Read with Rule 01 (domains · houses · Eindri).

## 1. A house is a company — nothing else

A **house** is a **company**. The two words are the same thing; use them
interchangeably. **WayOf is a house (a company).**

A house is **not** a domain (Rule 01), **not** a workspace, and **not** a
subsystem. The eight “Labs” — Ymir Labs, Brokk Forge, Runestone Labs, Muninn
Labs, Dvalin, Utgard Studios, Askr, Mannheim — are **domains**, never houses.

## 2. What a house owns

- A house **owns projects**. Every project belongs to exactly **one** house and
  may span many **domains** (Rule 01).
- A house has **members**, each with a role: `owner` · `admin` · `member`.
- A house has **products** and a **repo** (a single master registry entry,
  `workspace/projects.yaml`).

## 3. The house record

Each house has one entity card:

```
companies/<house>/entity.md
  name        the company name (the house)        e.g. WayOf
  type        company | personal
  owner       the owning operator                 e.g. zerwiz
  realm       the scope it runs in
  domains     the fields it works across          (Rule 01 ids)
  products    what it ships
  repo        git remote or local path
  status      active | holding | paused | retired
  lore_line   the one line that names the venture
```

The card lives inside the company container (`svartalfaheim/<company>/`), which
becomes the company's Docker boundary. A work workspace mounts that container.

## 4. Naming and boundaries

- A house is named for the **company** (WayOf). Never name a house after a
  domain, a subsystem, or a person.
- **House boundaries are sacred.** A house's data never reaches across to
  another house without explicit Allfather approval.
- Single tenant today: the **Allfather** owns the house (WayOf); the eight
  domains are how its knowledge is divided, not extra companies.

## 5. Do not conflate

```
house   = company            (WayOf)
domain  = field of knowledge, a Grein (the eight Labs)
workspace = a running scope  (personal | work)
brand   = a domain's label   (Ymir Labs, Brokk Forge, …)
```

Anything that treats a domain as a house, or a house as a domain, is a
violation and must be corrected here first.
