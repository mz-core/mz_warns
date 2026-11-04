# Checklist runtime - advertencias administrativas Lote 1

Nenhum item abaixo deve ser marcado como aprovado sem execucao no servidor de teste.

## Preparacao

- [ ] Fazer backup antes do primeiro start.
- [ ] Iniciar `oxmysql`, `ox_lib`, `mz_core`, `mz_warns`, `mz_menu` e `mz_admin` nessa ordem.
- [ ] Confirmar `[mz_warns] ready autoPunishment=false` no console.
- [ ] Confirmar que `mz_warn_entries` e `mz_warn_audit` existem.
- [ ] Confirmar que nenhum cargo Staff existente recebeu permissao automaticamente.
- [ ] Conceder manualmente apenas as permissoes necessarias ao Staff de teste.

## Menu e comandos

- [ ] `/admin` abre com `mz_warns` iniciado.
- [ ] A area `Advertencias` aparece somente com `staff.warns.view`.
- [ ] A ficha do player mostra `Aplicar advertencia` somente com `staff.warns.issue`.
- [ ] A ficha do player mostra `Consultar advertencias` somente com `staff.warns.view`.
- [ ] `/warn ID motivo` cria um Public ID `MWR-XXXXXXXX`.
- [ ] O alvo recebe notificacao com Staff, Public ID e motivo.
- [ ] `/warns ID` e o menu mostram CitizenID sem expor license ou identifiers.
- [ ] `/unwarn MWR-XXXXXXXX motivo` revoga sem apagar o registro.

## Negativas obrigatorias

- [ ] Staff sem `staff.warns.issue` nao aplica advertencia pelo menu nem comando.
- [ ] Staff sem `staff.warns.view` nao consulta advertencias.
- [ ] Staff sem `staff.warns.revoke` nao revoga advertencias.
- [ ] Um Staff nao consegue advertir a si mesmo.
- [ ] Um Staff nao consegue advertir Owner ou Staff de nivel igual/superior.
- [ ] Motivo vazio ou menor que 3 caracteres e negado.
- [ ] Public ID invalido e negado.
- [ ] Revogacao repetida retorna `already_revoked`.
- [ ] `mz_warns` parado remove somente o modulo de advertencias; `/admin` continua abrindo.
- [ ] Banco/schema indisponivel falha fechado e nao cria resultado parcial.

## Persistencia, auditoria e concorrencia

- [ ] Criacao gera uma linha ativa e uma revisao `issued` na auditoria.
- [ ] Revogacao mantem a linha, muda status/revisao e gera auditoria `revoked`.
- [ ] Duas revogacoes simultaneas resultam em uma unica transicao valida.
- [ ] Restart preserva registros e estados.
- [ ] Logs globais mostram `admin.warn.issued` e `admin.warn.revoked`.
- [ ] Nenhum registro ou log expoe license bruta; CitizenID aparece somente no escopo Staff autorizado.

## Nao regressao

- [ ] Nenhuma advertencia executa kick.
- [ ] Nenhuma advertencia cria ou revoga ban no BanGuard.
- [ ] Ban, whitelist, wall, spectate, garagens e organizacoes continuam operacionais.
- [ ] O Owner continua resolvido somente por `group.mz_owner`.

## Resultado

- Status atual: **pendente de runtime**.
- Evidencias, data, servidor de teste e responsavel: preencher somente apos execucao.
