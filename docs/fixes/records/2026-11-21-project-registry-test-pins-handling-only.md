# The registry test pins handling-only reads

The earlier registry test asserted that a top-level row key such as `name` answers `project.sh <id> --field name` when `handling:` lacks it. That was the fallback the judge refused on PR 876. The test now asserts the opposite: the read exits 1 and the row's top-level value never answers.
