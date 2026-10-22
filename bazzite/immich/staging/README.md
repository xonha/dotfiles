# Immich staging no Bazzite

Este Compose usa containers, porta, PostgreSQL e mídia separados da produção.
Nunca use o `UPLOAD_LOCATION` ou `DB_DATA_LOCATION` do `~/immich/.env` aqui.

Diretório operacional previsto: `/var/home/henrique/immich-staging`. A mídia
deve ser uma cópia COW em `/var/home/henrique/immich-staging/media`, criada a
partir do backup em `/var/home/henrique/immich-backups/pre-fork-2026-10-21/media`.
O PostgreSQL de staging deve ter seu próprio diretório sob `immich-staging/`.
A porta `2284` fica vinculada somente a `127.0.0.1`; não configure Funnel.
Servidor, banco e Redis usam uma rede interna sem saída para a Internet. O
container de ML tem uma segunda rede para poder baixar modelos, mas não
publica portas.

O `.env` de staging não é versionado. Ele precisa definir `UPLOAD_LOCATION`,
`DB_DATA_LOCATION`, `DB_USERNAME`, `DB_DATABASE_NAME` e `DB_PASSWORD`. A URL de
ML deve apontar para `http://immich-machine-learning:3003`. Use senha nova no
staging e não copie o `.env` de produção. Imagem padrão: release oficial
`v3.3.1`; `IMMICH_SERVER_IMAGE` pode selecionar uma imagem local do fork após
os testes de compatibilidade.

O script `prepare.sh` cria o `.env` com senha aleatória e recusa sobrescrever
um ambiente já preparado. Ele recusa usar a mídia da produção ou o backup
diretamente; não inicia containers nem altera a produção.
Para ambientes preparados antes da separação entre backup e mídia gravável,
`use_media_clone.sh` altera somente o caminho da mídia no `.env` após validar
que a cópia COW existe.

Sequência segura:

1. Validar a cópia da mídia (contagem, tamanho e `rsync --checksum --dry-run`).
2. Restaurar o dump do banco em um PostgreSQL novo de staging e comparar as
   contagens de `asset`/`user` com o dump.
3. Subir a release oficial em staging e verificar HTTP, logs e biblioteca.
4. Construir a imagem do fork e testá-la somente em staging. Conferir migrações,
   buscas, stacks, job e rollback para a imagem oficial no clone.
5. Antes de qualquer mudança em produção, atualizar a cópia com os uploads
   recentes, criar um novo dump do banco e testar sua restauração.

Não execute `podman compose down -v` e não use a cópia de staging como único
backup. Uma imagem anterior do servidor não reverte migrações de banco; o
rollback real exige restaurar também o dump pré-corte.

## Teste paralelo da release v3.3.4

`prepare_release_test.sh` prepara `/var/home/henrique/immich-staging-v334` com
uma segunda cópia COW do backup pré-fork, banco e senha próprios. O Compose
versionado aceita nomes de containers e porta por variáveis; sem elas,
os valores do staging original permanecem iguais. Inicie o Compose paralelo
com `podman compose -p immich-staging-v334` para dar a ele um projeto próprio;
o `podman-compose` deste host não expande variáveis no campo `name`. A instância paralela usa
`127.0.0.1:2285`, sem Serve/Funnel. Restaure o dump no PostgreSQL novo antes de
subir o servidor oficial v3.3.4, e só depois teste a imagem do fork nessa
instância. Não use o banco do staging baseado na linha de desenvolvimento como
entrada para v3.3.4: downgrade de migrações não é um rollback seguro.

Com o checkout local do fork v3.3.4 como diretório atual, a imagem pode ser
construída no notebook e enviada ao Bazzite sem passar por registry:

```bash
podman build --layers -f server/Dockerfile -t localhost/immich-best-pick:v3.3.4-auto-stack .
podman save localhost/immich-best-pick:v3.3.4-auto-stack | ssh bazzite podman load
```

Sequência no Bazzite, sempre com `-p immich-staging-v334` em
`/var/home/henrique/immich-staging-v334`:

1. Restaurar o dump no PostgreSQL já criado (`immich_staging_v334_postgres`)
   com `pg_restore -U postgres -d immich --no-owner --no-acl --clean --if-exists`
   e conferir as contagens de assets, usuários e stacks contra o dump.
2. Subir a v3.3.4 oficial e verificar `http://127.0.0.1:2285` e os logs de
   migração.
3. Trocar `IMMICH_SERVER_IMAGE` no `.env` dessa instância pela imagem do fork,
   recriar só o `immich-server` e verificar a migração
   `1792600000000-AddAutomaticStackFlag` e `No schema drift detected`.
