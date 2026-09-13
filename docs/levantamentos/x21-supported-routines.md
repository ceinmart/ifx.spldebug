<!--
Versão: v1.0.0
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

## Executar

O script não inicia o ODS e não altera os JARs. Ele usa a cópia já extraída em
`/home/informix/tmp/spl.debug/ods-2.2.1.1`:

```bash
cd /home/informix/tmp/spl.debug
bash /CAMINHO/DO/REPOSITORIO/bin/x21.sh
```

Ou informe os caminhos explicitamente:

```bash
bash bin/x21.sh \
  --ods-root /home/informix/tmp/spl.debug/ods-2.2.1.1 \
  --output /home/informix/tmp/spl.debug/x21
```

Requisitos: Bash, Java/JDK, `unzip`, `tar`, `sha256sum` e utilitários GNU. O
script localiza `jar`/`javap` em `JAVA_HOME`, ao lado do executável `java` ou nos
módulos do JDK 9+.

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

- `x21/x21-summary.txt`: resumo sanitizado; pode ser commitado após revisão.
- `x21-private.tar.gz`: coleta completa; **não commitar**.

Se `discovery_status=RESOLVED_STATIC_REVIEW`, enviar primeiro somente o resumo.
Se continuar `UNRESOLVED` ou `ROUTINE_SERVICE_NOT_FOUND`, serão necessários, em
ordem alfabética:

- `x21-private.tar.gz` — anexar diretamente à conversa, fora do Git;
- `x21-summary.txt` — copiar para `bin/outputs/` e commitar.

## Autoteste

Antes de executar sobre os JARs reais:

```bash
bash bin/test-x21.sh
```

O teste compila um JAR sintético temporário, valida descoberta, metadados,
conversão dos pares e criação do arquivo privado. Resultado esperado:
`PASS X21_SELF_TEST`. Isso valida o coletor, não os números do Informix.
