# Advertencias administrativas - implementacao do Lote 1

## Estado

Implementacao local concluida estaticamente. A aprovacao runtime depende da execucao integral do checklist separado.

## Autoridades

- `mz_core`: identidade, permissoes globais, hierarquia entre Staff e logs detalhados;
- `mz_warns`: regras, persistencia, Public IDs, auditoria e comandos de advertencia;
- `mz_admin`: bridge e builders visuais;
- `mz_menu`: renderizacao e entrada de dados.

Nenhum desses limites cria membership, identidade, permissao ou tabela paralela fora do dominio correspondente.

## Contratos publicos internos

Exports de `mz_warns`:

```lua
exports['mz_warns']:IsReady()
exports['mz_warns']:Issue(actorSource, targetSource, reason)
exports['mz_warns']:List(actorSource, filters)
exports['mz_warns']:Revoke(actorSource, publicId, reason)
```

Somente recursos da allowlist podem chamar as operacoes. Toda chamada revalida source online, permissao granular no `mz_core`, prontidao do schema, formato e limites do payload.

`Issue` tambem nega auto-alvo e chama `CanStaffActOnPlayer`. O alvo precisa estar online para que sua identidade seja resolvida pelo servidor.

`List` pode consultar o escopo global ou filtrar um player online. O filtro `targetSource` nunca e convertido no cliente: o servidor resolve o CitizenID.

`Revoke` usa permissao separada, preserva o registro original e cria nova revisao. Ela nao usa indice visual ou exclusao fisica.

## Persistencia e privacidade

`mz_warn_entries` guarda CitizenID e nomes necessarios ao dominio. `mz_warn_audit` guarda uma linha imutavel por `public_id + entry_revision`.

O DTO expoe `citizenId` ao Staff autorizado para identificar o personagem, mas nao expoe license, identifiers, nomes internos de colunas ou demais dados do banco. Public IDs seguem `MWR-XXXXXXXX` e nao possuem significado sequencial.

Criacao e revogacao usam transacoes. A revogacao exige `status = active` e a revisao observada, falhando fechada diante de concorrencia.

## Integracao administrativa

O `/admin`:

- verifica `IsReady` sem tornar `mz_warns` uma dependencia obrigatoria;
- mostra area de advertencias somente com `staff.warns.view`;
- mostra emissao somente com `staff.warns.issue`;
- mostra revogacao somente com `staff.warns.revoke`;
- oferece emissao e consulta contextual na ficha de um player online;
- usa callbacks do bridge, que delegam aos exports sem SQL.

Se o builder client nao carregar, o menu possui guard de tipo e continua abrindo.

## Comandos

- `/warn [id] [motivo]`;
- `/warns [id]`;
- `/unwarn [MWR-XXXXXXXX] [motivo]`.

Os comandos sao registrados somente por `mz_warns` e usam a mesma API do menu.

## Diferencas deliberadas da referencia QBCore

Nao foram copiados:

- license bruta como chave ou retorno visual;
- tabela `player_warns`;
- exclusao por indice de lista;
- hard delete;
- consultas a tabelas QBCore;
- punicao automatica por quantidade de advertencias.

`Config.AutoPunishment` permanece `false` e nao existe fluxo que chame kick ou ban.

## Templates Staff

Em bancos novos:

- Moderador recebe `staff.warns.view` e `staff.warns.issue`;
- Administrador herda essas permissoes e recebe `staff.warns.revoke`;
- Gerente Staff herda o Administrador.

O seed e idempotente: cargos existentes nao sao alterados. O Owner deve conceder manualmente essas permissoes depois da validacao runtime.
