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
- Travessão pra separar o card do que aconteceu: `CNT-3325 — achei em homolog...`.
- Bullet pode ter 2–3 linhas se o achado exigir. Não corte a evidência pra caber numa
  linha; corte o adjetivo.

## A regra que mais importa: precisão de estado

**Três estados diferentes, e colapsar eles num "fechei" é o erro mais caro desta skill:**

| Estado | O que significa | Como escrever |
|---|---|---|
| **desenho fechado** | sei o que fazer, ninguém validou | *"fechei o **desenho** de X (decisões provisórias, pendentes de confirmação)"* |
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
  exagero corrigido. Vira credibilidade, não fraqueza.

## Hoje: o que o time pode cobrar até amanhã

Intenção verbal no infinitivo, e **só o que interessa a alguém além de você**.

Fora: trabalho mecânico interno (rodar lint, publicar doc em branch, ajustar CI local).
Faz parte do dia, não do report — e cada bullet a mais custa atenção dos outros.

Dentro: o que destrava alguém, o que precisa de resposta de terceiro, o que tem relógio.

## Bloqueios: uma linha cada, e só o que bloqueia de verdade

- **Uma linha, não parágrafo.** Se precisa de contexto longo, o lugar é a thread ou o card.
- Quando tem data, ela entra: *"Doc do 1:1 da Bankly — corte em 25/08"*.
- **Sem bloqueio, escreve `N/A`.** É o padrão do canal, e some com a tentação de
  inventar bloqueio pra parecer ocupado.
- Item que depende de você **não é bloqueio** — é Hoje.

## O que NÃO entra

- 🔴 **Nome de pessoa.** Lista a pendência, não quem deve. *"duas pendências sem dono:
  o contrato comercial e o card de app"* — não *"esperando o fulano"*. Regra explícita
  do usuário: cobrança nominal em canal público é ruído, e o dono muda.
- Adjetivo de esforço: *"trabalhei bastante"*, *"dia intenso"*, *"complexo"*.
- Preâmbulo e despedida. *"Bom dia gente,"* no topo é do canal, e é a única cortesia.
- Detalhe que só faz sentido pra quem está dentro do teu terminal.

## Processo

1. **Levanta os fatos, não confia na memória.** A daily é sobre ontem, e ontem tem
   registro:
   ```bash
   git log --oneline --since="2 days ago" --author="$(git config user.name)" --all
   gh pr list --author @me --state all --limit 10
   jira issue list --assignee @me --plain --columns key,status,summary
   ```
   Em repo de documentação, o `git log` é literalmente o diário — cada commit tem o
   porquê na mensagem.
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
- [ ] Todo número citado foi medido, não estimado de cabeça.
- [ ] Todo item do Hoje interessa a mais alguém.
- [ ] Bloqueios em uma linha, com data quando existir, ou `N/A`.
- [ ] Nenhuma frase truncada. (Já foi postado um bloqueio pela metade: *"Contrato
      comercial da CAF — sem cal..."*. Reler o texto inteiro antes de entregar,
      inclusive o último bullet.)
