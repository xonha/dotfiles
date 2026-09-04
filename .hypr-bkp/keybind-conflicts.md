# Conflitos de atalhos: padrão Omarchy vs binds.lua (backup)

Atalhos que já tinham uma função no `binds.lua` antigo e que colidem com um
atalho padrão do Omarchy (ambos os lados atribuídos, ações diferentes).
Atalhos onde o padrão Omarchy estava livre (sem conflito real) foram
excluídos desta lista.

## Aplicativos

- [ ] **SUPER+G** — Toggle window grouping (Omarchy) vs Arquivos (backup)
- [ ] **SUPER+W** — Fechar janela (Omarchy) vs WhatsApp (backup)
- [ ] **SUPER+S** — Toggle scratchpad (Omarchy) vs Devbot (backup)
- [ ] **SUPER+X** — Universal cut (Omarchy) vs Devbot SSH, workspace vazio (backup)
- [ ] **SUPER+C** — Universal copy (Omarchy) vs Mais Todos SSH, workspace vazio (backup) - mover universal copy do omarchy para SUPER+SHIFT+C
- [ ] **SUPER+V** — Universal paste (Omarchy) vs Terminal, workspace vazio (backup) - Mover universal paste para super+shift+v
-[ ] **SUPER+F** — Full screen (Omarchy) vs Brave, workspace 1 (backup)

## Sistema / Noctalia

- [ ] **SUPER+Backspace** — Toggle window transparency (Omarchy) vs Menu de sessão (backup)
- [x] **SUPER+Space** — Omarchy menu (Omarchy) vs Abrir launcher (backup)
- [ ] **SUPER+P** — Pseudo window (Omarchy) vs Selecionar cor da tela (backup)
- [ ] **SUPER+T** — Toggle window floating/tiling (Omarchy) vs Ativar/silenciar microfone (backup)
- [x] **SUPER+J** — Toggle window split (Omarchy) vs Mostrar atalhos, cheatsheet (backup)
- [x] **SUPER+O** — Pop window out, float & pin (Omarchy) vs GitHub Pull Requests (backup)
- [ ] **SUPER+SHIFT+M** — Music, Spotify (Omarchy) vs Reativar tela interna, recuperação (backup)
- [x] **SUPER+K** — Keybindings (Omarchy) vs Notas (backup)

## Janelas

- [ ] **SUPER+SHIFT+B** — Browser (Omarchy) vs Alternar flutuante + centralizar (backup)
- [ ] **SUPER+SHIFT+Return** — Browser (Omarchy) vs Alternar tela cheia (backup)
- [ ] **SUPER+L** — Toggle workspace layout (Omarchy) vs Focar à direita (backup)

Para reaproveitar o esquema antigo nessas teclas, use `hl.unbind(...)` antes
do `o.bind(...)` correspondente em `~/.config/hypr/bindings.lua`.
