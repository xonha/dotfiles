# Lab — ambiente Arch de desenvolvimento no Bazzite

O `bazzite` executa uma única máquina rootless Podman chamada `lab`, baseada
em Arch Linux. Ela usa Bash com Starship e recebe o mesmo catálogo de pacotes
de desenvolvimento definido no repositório.

| Instância | Finalidade | SSH | Workspace | Home persistente |
|---|---|---|---|---|
| `lab` | Desenvolvimento | `2224` | `~/lab/workspace` | volume `lab-home` |

A imagem é construída de `setup/lab/Dockerfile`. O workspace é uma pasta
normal no Bazzite e o home persistente fica no volume `lab-home`. Na primeira
inicialização, o container clona `https://github.com/xonha/dotfiles.git` em
`~/Dotfiles` e executa `dotdrop install` a partir desse clone.

## Instalação e atualização

No Bazzite, após aplicar os dotfiles com Dotdrop:

```bash
cd ~/Dotfiles
dotdrop install --cfg dotdrop/config.yaml --profile omarchy
./setup/lab/setup.sh
```

O instalador cria `~/lab/workspace`, constrói a imagem, recarrega a unidade
Quadlet `lab` e habilita linger para iniciar o serviço no boot.

## Definition of Done da reprodução

Uma recriação de `lab` só está concluída quando:

- `lab.service` está ativo e `ssh lab` funciona;
- `~/Dotfiles` existe dentro do `lab` e é um clone limpo do repositório;
- `dotdrop install` foi executado a partir de `~/Dotfiles`;
- o login usa Bash;
- `config/bash.conf`, `bash_profile`, `config/tmux.conf` e `config/starship.toml` estão
  presentes no home do usuário;
- `starship` e `tmux` estão disponíveis;
- `blesh` está instalado pelo AUR (com build upstream como fallback) e uma
  sessão Bash interativa expõe `BLE_VERSION`;
- os checksums das configurações aplicadas foram comparados com o repositório.

O Foot fica fora do container: é uma configuração gráfica do host que abre a
conexão SSH. Portanto, sua validação ocorre no Omarchy/Bazzite host, não dentro
do `lab`.

## Acesso

```bash
ssh lab
podman exec -it -u henrique lab bash
```

O alias SSH encaminha a porta local `3000` para a porta `3000` dentro do
ambiente.

## Gerenciamento

```bash
systemctl --user status lab.service
systemctl --user restart lab.service
journalctl --user -u lab.service -f
```

Para recriar completamente a máquina, pare a unidade, remova o container e o
volume `lab-home`, e execute novamente `./setup/lab/setup.sh`. O diretório
`~/lab/workspace` deve ser preservado se contiver código.
