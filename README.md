# Dotfiles

Configuração pessoal para Arch, instalada com Dotdrop. O instalador detecta
o Omarchy e preserva os componentes que ele administra (shell, Foot, navegador
e gerenciador de arquivos). As configurações de usuário do Hyprland são
versionadas neste repositório e aplicadas após os padrões do Omarchy.

## Instalação

```bash
git clone https://github.com/henriqueluhm/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./setup/omarchy-setup.sh
```

O instalador configura a base de terminal e permite escolher a instalação do
desktop. O Omarchy já fornece `yay`, então o bootstrap desse helper não é
executado no host. No Omarchy, o perfil legado do Kitty
não é aplicado; os componentes correspondentes ficam fora do manifesto do Dotdrop.
Os ajustes específicos de hardware ficam fora do fluxo principal.

## ThinkPad

Wake por teclado e tampa via udev rules — diagnóstico e configuração manual
documentados em [`setup/README.md`](setup/README.md).

## Ambientes de desenvolvimento no Bazzite

`lab` usa uma imagem Arch focada em desenvolvimento no Bazzite. Depois
de aplicar os dotfiles com Dotdrop, execute:

```bash
./bazzite/lab/setup.sh
```

O guia operacional está em [`bazzite/lab/README.md`](bazzite/lab/README.md).

## Keeper.sh

O Keeper.sh roda no Bazzite como serviço Quadlet rootless, na porta local
`8088`. O guia operacional está em [`bazzite/keeper/README.md`](bazzite/keeper/README.md).

## Immich

O Immich roda no Bazzite com Podman Compose, biblioteca no HD separado e
acesso LAN/Tailscale/Funnel. O guia operacional está em
[`bazzite/immich/README.md`](bazzite/immich/README.md).
