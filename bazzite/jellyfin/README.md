# Jellyfin no Bazzite

O Jellyfin roda em um Quadlet Podman rootless com a imagem oficial. Acesse
`https://bazzite.tail9319fe.ts.net:8450` pela tailnet e conclua o assistente
inicial, criando a conta de administrador. A porta local 8096 escuta apenas no
localhost. Descoberta automática e DLNA não estão configurados.

No assistente, adicione bibliotecas para `/media/movies` (filmes), `/media/tv`
(séries) e `/media/music` (música). Elas correspondem às pastas do Mediarium no
HD `/dev/sdb1` e são montadas em modo somente leitura. O serviço verifica o
mount antes de iniciar e tenta novamente caso o disco ainda não esteja montado.
O SELinux é desativado apenas neste container para preservar os rótulos do HD.
A transcodificação por GPU não está configurada; o servidor usa CPU quando
precisar transcodificar.

A configuração e o banco ficam em `~/.local/share/jellyfin/config`; faça backup
dessa pasta. O cache fica em `~/.local/share/jellyfin/cache`.

```bash
./bazzite/setup.sh jellyfin
ssh bazzite systemctl --user status jellyfin.service
ssh bazzite podman logs jellyfin
ssh bazzite podman pull ghcr.io/jellyfin/jellyfin:latest
ssh bazzite systemctl --user restart jellyfin.service
```
