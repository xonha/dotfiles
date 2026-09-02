# Dotfiles

Configuração pessoal para CachyOS/Arch, instalada com GNU Stow.

## Instalação

```bash
git clone https://github.com/henriqueluhm/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./.setup/install.sh
```

O instalador configura a base de terminal e permite escolher a instalação do
desktop Hyprland. Os ajustes específicos de hardware ficam fora do fluxo
principal.

## ThinkPad

Para habilitar wake por teclado e tampa nesta máquina:

```bash
./.setup/desktop/thinkpad_t495/wakeup.sh
```

Os IDs de hardware e o diagnóstico estão documentados em
[`.setup/README.md`](.setup/README.md).

## Devbot no Bazzite

A imagem Arch usada pelo devbot está definida apenas em
[`.setup/devbot/Dockerfile`](.setup/devbot/Dockerfile). O guia operacional
completo está em [`.setup/docs/devbot.md`](.setup/docs/devbot.md). Para
construí-la:

```bash
mkdir -p "$HOME/devbot/workspace"
podman build -t devbot:latest .setup/devbot
```

Crie o container com o workspace persistente:

```bash
podman create \
  --name devbot \
  --hostname devbot \
  --memory 14g \
  --memory-swap 14g \
  --pids-limit 4096 \
  -p 2222:22 \
  -v "$HOME/.ssh/id_ed25519.pub:/run/host_ssh_key:ro,Z" \
  -v "$HOME/devbot/workspace:/workspace:Z" \
  -w /workspace \
  devbot:latest
```

O SSH aceita somente a chave pública montada acima; não há senha fixa na
imagem. Depois de iniciar o container, acesse com `ssh -p 2222 henrique@HOST`.

O container preserva sua camada gravável enquanto não for removido. Código e
outros dados importantes devem permanecer no volume `/workspace`.
