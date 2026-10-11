# Inventories

Dated, redacted dumps from `scripts/premigration-inventory.sh`, kept so a rebuild can be diffed
against the machine as it was.

| file | meaning |
| --- | --- |
| `premigration-inventory-<date>.redacted.txt.gz` | the committed copy |
| `premigration-inventory-<date>.txt.gz` | **not here** — the full dump stays on the machine in `~/Documents/`, because this repo is published |

Regenerate with `scripts/premigration-inventory.sh`, then copy the `.redacted` file into this
directory. The script self-tests its redaction rules on every run and prints the diff workflow;
`../storage-migration.md` explains what the diff is *for*.
