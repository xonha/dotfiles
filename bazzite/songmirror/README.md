# SongMirror no Bazzite

O SongMirror roda como um Quadlet rootless usando a imagem publicada no GHCR.
Contas, tokens, cache, histórico e backups de playlists ficam em
`~/.local/share/songmirror/data`.

A interface não tem login. O container publica a porta `8888` somente em
`127.0.0.1`, e o setup configura o Tailscale Serve em HTTPS na porta `8447`.
Abra `https://bazzite.tail9319fe.ts.net:8447` em um dispositivo conectado ao
tailnet. A interface não deve ser publicada na internet.

## Instalação

De um cliente com este repositório e SSH para o host:

```bash
./bazzite/setup.sh songmirror
```

Não é necessário `.env`: conecte Spotify e YouTube Music na página Accounts do
SongMirror e siga as instruções de autenticação exibidas para cada serviço.

## Operação

```bash
systemctl --user status songmirror.service
podman logs -f songmirror
systemctl --user restart songmirror.service
tailscale serve status
```

Faça backup de `~/.local/share/songmirror/data` para preservar credenciais,
cache de correspondências, arquivo de músicas e snapshots agendados. Para
atualizar a imagem publicada:

```bash
podman pull ghcr.io/ahnafnafee/songmirror:latest
systemctl --user restart songmirror.service
```
