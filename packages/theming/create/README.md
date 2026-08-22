# Theme Generation Diagram

```mermaid
flowchart TD
  A["packages/theming/create/tokens.css"] --> B["packages/theming/create/controller.ts"]
  B --> C["packages/theming/create/apps/vscode.ts"]
  B --> D["packages/theming/create/apps/opencode.ts"]
  B --> E["packages/theming/create/apps/ghostty.ts"]
  B --> F["packages/theming/create/apps/superfile.ts"]
  B --> G["packages/theming/create/apps/nvim.ts"]
  B --> H["packages/theming/create/apps/oh-my-zsh.ts"]

  C --> I["packages/theming/output/vscode/*"]
  D --> J["packages/theming/output/opencode/*"]
  E --> K["packages/theming/output/ghostty/*"]
  F --> L["packages/theming/output/superfile/*"]
  G --> M["packages/theming/output/nvim/*"]
  H --> N["packages/theming/output/oh-my-zsh/*"]

  I --> O["install copy -> packages/theming/vsce-package/themes/*"]
  J --> P["install copy -> opencode/themes/*"]
  K --> Q["install copy -> ghostty/themes/*"]
  L --> R["install copy -> superfile/theme/*"]
  M --> S["install copy -> nvim/colors/*"]
  N --> T["install copy -> ~/.oh-my-zsh/custom/themes/*"]

  U["bash packages/installer/install.sh --theme\n(npm run install:theme)"] --> B
```

The Zsh prompt reads the saved machine color from `~/.dotfiles/machine.json`.
The machine-name block uses white text on black and black text on every other
supported color.
