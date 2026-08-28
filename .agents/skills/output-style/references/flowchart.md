# Flowchart

Show how work, data, or control moves. Use arrows for linear steps and labeled branches for decisions. End every branch at an outcome or another step.

Linear flow:

```text
User clicks Save
        ↓
Client validates the form
        ↓
API writes the record
        ↓
Client shows confirmation
```

Decision flow:

```text
Did verification pass?
├── Yes
│   └── Deliver the result
└── No
    ├── Known fix available → Apply it and test again
    └── Cause unknown        → Report the blocker
```

Keep each step short. Show only supported paths. Do not use the flowchart style for hierarchy without movement or decisions; use `tree` for that.
