# public-data — RULES/04 — a secret, a name, a topology, a mailbox or a machine named as a host is
# refused, and the ward is proved to refuse.
#
# The ward itself is in guards.sh's list above; this is the proof that it BITES (a ward never seen
# to refuse is decoration, and this one wore that coat).
gate public-data "RULES/04 — a secret, a name, a topology, a mailbox or a machine named as a host is refused, and the ward is proved to refuse" \
     bash "$ROOT/bin/gates/checks/public-data-ward.test.sh"
