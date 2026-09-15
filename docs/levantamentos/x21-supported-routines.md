<!--
Versão: v1.1.0
Atualizado em: 2026-09-15T14:10:00Z
Criado em: 2026-09-13 16:22:10 -03:00
Criado por: Codex (ChatGPT)
Projeto: ifx.spldebug
Finalidade: orientar a coleta estática que identifica psmd.supported.types.
-->
# Coleta x21 — SupportedRoutines

## Motivo

Os levantamentos anteriores varreram 4.354 JARs do ODS 2.2.1.1 e confirmaram:

- `ClientComposer` transforma a lista em `<Routine type="..." language="..."/>`;
- `SessionClient` compara exatamente os pares tipo/linguagem;
- os wrappers chamam `RoutineService.getRoutineType(ArrayList)`.

Entretanto, os arquivos recuperados contêm apenas os **callers** de
`getRoutineType`. Não contêm o bytecode de `RoutineService`, seus possíveis
providers nem o registro de extensões que fornece os números. Portanto o valor
de `psmd.supported.types` ainda não pode ser obtido dos resultados x18/x20.

## Execução histórica

O coletor x21 foi temporário, não iniciava o ODS nem alterava seus JARs. Conforme
a política atual, scripts `x*` e seus outputs são trocados pela conversa e não
permanecem no repositório. Esta página conserva apenas a finalidade e a
conclusão técnica revisada da coleta já realizada.

## O que é coletado

- JAR que contém `com.ibm.debug.spd.internal.core.RoutineService`;
- bytecode básico e verbose dessa classe e de classes candidatas relacionadas;
- `plugin.xml`, `fragment.xml` e schemas `.exsd` que mencionam serviços de
  rotina, SPL, Informix ou Stored Procedure Debugger;
- hashes SHA-256 dos JARs envolvidos;
- candidatos numéricos adicionados diretamente por `getRoutineType`;
- pares explícitos encontrados em tags `<Routine type="..." language="...">`.

Quando `getRoutineType` adicionar strings no formato legado observado pelo ODS,
como `"12"`, o resumo converte a primeira posição em `type` e o restante em
`language`: `1:2`. O resultado ainda sai com `review_required=yes` para ser
conferido contra o bytecode coletado antes de entrar na configuração.

## Arquivos resultantes

- `x21/x21-summary.txt`: resumo sanitizado enviado pela conversa.
- `x21-private.tar.gz`: coleta completa; **não commitar**.

Se `discovery_status=RESOLVED_STATIC_REVIEW`, enviar primeiro somente o resumo.
Se continuar `UNRESOLVED` ou `ROUTINE_SERVICE_NOT_FOUND`, serão necessários, em
ordem alfabética:

- `x21-private.tar.gz` — anexar diretamente à conversa, fora do Git;
- `x21-summary.txt` — enviar pela conversa.

O autoteste histórico usou JAR sintético e validou a mecânica do coletor; ele
não validava os números do Informix.
