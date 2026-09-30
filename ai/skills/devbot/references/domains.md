# Devbot — domínios, certificados e DNS

Pedidos típicos: "cria uma entrada de DNS para `X.com`" ou "a URL
`https://campanha-Y-prd.devbot.com.br/` precisa virar `X.com`". O trabalho
se divide em três frentes: **certificado (ACM)**, **DNS** (nosso ou do
cliente) e **CloudFront via SST**.

Nunca grave aqui account IDs, ARNs, tokens ou IDs de registros: este
repositório é público. Descubra tudo em tempo de execução com os comandos
abaixo.

## Ferramentas e acesso

| Ferramenta | Uso | Autenticação |
|---|---|---|
| `aws` | ACM (`us-east-1`), CloudFront | perfil padrão já autenticado |
| `flarectl` (`~/go/bin`) | DNS da Cloudflare | `CF_API_TOKEN` em `secrets.env` (carregado pelo bashrc) |
| DoH via `curl` | consultas DNS públicas (não há `dig` no host) | — |

- O token da Cloudflare tem escopo `Zone:Read` + `DNS:Edit` nas zonas nossas,
  com filtro de IP e expiração. Erro `9109 Cannot use the access token from
  location` significa que o IP mudou: o usuário precisa atualizar o filtro
  (IPv4 exato + prefixo IPv6 `/64`, porque o IPv6 é temporário).
- Instalação do flarectl: `go install github.com/cloudflare/cloudflare-go/cmd/flarectl@latest`
  (série v0 da lib; ele lê `CF_API_TOKEN`, não `CLOUDFLARE_API_TOKEN`).
- Rode comandos com `source ~/.bashrc; export PATH=$PATH:~/go/bin` se o
  shell não tiver carregado o token.

Consulta DNS pública:

```bash
doh() { curl -s "https://cloudflare-dns.com/dns-query?name=$1&type=$2" -H 'accept: application/dns-json' \
  | python3 -c 'import sys,json;j=json.load(sys.stdin);print([a["data"] for a in j.get("Answer",[])],[a["data"] for a in j.get("Authority",[])])'; }
doh dominio.com NS; doh dominio.com A; doh www.dominio.com CNAME; doh dominio.com CAA
```

## Fluxo

### 1. Diagnóstico (só leitura, faça sempre antes de propor algo)

1. **Onde mora o DNS do domínio alvo**: `doh <dominio> NS`.
   - `*.ns.cloudflare.com` e a zona aparece em `flarectl zone list` → é nosso, eu crio.
   - `*.akam.net` (SOA `hostmaster.<cliente>`) ou qualquer outro → é do cliente,
     vira pedido/chamado. Não temos acesso ao Akamai.
   - Sem NS / NXDOMAIN → domínio não registrado; avisar que precisa ser comprado.
2. **O que o domínio serve hoje**: `curl -sI https://<dominio>` — se houver
   redirect ou site no ar, a virada derruba isso; confirmar com quem pediu.
3. **Para onde a URL de origem aponta**: `doh campanha-Y-prd.devbot.com.br CNAME`
   → normalmente `dXXXX.cloudfront.net` (registro DNS only, sem proxy).
4. **Qual distribuição CloudFront**:
   ```bash
   aws cloudfront list-distributions --query "DistributionList.Items[?DomainName=='dXXXX.cloudfront.net'].{Id:Id,Aliases:Aliases.Items,Cert:ViewerCertificate.ACMCertificateArn,Origins:Origins.Items[].DomainName}"
   ```
   Origem `placeholder.sst.dev` → distribuição gerenciada pelo **SST**:
   não editar aliases/certificado no console ou CLI (o próximo `sst deploy`
   desfaz). A mudança vai no `sst.config.ts` do repositório da campanha.
5. **CAA**: `doh <dominio> CAA`. Se existir e não incluir `amazon.com`, o
   cliente precisa liberar antes da emissão.

### 2. Certificado ACM — padrão da casa

Sempre em `us-east-1` (exigência do CloudFront), validação DNS, sem tags:

| Campo | Valor |
|---|---|
| Domínio principal | `*.<dominio>` |
| SANs | `<dominio>`, `*.devbot.com.br`, `devbot.com.br` |

