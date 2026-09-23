# Keeper.sh no Bazzite

O Keeper.sh roda como um Quadlet rootless usando a imagem standalone. Essa
imagem inclui web, API, cron, worker, PostgreSQL, Redis e MCP.

A imagem em uso é construída localmente, não a `ghcr.io/ridafkih/keeper-standalone:2`
publicada. Veja [Imagem local](#imagem-local).

## Instalação

Depois de aplicar os dotfiles com Dotdrop, a partir da raiz deste repositório:

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

## Imagem local

O upstream não copia o Google Meet entre calendários: `conferenceData` e
`hangoutLink` são lidos do evento de origem mas descartados na escrita, então o
espelho perde o link. O fork em `~/.local/src/keeper.sh` no bazzite carrega esses
dados no fluxo Google → Google e escreve com `conferenceDataVersion=1`.

A alteração não está no upstream. Enquanto não estiver, `podman pull` da tag
publicada **reverte o comportamento** — o `keeper.container` aponta para a tag
local justamente para que um pull de rotina não troque a imagem sem querer.

### Reconstruir

O fonte fica no bazzite, sincronizado a partir do clone de trabalho:

```bash
# do clone do keeper.sh, na máquina de desenvolvimento
rsync -az --delete \
  --exclude node_modules --exclude .git --exclude dist --exclude .next --exclude .turbo \
  ./ bazzite:~/.local/src/keeper.sh/
```

```bash
# no bazzite
cd ~/.local/src/keeper.sh
podman build -f docker/standalone/Dockerfile -t localhost/keeper-standalone:meet .
systemctl --user restart keeper.service
```

O build leva alguns minutos e compila o monorepo inteiro. As migrações rodam
sozinhas no boot (`init-db` chama `packages/database/scripts/migrate.ts`), então
não há passo manual de banco.

### Voltar para o upstream

```bash
sed -i 's|^Image=localhost/keeper-standalone:meet|Image=ghcr.io/ridafkih/keeper-standalone:2|' \
  ~/.config/containers/systemd/keeper.container
systemctl --user daemon-reload
systemctl --user restart keeper.service
```

A coluna `event_states.conference` que a migração adiciona é aditiva e fica
inerte na imagem publicada — não é preciso reverter o banco.

## Operação

```bash
systemctl --user status keeper.service
podman logs -f keeper
systemctl --user restart keeper.service
```

Backup lógico do banco antes de trocar a imagem:

```bash
mkdir -p ~/backups/keeper
podman exec keeper su postgres -c \
  "/usr/lib/postgresql/17/bin/pg_dump -d keeper -Fc" \
  > ~/backups/keeper/keeper-$(date +%Y%m%d-%H%M%S).dump
```

O diretório de dados pertence ao usuário do namespace do container e não pode
ser lido direto do host — por isso o dump lógico em vez de copiar os arquivos.

Faça backup de `~/.local/share/keeper/data` e do arquivo
`~/.config/containers/systemd/keeper.env`. O banco contém os eventos e as
contas vinculadas; a `ENCRYPTION_KEY` é necessária para descriptografar
credenciais CalDAV.
