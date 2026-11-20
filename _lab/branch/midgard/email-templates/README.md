# Email Template Library

A collection of professional email templates for different meeting types and
occasions. Each template uses `{{placeholder}}` syntax for variable substitution.

## Folder structure

```
email-templates/
├── README.md
├── components/          # Reusable email components (header, sign-off, agenda, brief)
├── client/              # Client-facing emails (follow-up, thank you)
├── internal/            # Internal team emails (follow-up, stand-up, retro)
├── sales/               # Sales emails (discovery, demo, follow-up)
├── board/               # Board/governance emails (minutes, resolutions)
├── standup/             # Stand-up emails (daily/weekly sync)
├── workshop/            # Workshop emails (outcomes, action items)
└── archive/             # Outdated templates
```

## How to use

1. Pick a template from the appropriate folder
2. Replace `{{placeholders}}` with actual values
3. Send via `mail-send.sh draft --body /path/to/template.md`

## Template categories

| Folder | Use case | Templates |
|--------|----------|-----------|
| components/ | Reusable parts | header, signoff-request, agenda-draft, brief |
| client/ | Client-facing | followup-client-meeting |
| internal/ | Internal team | followup-team-meeting |
| sales/ | Sales calls | followup-sales-call |
| board/ | Board/governance | followup-board-meeting |
| standup/ | Daily/weekly sync | followup-standup |
| workshop/ | Workshops | followup-workshop |

## Adding new templates

1. Create a new `.md` file in the appropriate folder
2. Use `{{placeholder}}` syntax for variables
3. Include Subject line, body, and signature
4. Test with `mail-send.sh draft --body /path/to/template.md --dry-run`
EOF
echo "Created README"