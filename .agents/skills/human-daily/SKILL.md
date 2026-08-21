---
name: human-daily
description: Escreve a daily async no formato do Slack do time (Ontem / Hoje / Bloqueios), em tom humano, levantando os fatos do git, do Jira e dos PRs em vez da memoria. Use quando o usuario pedir a daily, o report do dia, o async standup ou "o que eu fiz ontem" pra postar no canal.
---

# Human Daily

Skill pra escrever a **daily async** que vai pro canal do Slack do time.

O trabalho aqui não é redigir bonito — é **relatar com precisão de estado**. O texto vai
para pessoas que planejam sprint com ele. Report otimista atrasa gente.

## Quando usar

- "Escreve a daily", "monta meu report do dia", "async standup".
- "O que eu fiz ontem?" com intenção de postar.
- Depois de um dia de trabalho pesado, pra consolidar o que virou entrega.

## Formato (é o do canal, não invente outro)

```
Ontem:
- item
- item

Hoje:
- item
- item

Bloqueios:
- item        (ou: N/A)
```

Regras de forma, todas aprendidas de correção real no texto postado:

- **Texto puro. Sem markdown.** Nada de `**negrito**`, nada de tabela, nada de
  `[link](url)`. O canal renderiza pouco e o negrito no meio de bullet técnico vira ruído.
- **Card é texto puro:** `CNT-3319 — o quê`. Sem link. Quem quer abrir, cola o ID.
- **Português normal, com acentos.** (Diferente da `human-review`, que é sem acento
  porque vai pra comentário de PR.)
- Primeira pessoa no **Ontem** (`fechei`, `achei`, `emendei`, `abri`), **infinitivo** no
  **Hoje** (`Registrar`, `Seguir`, `Levar`).
