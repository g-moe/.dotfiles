# Before and After

Show one focused change. Use the same structure and level of detail on both sides so the difference is clear.

```text
Before
└── Every request reads the configuration file

After
├── First request reads the file
└── Later requests use the cached value
```

Include only context that helps explain the change. Do not imply that unchanged behavior changed.