```bash
aws acm request-certificate --region us-east-1 \
  --domain-name '*.<dominio>' \
  --subject-alternative-names '<dominio>' '*.devbot.com.br' devbot.com.br \
  --validation-method DNS --output text
# aguarde alguns segundos e pegue os registros de validação
aws acm describe-certificate --region us-east-1 --certificate-arn <arn> \
  --query "Certificate.DomainValidationOptions[].[DomainName,ValidationStatus,ResourceRecord.Name,ResourceRecord.Value]" --output text
```

- Antes de pedir, veja se já existe um certificado para o domínio:
  `aws acm list-certificates --region us-east-1 --includes keyTypes=RSA_2048,EC_prime256v1`.
- `*.devbot.com.br`/`devbot.com.br` validam na hora (o CNAME de validação já
  existe na Cloudflare). `*.<dominio>` e `<dominio>` compartilham **um único**
  CNAME de validação; o wildcard cobre o `www`.
- O ACM expira pedidos não validados em **72h** — deixar isso claro no pedido.
- Pedido criado errado e ainda não usado: pode apagar com
  `aws acm delete-certificate` (confirmar com o usuário antes).

### 3a. DNS nosso (Cloudflare)

Confirme o registro com o usuário antes de criar ou alterar.

```bash
flarectl dns list --zone devbot.com.br --type CNAME | grep <nome>
# validação ACM
flarectl dns create --zone <zona> --type CNAME --name <ResourceRecord.Name sem ponto final> --content <ResourceRecord.Value sem ponto final>
# apontamento para CloudFront: DNS only (sem --proxy), igual aos registros existentes
flarectl dns create --zone <zona> --type CNAME --name <sub.dominio> --content dXXXX.cloudfront.net
```

A Cloudflare aceita CNAME no domínio raiz (CNAME flattening), então apex
também pode apontar direto para o CloudFront.

### 3b. DNS do cliente (Akamai ou outro) — pedido por chat/chamado

O usuário envia; eu só redijo. Formato que ele copia e cola:

```
Oi! Podem criar este registro DNS na zona <dominio>? É para validar o certificado SSL da campanha e não afeta o site atual.

Tipo: CNAME
CNAME Name: <ResourceRecord.Name sem ponto final>
CNAME Value: <ResourceRecord.Value sem ponto final>
TTL: 300
```

Se o painel pedir só o host, o nome é a parte antes de `.<dominio>`.

Apontamento (enviar só depois de combinada a data de virada). Destino:
`dXXXX.cloudfront.net`. Domínio raiz não aceita CNAME no Akamai, então
oferecer, em ordem de preferência:

- **A**: a propriedade Akamai do cliente faz proxy para `dXXXX.cloudfront.net`
  (origin), repassando `Host: <dominio>`, e remove o redirect atual;
- **B**: `www.<dominio>` CNAME `dXXXX.cloudfront.net` e o apex redireciona
  para `https://www.<dominio>/`.

Subdomínio (ex.: `promo.<dominio>`) é simples: CNAME direto para o CloudFront.

### 4. CloudFront via SST

Depois do certificado `ISSUED`, no repositório da campanha (pedir o caminho
se não souber), ajustar o `domain` do componente (StaticSite/Nextjs/etc.)
no stage `prd`:

```ts
domain: {
  name: "<dominio>",               // ou o devbot atual, com o novo em aliases
  aliases: ["campanha-Y-prd.devbot.com.br"],
  dns: false,                      // DNS fica na Cloudflare/cliente, não no Route53
  cert: "<arn do certificado>",
}
```

Seguir o padrão que o próprio repositório já usa para outras campanhas
antes de inventar um formato. Deploy segue o fluxo de PR do projeto.
Checar também se a aplicação tem lista de hosts permitidos, CORS ou URL
base que precise do domínio novo.

### 5. Verificação

```bash
aws acm describe-certificate --region us-east-1 --certificate-arn <arn> --query Certificate.Status
doh <dominio> CNAME; doh <dominio> A
curl -sI https://<dominio> | head -5      # espera server CloudFront / x-cache
```

## Regras

- Diagnóstico é livre; criar/alterar/apagar registro ou certificado exige
  confirmação do usuário.
- Mensagens para cliente ou chamados: eu redijo, o usuário envia.
- Não mexer em distribuições SST fora do código.
- Não copiar valores sensíveis (ARN, account ID, tokens) para este repositório.
