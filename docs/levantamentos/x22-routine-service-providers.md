<!--
Versão: v1.2.0
Criado em: 2026-09-14T18:51:29Z
Atualizado em: 2026-09-15T14:10:00Z
Criado por: Codex (ChatGPT)
Projeto: ifx.spldebug
Finalidade: documentar a coleta das implementações de IRoutineService.
-->
# Coleta x22 — provedores de IRoutineService

## Evidência que motivou a coleta

O bytecode real de `RoutineService.getRoutineType(ArrayList)` não adiciona
tipos diretamente. Ele obtém todos os serviços registrados por
`RoutineServiceExtensionManager.getAllServices()` e chama
`IRoutineService.getRoutineType(ArrayList)` em cada implementação.

Por isso o resultado vazio do x21 é correto: os números pertencem aos provedores,
não à classe central.

## Execução histórica

O x22 foi um coletor temporário com autoteste sintético. Conforme a política
atual, scripts `x*` e seus outputs são trocados pela conversa e não permanecem
no repositório. Esta página conserva a metodologia e o resultado revisado da
coleta já concluída sobre a cópia preservada do ODS.

O x22:

1. extrai nomes de classes dos metadados Eclipse relevantes coletados pelo x21;
2. localiza essas classes nos JARs do ODS;
3. desmonta somente as classes candidatas;
4. seleciona as que expõem `getRoutineType(ArrayList)`;
5. deriva strings numéricas adicionadas à lista e converte `TL` para `T:L`;
6. seleciona para `psmd.supported.types` somente o provedor
   `com.ibm.debug.spd.spl.internal.core.SPLRoutineService`.

## Resultado confirmado em 2026-09-14

| Provedor | Pares |
| --- | --- |
| JavaRoutineService | `0:1` |
| PLSQLRoutineService | `0:3,1:3` |
| SPLRoutineService | `0:4,1:4` |
| SQLRoutineService | `0:0,1:0` |

O projeto anuncia somente suas capacidades de Informix SPL:

```properties
psmd.supported.types=0:4,1:4
```

Os valores foram obtidos dos JARs do ODS 2.2.1.1. Não foram deduzidos de
`T789`, do nome de uma rotina ou dos vetores sintéticos dos autotestes.

## Resultados

- `x22/x22-summary.txt`: resumo sanitizado enviado pela conversa;
- `x22-private.tar.gz`: bytecode e índices completos, fora do Git.

Na versão v1.1.0, `routine_service_pairs` mantém todos os pares encontrados para
auditoria, `spl_routine_service_pairs` contém apenas os pares do provedor SPL e
`psmd.supported.types` recebe somente esta última lista.

Se continuar sem resolução, enviar em ordem alfabética:

- `x22-private.tar.gz` — anexar à conversa, nunca commitar;
- `x22-summary.txt` — enviar pela conversa.
