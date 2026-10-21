## gate · 2026-10-21 — the capability gate executed its own register

### Why
`bin/gates/capabilities.sh` built its header with an **unquoted heredoc** (`cat <<EOM`). Its
body contains a ``` fence and inline-code backticks, so the backticks **paired across lines**
and bash ran the register's own text as a command substitution:

```
bin/gates/capabilities.sh: line 92: capabilities[5]surface:: command not found
bin/gates/capabilities.sh: line 93: shell doors (bin/*.sh),502: No such file or directory
```

The substitution produced nothing, so the fenced block came out **empty** in every written
register — visible as a blank gap where the header block should be — and the block the reader
actually saw was the one printed by the `printf` after the heredoc. Under CI's `bash -e` the
same wound could end the script before its verdict, reporting a CURRENT register as a failed
gate. The script's own comment at line 214 admitted it: *"Quoting the heredoc is the proper fix
and is still owed."*

### Fix
- The heredoc is now quoted (`<<'EOM'`); nothing inside expands.
- The redundant block was deleted from inside it (the `printf` owns that block).
- The escaped backticks lost their escapes, since the body is now literal.
- `bash -n` green; the register regenerates without the blank gap.

### Verified
`extension_api[2]{extensions,bad}: "17","0"`; `capabilities.sh --check` runs without the
"command not found" noise it had emitted for months.

### Owed
The register itself must be regenerated and committed — `--check` still reads STALE by 72
doors (430 on disk, 502 in the tree) and 1 skill (27 vs 28).

### Files
- `bin/gates/capabilities.sh`
