# Theme Generation Diagram

```mermaid
flowchart TD
  A["packages/theming/create/tokens.css"] --> B["packages/theming/create/controller.ts"]
  B --> C["packages/theming/create/apps/vscode.ts"]
  B --> D["packages/theming/create/apps/opencode.ts"]
  B --> E["packages/theming/create/apps/ghostty.ts"]
  B --> F["packages/theming/create/apps/nvim.ts"]
  B --> G["packages/theming/create/apps/oh-my-zsh.ts"]

  C --> H["packages/theming/output/vscode/*"]
  D --> I["packages/theming/output/opencode/*"]
  E --> J["packages/theming/output/ghostty/*"]
  F --> K["packages/theming/output/nvim/*"]
  G --> L["packages/theming/output/oh-my-zsh/*"]

  H --> M["install copy -> packages/theming/vsce-package/themes/*"]
  I --> N["install copy -> opencode/themes/*"]
  J --> O["install copy -> ghostty/themes/*"]
  K --> P["install copy -> nvim/colors/*"]
  L --> Q["install copy -> ~/.oh-my-zsh/custom/themes/*"]

  R["bash packages/installer/install.sh --theme\n(npm run install:theme)"] --> B
```
