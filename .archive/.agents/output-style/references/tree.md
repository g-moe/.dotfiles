# Tree

Use Unicode tree characters to show hierarchy. Use `├──` for an item with a sibling below it and `└──` for the last item. Continue each active parent line with `│`.

Files:

```text
output-style/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── references/
    ├── anatomy.md
    ├── before-after.md
    ├── box.md
    ├── flowchart.md
    ├── input-output.md
    ├── section-divider.md
    └── tree.md
```

Relationships:

```text
Application
├── Interface
│   ├── Header
│   └── Content
└── Services
    ├── Authentication
    └── Storage
```

Keep labels short. Preserve the correct parent and child relationships. Do not add branches that are not present in the content.
