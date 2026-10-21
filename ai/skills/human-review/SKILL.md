---
name: human-review
description: Revisa um PR e posta como GitHub review com comentarios inline (um por achado, ancorados em linhas de codigo), em tom humano e informal PT-BR sem acentos. Use quando o usuario pedir review de PR nesse estilo, code review humanizado, ou comentarios nas linhas ao inves de um comentario solto no corpo do PR.
---

# Human Review

Skill pra revisar Pull Requests e publicar o review com comentarios **inline**
(ancorados em linhas de codigo), em tom humano e informal.

## Quando usar

- Pedido de review de PR ("revisa o PR X", "code review humano").
- Usuario quer comentarios nas linhas, nao um texto solto no corpo do PR.

## Filtro por repo e estado (antes de revisar)

Vale pra review avulso e pra lote. Filtra **antes** de gastar analise:

| Caso | O que fazer |
|---|---|
| PR mergeado | **Nunca comenta.** Se ja tinha comentario postado quando o merge aconteceu, apaga. |
| `banking-pj-app` | **So approve, sem comentario inline.** Se ja comentou, apaga e aprova. |
| `banking.atlas` | **Approve direto, sem review.** |
| Qualquer outro repo | Segue o Processo abaixo. |

**Por que:** comentario em PR ja mergeado ou desatualizado e ruido pro autor. pj-app e
atlas sao revisados por outras pessoas ou sao baixo risco pro usuario (20/10/2026: 3
comentarios apagados no pj-app#1049 a pedido dele, trocados por approve simples).

## Tom (o ponto principal)

- Portugues do Brasil, informal, **sem acentos**.
- Abreviacoes naturais: "vc", "pra", "tb", "ta".
- Informal, mas **sem girias**. Direto e tecnico.
- Um comentario por achado.
- **Tom de duvida, nao de veredito**: nao afirma que ta errado, pergunta se ta certo.
  Fala como quem leu rapido e quer confirmar com o autor, nao como quem ja decidiu.
  Usa "acho que", "sera que", "nao sei se", "confere?", "faz sentido isso?" em vez de
  "isso ta errado" / "precisa mudar". O autor sabe mais do contexto que a gente.
- O que postar e o `event` do review dependem da pior severidade encontrada
  (ver **Regra de veredito** abaixo).
- No preview da conversa, usa os emojis de severidade normalmente.
- **Nos comentarios postados no PR (body do comentario inline), sem emojis.** Texto limpo.
- Sempre que der, manda sugestao de codigo (bloco `suggestion`) junto — mesmo no tom
  de duvida ("algo assim talvez?"). So pula quando o fix nao for trivial (precisa de
  mudanca em varios arquivos/camadas) — nao vale se esforcar muito pra forcar uma.

## Processo

1. **Contexto**: se tiver card (Jira/issue) ligado, le o escopo + Definition of Done.
   Confirma o que o PR deveria entregar.
2. **Analise com `speckit-staff-review-run`**: roda a skill sobre o diff do PR, com a
   spec resolvida como em **Spec da analise** abaixo. Ela cobre corretude, seguranca,
   performance, aderencia a spec e qualidade de teste.
3. **Codigo**: confere cada achado da analise no diff **e** no codigo ao redor (nao so
   no diff), comparando com implementacoes irmas. Achado que o codigo nao confirma sai.
4. **Mapeia achado -> linha**: cada achado vira um comentario ancorado em arquivo +
   linha(s) do head do PR. Confirma o working tree limpo e pega o SHA do head pra os
   numeros baterem.
5. **Severidade**: classifica 🔴 / 🟡 / 🟢 no preview e aplica a **Regra de veredito** — sem emoji no body do comentario GitHub.
6. **Preview**: mostra o review pro usuario antes de postar. So posta apos o ok dele.
7. **Confere de novo e posta**: ver **Antes de postar**. Um review unico via API, com
   todos os comentarios inline. Sem comentario solto no corpo.

## Spec da analise (`speckit-staff-review-run`)

A `speckit-staff-review-run` precisa de spec, plan e tasks. Resolve nesta ordem:

1. **Existe spec do Spec Kit pro PR**: usa ela. Vale um feature dir em `specs/<feature>/`
   (com `spec.md`, `plan.md`, `tasks.md`) que o PR cria ou altera, um apontado por
   `.specify/feature.json`, ou um cujo nome tenha o ID do card (`specs/*CNT-XXXX*`).
   Se tiver mais de um candidato e o contexto nao desempatar, pergunta qual.
2. **Nao existe spec**: usa como spec o card do Jira citado na descricao do PR (se nao
   estiver na descricao, procura no titulo e no nome da branch).
   `jira issue view <ID> --raw` → descricao, criterios de aceite e DoD fazem o papel do
   `spec.md`. A descricao do PR faz o papel do `plan.md`, e o escopo vem do diff (nao tem
   `tasks.md`).
3. **Nem spec nem card**: roda so com o diff e a descricao do PR, e diz no preview que a
   aderencia a spec nao foi checada.

Adaptacoes ao rodar num PR de outra pessoa:

- **O relatorio nao vai pro repo.** A skill grava em `FEATURE_DIR/reviews/`; aqui o
  relatorio vai pro scratchpad da sessao, nunca pro clone do autor e nunca em commit.
- **Base do diff e a base do PR**, nao `main`: `gh pr diff <N>` ou
  `git diff origin/<base>...origin/<head>` (PR empilhado tem base de feature).
- O veredito dela (APPROVED / CHANGES REQUIRED) e insumo interno. Quem decide o `event`
  e o que vai pro PR e a **Regra de veredito** daqui, e o texto segue o **Tom**.

## Regra de veredito

A pior severidade do PR decide quais achados viram comentario e o `event` do review:

| Pior achado | Posta | `event` |
|---|---|---|
| 🔴 | 🔴 e 🟡 (ignora 🟢) | `REQUEST_CHANGES` |
| 🟡 (sem 🔴) | todos: 🟡 e 🟢 | `COMMENT` |
| so 🟢 | todos os 🟢 | `APPROVE` |
| nenhum | nada inline | `APPROVE` |

So muda se o usuario pedir outra coisa pra aquele PR.

## Antes de postar

Entre o preview e o post o PR pode andar. Imediatamente antes de postar, confere estado
e head SHA de cada PR (`gh pr view <N> --json state,headRefOid`):

- **Mergeado nesse meio tempo**: nao posta (ver **Filtro por repo e estado**).
- **Head mudou** (commit novo, force-push) ou o autor respondeu: le o que entrou e
  reconfere os achados contra o head novo. Nunca posta review preso a um SHA velho.
- **Igual ao preview**: posta com `commit_id` fixo nesse SHA.

## Como postar (gh api)

Endpoint: `POST /repos/{owner}/{repo}/pulls/{n}/reviews` com `comments[]`.

Monta o payload em **Python** — escapa acento, aspas, backtick e o fence `suggestion`
sem dor — e manda com `gh api --input`. Template pronto em [`post_review.py`](post_review.py).

- `commit_id`: fixa no SHA do head — `gh pr view <N> --json headRefOid -q .headRefOid`.
- Comentario de 1 linha: `{path, line, side:"RIGHT", body}`.
- Multi-linha: `{path, start_line, line, start_side:"RIGHT", side:"RIGHT", body}`.
- `event`: segue a **Regra de veredito** (`REQUEST_CHANGES` / `COMMENT` / `APPROVE`).
- A linha precisa existir no diff (arquivo alterado no PR). Achado sem linha no diff
  (ex: falta de teste de integracao) ancora num arquivo proximo que esta no diff e
  explica no texto.

## Bloco de sugestao

Pra sugerir codigo, o corpo do comentario inclui um bloco `suggestion` que substitui
**exatamente** as linhas do range comentado (cuida a indentacao final):

````
```suggestion
                code,
                "Mensagem amigavel pro usuario.",
```
````
