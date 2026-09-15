<!-- v0.1.1-doc4 | 2026-09-15T14:10:00Z | Atualizado com auxílio de ChatGPT. -->
# Executar a POC v0.1.1

## Estado real

Código experimental implementado e testado localmente. O teste real confirmou
o bootstrap do Session Manager e a execução JCC/DRDA, mas o runtime Informix não
registrou a rotina e não produziu parada. A coleta estática x22 confirmou no
provedor SPL do ODS 2.2.1.1 os pares `0:4` e `1:4`.

## Compilação e teste local

Requisitos: Linux, Bash, Java com compilador (JDK 8 ou superior), `tee`, `date` e
`sha256sum`. Não é preciso Maven/Gradle, rede ou dependências IBM para compilar.
`JAVA_HOME` é opcional. Na raiz do checkout:

```bash
bash bin/build-v0.1.1.sh
bash bin/test-v0.1.1.sh
```

Resultado esperado: `PASS BUILD` e `PASS LOCAL_PROTOCOL`, com códigos zero. Os
testes incluem a extração de pares de um XML sintético. Esses pares de teste
**não** são valores documentados para Informix.

## O que é `psmd.supported.types`

É a lista de capacidades anunciada pelo cliente no `InitializeClient` PSMD:

```xml
<SupportedRoutines>
    <Routine type="TYPE" language="LANGUAGE"/>
</SupportedRoutines>
```

Na propriedade, cada elemento vira `TYPE:LANGUAGE`; quando a captura contiver
mais de um `Routine`, todos são preservados na ordem observada e separados por
vírgula:

```properties
psmd.supported.types=<TYPE>:<LANGUAGE>[,<TYPE>:<LANGUAGE>...]
```

Os sinais `<` e `>` acima indicam campos a substituir e não devem aparecer no
arquivo final. `type` e `language` são identificadores numéricos distintos.
`T789`, usado em `CLIENT DEBUGINFO`, é outro campo e não fornece esses valores.
Uma lista vazia também não significa “qualquer rotina”.

O levantamento x22 encontrou quatro provedores. O provedor específico de SPL,
`com.ibm.debug.spd.spl.internal.core.SPLRoutineService`, adiciona `04` e `14`,
serializados pelo cliente como `0:4` e `1:4`. Os pares dos provedores Java,
PL/SQL e SQL não são capacidades deste cliente e não devem ser anunciados.

## Como o valor foi descoberto sem executar o ODS

Os resultados x18/x20 continham chamadas para
`RoutineService.getRoutineType(ArrayList)`, mas não o corpo desse método. O
coletor temporário x21 procurou `RoutineService.class` nos JARs preservados e
mostrou a delegação aos provedores. Consulte a conclusão revisada em
[`levantamentos/x21-supported-routines.md`](levantamentos/x21-supported-routines.md).

O x21 mostrou que `RoutineService` apenas delega para implementações de
`IRoutineService`. O x22 localizou os provedores e resolveu o valor SPL. Use:

```properties
psmd.supported.types=0:4,1:4
```

`db2dbgm.jar` não substitui os bundles do ODS: ele implementa o Session Manager.
Uma listagem de métodos ou os callers já coletados também não resolve o par.

### Captura de bootstrap

O extrator `discover-supported-types-v0.1.1.sh` permanece disponível para um
futuro XML/captura real de `InitializeClient`, mas não é o caminho atual porque
o mantenedor não possui um ODS executável.

## Preparar integração

Use Informix 14.10 de teste, listener DRDA, banco com logging, rotina existente e
permissão para executá-la. O driver é `db2jcc4.jar`, fornecido pelo mantenedor, e
o manager é `db2dbgm.jar`. Os scripts não instalam nem distribuem esses JARs.

Copie `config/poc-v0.1.1.properties.example` para `config/local.properties` e
preencha os campos reais. Coloque em `config/call.sql` somente uma chamada da
rotina de teste; esse arquivo é ignorado pelo Git.

| Campo | Valor a fornecer |
| --- | --- |
| sm.host / sm.port | Manager acessível ao cliente e ao Informix; standalone costuma usar 4554. |
| client.ip | IPv4 real usado na identidade do cliente. |
| psmd.supported.types | `0:4,1:4`, confirmado no `SPLRoutineService` do ODS 2.2.1.1. |
| jdbc.url | URL JCC real do listener DRDA, começando por `jdbc:db2:`; sem senha. |
| jdbc.user | Login com permissão de execução. |
| call.file | Arquivo com uma chamada `CALL` ou `EXECUTE PROCEDURE/FUNCTION`. |
| run.timeout.seconds | Prazo máximo do teste; padrão 60 segundos. |
| socket.timeout.ms | Prazo de conexão/leitura PSMD; padrão 10000 ms. |

Exporte `JCC_JAR` e `DBGM_JAR` com caminhos completos. A senha é perguntada no
terminal ou recebida em `SPLDBG_PASSWORD`, sem ser impressa. O motor usa
`autoCommit=false` e rollback próprio; isso não desfaz commits internos, efeitos
externos ou operações não transacionais da rotina.

## Manager e testes

No host do manager:

```bash
bash bin/session-manager-v0.1.1.sh
```

No cliente, depois de preencher a configuração:

```bash
bash bin/run-v0.1.1.sh --probe config/local.properties
bash bin/run-v0.1.1.sh --run config/local.properties --auto
```

Probe faz InitializeClient/Options/TerminateClient e não acessa JDBC. O teste
automático espera parada, envia Continue, espera conclusão e executa cleanup.
PASS exige a sequência completa; timeout, erro remoto, configuração ausente ou
cleanup incompleto retornam erro.

Depois de aplicar `CLIENT DEBUGINFO`, o cliente emite `DEBUGINFO_APPLIED`. Se a
chamada retornar sem o Session Manager reportar a conexão do runtime, o erro é
`NO_DEBUG_RUNTIME_REGISTRATION`; se houver conexão mas nenhuma parada, o erro é
`NO_DEBUG_STOP_EVENT`. `runtime.registration.grace.ms`, com padrão de 1000 ms,
evita classificar como ausência um report recebido junto com o retorno da CALL.

Cada script permanente da POC grava saída em `bin/outputs/`. Depois da execução,
revise e commite quando útil os logs `build-*.log`, `test-local-*.log` e
`run-*.log`. Coletores temporários `x*` e seus outputs são enviados apenas pela
conversa e não entram no repositório.
