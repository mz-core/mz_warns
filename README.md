# MZ Warns

`mz_warns` e o dominio persistente de advertencias administrativas da framework MZ.

O recurso:

- usa o `mz_core` para identidade, permissoes, hierarquia e logs globais;
- persiste advertencias e revisoes de auditoria em tabelas proprias;
- disponibiliza os comandos `/warn`, `/warns` e `/unwarn`;
- fornece exports internos consumidos pelo `mz_admin`;
- nao aplica kick, ban ou qualquer outra punicao automatica.

## Ordem de inicializacao

```text
ensure oxmysql
ensure ox_lib
ensure mz_core
ensure mz_warns
ensure mz_menu
ensure mz_admin
```

O `mz_admin` trata `mz_warns` como modulo opcional. Se ele estiver parado ou sem schema valido, o restante do menu administrativo continua disponivel e a area de advertencias nao aparece.

## Permissoes

- `staff.warns.view`: consultar registros;
- `staff.warns.issue`: aplicar advertencia a player online inferior;
- `staff.warns.revoke`: revogar uma advertencia ativa.

Cada operacao e revalidada no servidor. A interface nunca concede a permissao.

## Persistencia

Com `Config.Database.AutoCreateMissingTables = true`, o bootstrap usa apenas `CREATE TABLE IF NOT EXISTS` para:

- `mz_warn_entries`;
- `mz_warn_audit`.

Nao existem migrations destrutivas, hard delete ou persistencia de license. CitizenID identifica o personagem no dominio e e exposto apenas no DTO administrativo autorizado, junto do Public ID `MWR-XXXXXXXX`.

## Teste estatico

```powershell
lua mz_warns/tests/api_contract_harness.lua
lua mz_warns/tests/integration_contract_harness.lua
```

O teste runtime esta em [docs/RUNTIME_CHECKLIST_LOT_1.md](docs/RUNTIME_CHECKLIST_LOT_1.md).
