# Rule 21 — Company documents are written in business language

> Adopted 2026-10-13: *"are the wording business? we need to create a rule around company
> documents to have business wording."*

A document that leaves the company — to a client, a partner, a teammate, a supplier or a
regulator — is a **business document**. It is read by people who do not work here, do not know
our internal names, and will judge the company by how it writes. So the language of a company
document is **plain professional English**, and nothing internal appears in it.

## The law

```
company_doc_law[6]{rule}:
  "A company document is written in plain business English — no internal register"
  "No internal names: not a system, a component, a subsystem, an agent, a hall, a rune, a rule number"
  "No persona and no allegory: the writer is the company, not a character; a thing is described by what it does"
  "No infrastructure detail: no hostnames, ports, container names, file paths, IP addresses or account identifiers"
  "No third party the reader has no business knowing: another product, project or company is 'another product', or it is named only if it is genuinely part of the subject"
  "A document that cannot be written without internal terms is an INTERNAL document — mark it so and keep it in"
```

## What counts as a company document

Anything a person outside the immediate build sees: proposals · decision papers · comparisons ·
cost breakdowns · contracts and NDAs · onboarding notes · instructions for users · shared
READMEs · emails that carry a decision.

**Not** company documents, and therefore out of this rule's reach: build plans, operational
runbooks, incident notes, and internal design records — **provided** they are marked internal
and stay in the company's own document store.

## The test, applied before sending

```
send_check[7]{question,if the answer is no}
  "Would a new colleague understand every sentence without insider knowledge?"  "rewrite it"
  "Does any word here name a system, an agent or a component of ours?"           "describe what it does instead"
  "Does any word here come from our own stories or naming?"                     "use the plain term"
  "Is there a hostname, a port, a path or an account id?"                       "remove it — the reader does not need it"
  "Does it name another product, project or company that is not the subject?"   "say 'another product', or delete the sentence"
  "Is every claim either a fact, a figure or a stated opinion?"                 "make it one of the three"
  "Would we be comfortable if the reader forwarded it?"                          "do not send it yet"
```

## Wording: preferred forms

| Instead of | Write |
|---|---|
| a rune, a ledger entry | an audit log entry |
| the hall, the forge | the workspace, the code platform |
| the fleet, the mesh | the servers, the network |
| our agent / the assistant's name | the AI assistant, by name if it is the subject |
| a rule number | the requirement, stated in words |
| "it endures", "it survives the fire" | what it does: "kept on the company's own server" |
| an internal product name | the product's public name, or "another product" |

## Why this is a rule and not a preference

1. **A reader judges the company by the document.** Internal shorthand reads as secrecy or
   carelessness, and both cost credibility.
2. **Internal names are unnecessary disclosure.** A system name and a port number describe our
   estate to anyone who receives the file; a business document needs neither.
3. **It makes the document reusable.** Plain wording survives a change of tool, supplier or
   audience; internal wording must be rewritten each time.
4. **It protects the boundaries.** What is written in the internal register belongs to internal
   material — and a company document that borrows it blurs the line the boundaries exist to keep.

## Applying it

- **Before sending:** run the send check above. If any answer is no, fix it or mark the document
  internal and do not send it.
- **When drafting:** write for the reader — a colleague who has never seen our systems.
- **When revising:** the fix is almost always *shorter*. Internal shorthand is long; plain
  wording is short.