- **Travessão só pra separar o card do fato:** `CNT-3325 — achei em homolog...`. **Dentro
  da frase, vírgula.** Travessão como parêntese no meio do bullet (*"todo code diferente
  de 01 — que é justamente o que essa pessoa recebe"*) foi trocado por vírgula em **todos**
  os bullets na revisão de 14/08. Uma pontuação forte por bullet, e ela é a do card.
- 🔴 **Duas frases por bullet, no máximo.** Medido na revisão de 14/08: os quatro bullets
  do Ontem que sobreviveram tinham 1 ou 2 frases; **em cada bullet que eu escrevi com três,
  a terceira foi cortada.** A terceira frase é sempre onde entra o mecanismo, a ressalva
  redundante ou a enumeração — nenhum dos três pertence ao canal.
- **Entrega sem wrap manual.** O Slack reflui sozinho; texto pré-quebrado em 80 colunas
  vira quebra no meio da frase quando colado. Uma linha por bullet, por longa que seja.

## A regra que mais importa: precisão de estado

**Três estados diferentes, e colapsar eles num "fechei" é o erro mais caro desta skill:**

| Estado | O que significa | Como escrever |
|---|---|---|
| **desenho fechado** | sei o que fazer, ninguém validou | *"fechei o **desenho** de X"* — e **para aí**, ver abaixo |
| **decisão ratificada** | quem responde pelo assunto concordou | *"ratificado com o time/fornecedor: X"* |
| **entrega feita** | existe código rodando e provado | *"X em PR, provado em CI/homolog"* |

⚠️ **Incidente real que gerou esta regra** (12/08/2026): a daily saiu com
*"fechei a integração com a CAF/Certta"*. Não havia **uma linha** de cliente CAF escrita,
os dois cards de entrega nem existiam, e as duas decisões eram provisórias, pendentes de
confirmação do fornecedor. Quem leu entendeu que a fase tinha destravado. **A correção que
ficou como padrão:** *"fechei o desenho da integração (decisões provisórias)"*.

Palavras que exigem conferência antes de usar: **fechei · finalizei · resolvido ·
entregue · pronto · destravado**. Se o passo seguinte depende de outra pessoa
responder algo, não é nenhuma delas.

### O estado mora no verbo, não numa frase extra

✏️ **Refinado em 14/08.** Eu escrevi *"Fechei o desenho das 12 pendências do CNT-3319, o
que fazemos conforme cada resposta, decidido antes de perguntar. **São decisões
provisórias, pendentes de ratificação de Prevenção a Fraudes e de confirmação da
Certta.**"* — e a segunda frase foi cortada.

**Ela estava certa e era redundante.** *"Fechei o desenho"* **já** diz que ninguém
ratificou; é exatamente por isso que a coluna da tabela acima usa essa formulação.
Anexar a explicação do que "desenho" significa é escrever a nota de rodapé da própria
escolha de palavra.

**Regra:** escolha a formulação certa da tabela e **pare ali**. Se sentir necessidade de
adicionar *"pendente de X"* logo depois, o problema é que o verbo escolhido foi forte
demais — corrija o verbo, não some uma ressalva.

## Ontem: fato com consequência, não lista de atividade

Cada bullet responde **o que mudou por causa disso**. Duas formas do mesmo item:

- ❌ *"Investiguei a documentação da CAF e fiz anotações."*
- ✅ *"Descobri que não existe verificação 1:1 server-to-server na CAF — toda comparação
  roda dentro do SDK —, então a forma escolhida é SDK web em WebView."*

O que faz um bullet valer o espaço dele:

- **número medido**, não impressão: *"267 erros → zero"*, *"6 respondidas, 8 parciais,
  5 não cobertas"*, *"achados abertos: 16 → 9"*.
- **onde foi provado**: *"provado em postgres local"*, *"passou no CI"*, *"verificado em
  homolog"*. Sem isso, o time não sabe se acredita.
- **o risco em uma frase, quando o achado é de segurança**: *"o rosto de uma pessoa
  autentica a conta da outra, numa rota de reset de senha"* — é o que faz alguém agir.
- **erro próprio entra igual.** Achado que contradiz decisão anterior, premissa refutada,
  exagero corrigido. Vira credibilidade, não fraqueza. **Mas só o fato e a consequência** —
  *"Erro meu corrigido: o PF-BNK-004 pede liveness real, não PAD certificado, então deixa
  de bloquear a Fase 1"*. O **porquê** do erro (*"a exigência de ISO 30107-3 era barra que
  este refinamento adicionou"*) foi cortado em 14/08: é autópsia, e ela vive no doc.

### Relate o problema e a consequência, não o mecanismo da correção

✏️ **Aprendido em 14/08, no bullet mais importante do dia.** O que sobreviveu:

> *"Achei uma contradição no desenho da CAF: os documentos prometiam que o RG/CNH cobre
> quem não está em Senatran/TSE, mas o fail-closed recusava todo code diferente de 01, que
> é justamente o que essa pessoa recebe. Titular legítimo com CNH válida seria recusado em
> toda tentativa num reset de senha."*

O que foi cortado: *"É o achado 133, aberto e fechado no mesmo dia, separando ausência de
erro e de discordância."*

**O corte não foi do número do achado** — `achado 68` e `achado 72` ficaram em outros
bullets, porque lá eles eram a **referência rastreável** de algo que o time acompanha. O
corte foi da **narração de como consertei**: a taxonomia da solução (*"separando ausência
de erro e de discordância"*) e o placar (*"aberto e fechado no mesmo dia"*).

**Regra:** o bullet entrega **o que estava errado** e **quem se machuca com isso**. Como
foi resolvido está no doc e no card — quem precisa, abre. Citar o ID do achado só quando
ele é a chave de rastreio que alguém vai usar, não como assinatura do trabalho.

## Hoje: o que o time pode cobrar até amanhã

Intenção verbal no infinitivo, e **só o que interessa a alguém além de você**.

Fora: trabalho mecânico interno (rodar lint, publicar doc em branch, ajustar CI local).
Faz parte do dia, não do report — e cada bullet a mais custa atenção dos outros.

Dentro: o que destrava alguém, o que precisa de resposta de terceiro, o que tem relógio.

## Bloqueios: o que trava o MEU trabalho hoje

🔴 **A regra mais violada desta skill, e o erro mais fácil de cometer sendo agente:
risco de projeto sem dono NÃO é bloqueio da daily.**

**Incidente de 14/08.** Entreguei quatro bloqueios, todos reais e todos verificados:

```
- Trabalho de app sem card e sem dono — pré-requisito das 3 rotas, 46 dias até 29/09
- CNT-3158, base compartilhada de ECS, em Backlog sem responsável
- Credencial de sandbox da Certta não existe
- Documentoscopia pode estar fora do escopo do contrato
```

**Os quatro foram cortados. O que foi postado no lugar:** `PRs com review pendente`.

**Por que os meus estavam errados.** Nenhum dos quatro impedia o trabalho de andar
naquele dia — eram **riscos que travam a fase**, com prazo em setembro. Isso é conteúdo de
refinamento, de card e de conversa com coordenação. Na daily, ocupavam o lugar da única
coisa que estava de fato parando o dia dele.

| Isto | Vai para |
|---|---|
| PR meu aguardando review · ambiente caído · credencial que pedi e não veio · resposta que preciso hoje | **Bloqueios** |
| Item sem dono com prazo em semanas · dependência de outro time ainda não cobrada · premissa não confirmada | **card, refinamento, ou Ontem como achado** |
| Coisa que depende de mim | **Hoje** |

**Teste antes de escrever cada bloqueio:** *se isso se resolvesse nas próximas 2 horas, eu
faria algo diferente hoje?* Se não, não é bloqueio da daily.

- **Uma linha, não parágrafo.** Se precisa de contexto longo, o lugar é a thread ou o card.
- Quando tem data, ela entra: *"Doc do 1:1 da Bankly — corte em 25/08"*.
- **Sem bloqueio, escreve `N/A`.** É o padrão do canal, e some com a tentação de
  inventar bloqueio pra parecer ocupado.
- **O mesmo item pode aparecer em Hoje e em Bloqueios** quando você consegue empurrar mas
  não resolver sozinho — foi o que ele fez com os PRs: *"Ajudar a destravar os PRs com
  review pendente"* no Hoje, *"PRs com review pendente"* no Bloqueio. Não é redundância,
  são coisas diferentes: a ação dele e a espera por outros.

## O que NÃO entra

- 🔴 **Nome de pessoa.** Lista a pendência, não quem deve. *"duas pendências sem dono:
  o contrato comercial e o card de app"* — não *"esperando o fulano"*. Regra explícita
  do usuário: cobrança nominal em canal público é ruído, e o dono muda.
- Adjetivo de esforço: *"trabalhei bastante"*, *"dia intenso"*, *"complexo"*.
- Preâmbulo e despedida. *"Bom dia gente,"* no topo é do canal, e é a única cortesia.
- Detalhe que só faz sentido pra quem está dentro do teu terminal.

## Processo

1. **Levanta os fatos, não confia na memória.** A daily é sobre ontem, e ontem tem
   registro. **Os três comandos, sempre — nenhum é opcional:**
   ```bash
   git log --format="%ad %h %s" --date=short --since="3 days ago" --author="$(git config user.name)" --all
   gh pr list --author @me --state all --limit 10          # e os que estou revisando
   gh pr status
   jira issue list --assignee @me --plain --columns key,status,summary
   ```
   Em repo de documentação, o `git log` é literalmente o diário — cada commit tem o
   porquê na mensagem. Use `--date=short`: **a data decide se o item vai em Ontem ou em
   Hoje**, e sessão longa atravessa a meia-noite.

   🔴 **`gh pr status` é o comando que eu pulei em 14/08, e foi a falha de processo do dia.**
   Rodei `git log` e `jira issue list`, montei quatro bloqueios de risco de projeto — e o
   bloqueio real, `PRs com review pendente`, ele teve que escrever sozinho. **PR aguardando
   review é o bloqueio mais comum da carreira dele e não aparece nem no git log nem no
   Jira.** Se o único lugar onde um fato existe é o GitHub, e eu não olhei o GitHub, o fato
   não entra no report.
2. **Confere o estado real no Jira** dos cards que vai citar (`jira issue view`): status
   e o que de fato foi comentado lá. Não escreva "registrado no Jira" sem olhar.
3. **Classifica cada item nos três estados** (desenho / ratificado / entregue) **antes**
   de escrever o bullet. É aqui que o exagero morre.
4. **Escreve as três seções** no formato do canal.
5. **Mostra pro usuário e espera o ok.** Nunca posta sozinho — a daily sai no nome dele.
6. Se o usuário editar o texto antes de postar, **lê a edição como spec**: o que ele
   cortou é o que não pertence, e isso volta pra esta skill como regra.

## Checklist antes de entregar

- [ ] Zero markdown, zero link, card como texto puro.
- [ ] Zero nome de pessoa.
- [ ] Nenhum "fechei/pronto/resolvido" que na verdade seja desenho ou decisão provisória.
- [ ] **Nenhuma frase que explique o que o verbo de estado já disse** ("fechei o desenho…
      são decisões provisórias" = redundante).
- [ ] **Nenhum bullet com três frases.** Se tem, a terceira sai.
- [ ] **Travessão só na separação do card.** Dentro da frase, vírgula.
- [ ] **Rodei `gh pr status`?** Se não, os Bloqueios estão incompletos por construção.
- [ ] **Cada bloqueio passa no teste das 2 horas** — se resolvesse agora, o dia mudaria?
      Risco de fase não passa.
- [ ] Todo número citado foi medido, não estimado de cabeça.
- [ ] Todo item do Hoje interessa a mais alguém.
- [ ] Bloqueios em uma linha, com data quando existir, ou `N/A`.
- [ ] Uma linha por bullet, sem wrap manual — o canal reflui.
- [ ] Nenhuma frase truncada. (Já foi postado um bloqueio pela metade: *"Contrato
      comercial da CAF — sem cal..."*. Reler o texto inteiro antes de entregar,
      inclusive o último bullet.)
- [ ] **Nenhum pronome sem antecedente.** Cortar uma frase deixa órfão o `ela`/`isso` da
      seguinte: em 14/08 sobrou um *"então **ela** deixa de bloquear"* cujo sujeito tinha
      saído no corte. Reler depois de encurtar, não antes.
