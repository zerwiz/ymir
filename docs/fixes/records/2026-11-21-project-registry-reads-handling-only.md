# The project registry reads `handling:` only, and tolerates string lists

## What was wrong

The judge returned NEEDS-REWORK on PR 876 with two faults in `bin/records/project_registry.py`.

1. `get_field` fell back to the row's top-level `delivery:` and `board:`. So `project.sh <id> --field delivery` printed an old shipper switch with exit code 0, when the handling block carried no answer.
2. `brief()` assumed every list item was a dict. A schema-valid list of strings, such as `keepers: {value: ["alpha"]}`, crashed `--page` with `AttributeError`.

## What changed

- `get_field` walks the `handling:` block only. An absent field exits 1 with `no field '<name>' (handling: does not carry it)`.
- `brief()` turns bare strings in a list into cells, so no list shape crashes a page.
- `tests/test_project_registry_reads.sh` covers both: no leak from the top-level keys, exit 1 with a named message, and `--page` on string lists.
