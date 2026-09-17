# Keeper.sh no Bazzite

O Keeper.sh roda como um Quadlet rootless usando a imagem standalone. Essa
imagem inclui web, API, cron, worker, PostgreSQL, Redis e MCP.

## Instalação

Depois de aplicar os dotfiles com Stow, a partir da raiz deste repositório:

```bash
mkdir -p ~/.config/containers/systemd ~/.local/share/keeper/data
cp .setup/keeper/keeper.env.example \
  ~/.config/containers/systemd/keeper.env
chmod 600 ~/.config/containers/systemd/keeper.env

sed -i \
  -e "s/^BETTER_AUTH_SECRET=.*/BETTER_AUTH_SECRET=$(openssl rand -base64 32)/" \
  -e "s/^ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$(openssl rand -base64 32)/" \
  ~/.config/containers/systemd/keeper.env

systemctl --user daemon-reload
systemctl --user enable --now keeper.service
```

Abra `https://bazzite.tail9319fe.ts.net:8444` a partir de outro computador
conectado ao Tailscale.

O serviço escuta somente em loopback e o Tailscale Serve fornece HTTPS apenas
para o tailnet. Para Google/Outlook, configure as credenciais OAuth próprias.
`WEBHOOK_PUBLIC_URL` só deve ser configurada quando existir uma URL HTTPS
pública alcançável pelos provedores.

## Operação

```bash
systemctl --user status keeper.service
podman logs -f keeper
podman pull ghcr.io/ridafkih/keeper-standalone:2
systemctl --user restart keeper.service
```

Faça backup de `~/.local/share/keeper/data` e do arquivo
`~/.config/containers/systemd/keeper.env`. O banco contém os eventos e as
contas vinculadas; a `ENCRYPTION_KEY` é necessária para descriptografar
credenciais CalDAV.
