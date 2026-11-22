#!/usr/bin/env bash
# veil — 2026-11-22 (plan 350 B): the Veil. A done act without evidence ends unproven; every report carries an
# id the arm holder answers RECEIVED; no receipt is resent into the holder's pane and turns red past ten minutes;
# Níðhöggr runs on the clock, stamps his run, and a stopped clock is red in the trouble panel.
gate veil "evidence or no done; RECEIVED for every report; Níðhöggr on the clock" \
     bash -c 'bash "$1/bin/agents/tests/test_veil.sh" && bash "$1/bin/agents/tests/test_acclaim_evidence.sh" && bash "$1/bin/ward/tests/test_trouble_veil.sh"' _ "$ROOT"
