<!-- v0.1.1-doc2 | 2026-09-13T19:22:10Z | Atualizado com auxílio de ChatGPT. -->
# Executar a POC v0.1.1

## Estado real

Código experimental implementado e testado localmente, sem integração Informix
executada. O par tipo/linguagem de SPL para `SupportedRoutines` ainda precisa ser
observado no ambiente. Como o mantenedor não possui ODS executável, a coleta
atual é estática sobre os JARs preservados do ODS 2.2.1.1.
Sem esse valor, `--probe` e `--run` recusam a configuração antes de abrir sockets.

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

Os levantamentos existentes provam o formato e a comparação exata dos pares,
mas não trazem a implementação de `RoutineService.getRoutineType(...)` nem um
bootstrap real com os números. Por isso esta versão não define um número por
suposição.

## Como descobrir o valor sem executar o ODS

Os resultados x18/x20 existentes contêm chamadas para
`RoutineService.getRoutineType(ArrayList)`, mas não o corpo desse método. Execute
a nova coleta estática nos JARs preservados:

```bash
cd /home/informix/tmp/spl.debug
bash /CAMINHO/DO/REPOSITORIO/bin/x21.sh
```

O script procura `RoutineService.class` em todos os JARs, coleta seu bytecode,
classes candidatas e registros Eclipse, e tenta derivar os pares adicionados
diretamente pelo método. Consulte o procedimento e os cuidados em
[`levantamentos/x21-supported-routines.md`](levantamentos/x21-supported-routines.md).

Se `x21/x21-summary.txt` contiver `psmd.supported.types=...`, o valor ainda deve
ser revisado contra a coleta antes de ser usado. Se ficar vazio, não testar
números: será preciso analisar `x21-private.tar.gz`, que não pode ser commitado.

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
| psmd.supported.types | Linha produzida pela coleta acima, sem o nome da propriedade. |
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

Cada script da POC grava saída em `bin/outputs/`. Para a etapa atual, execute
primeiro `test-x21.sh` e `x21.sh`. Commite o log `x21-self-test-*.log` e uma cópia
revisada de `x21-summary.txt`. O arquivo `x21-private.tar.gz` só deve ser anexado
à conversa se o resumo não resolver o par; nunca deve entrar no Git. Depois da
resolução, execute e commite os logs `build-*.log`, `test-local-*.log` e
`run-*.log`. Não envie novamente outputs já presentes no branch.
