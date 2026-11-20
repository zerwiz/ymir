# 41 — The hand on a shared system

**Appended 2026-11-01**, after a fault with no excuse.

## What happened (2026-11-01, recorded plainly)

A shared system reported fewer objects than the operator's project registry held. An agent compared the
two, concluded twenty were "missing", and **created twenty-one objects inside that system on its own
inference** — including objects owned by other parties. None of them belonged there. All twenty-one were
removed the same hour and the system was verified back to its original state.

The names of the system, the operator and the objects are deliberately not written here: this rule is
shipped to every Ymir user, and most of them have neither that system nor that registry. What must travel
is the mechanism and the lock, not the incident's private detail.

## Why it was possible — four failures, in order

1. **The registry carried no owner.** `workspace:` and `company:` are empty on all twenty-five projects.
   Nothing anywhere said *which company a project belongs to*, so "our projects" was read as "the
   company's projects".
2. **A read-only observation was treated as an instruction to write.** "The board is missing its
   projects" is a report. It is not a licence to populate a workspace — and the direction was not even
   from the Allfather alone: it named a *symptom*.
3. **Nothing in the house guards a write to an outside system.** The wards guard commits, the vault,
   the places and the ports. An API call to Plane, Trello, Gmail or Drive is a write into a system other
   people use, and it had no guard at all — the only thing between an inference and a client's workspace
   was the agent's judgement.
4. **The agent inferred authority from a capability.** It could create projects, so it did.

## The law

```
shared_system_law[6]{rule}:
  "A NAME IS NOT A LICENCE","a place, board, workspace, channel, repo or mailbox that other people use is a SHARED SYSTEM. Seeing that something is missing is a REPORT, never an instruction to create it."
  "THE OWNER COMES FROM THE REGISTRY, NEVER FROM INFERENCE","no object is created in a shared system unless the project registry names its workspace AND its owning company. An empty field is a refusal."
  "CREATES NEED HIS WORD, NAMING THEM","a create, a move, or a delete in a shared system needs the Allfather's explicit instruction that names the thing and the place."
  "ONE DOOR","every write to Plane, Trello, Gmail, Drive or a similar system goes through a door in bin/boards/ or bin/mail/ that enforces the two rules above. An ad-hoc curl is the fault."
  "REVERSIBLE FIRST","when the shape is uncertain, create nothing; propose the map and wait. A deletion is not a rollback if a person already touched the object."
  "SAY THE FAULT PLAINLY","a wrong write is reported in full — what was created, where, and how it was undone — never softened into 'a sync issue'."
```

**Why it is law and not preference:** a wrong board in a client's workspace is visible to the client. The
record of this house is that its faults are found by its own wards; an unwarded door is the one place
where that stops being true.
