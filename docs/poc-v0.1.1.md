<!-- v0.1.1 | 2026-09-11T19:30:37Z | Criado com auxílio de ChatGPT. -->
# Executar a POC v0.1.1

## Estado real

Código experimental implementado e testado localmente, sem integração Informix
executada. O par tipo/linguagem de SPL para `SupportedRoutines` ainda precisa ser
observado no ambiente. A v0.1.1 inclui um procedimento reproduzível para obtê-lo.
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

## Como descobrir o valor no ambiente

O método preferencial é observar uma inicialização feita pelo ODS compatível com
o Informix alvo. O PSMD estudado é TCP sem TLS e o XML aparece no payload. Faça
a captura somente em ambiente autorizado e durante uma sessão de teste.

1. Descubra a porta do Session Manager usada pelo ODS. Os padrões observados são
   4554 (standalone) e 4555 (builtin), mas confirme no processo/configuração.
2. Inicie a captura de `tcp.payload` com `tshark`, substituindo `PORTA`:

   ```bash
   sudo tshark -i any -f 'tcp port PORTA' -l -T fields -e tcp.payload \
     > /tmp/psmd-payload.hex
   ```

3. No ODS, inicie uma única depuração SPL até a sessão conectar. Pare o `tshark`
   com Ctrl+C.
4. Extraia somente os pares, sem commitar a captura:

   ```bash
   bash bin/discover-supported-types-v0.1.1.sh \
     --tshark-hex /tmp/psmd-payload.hex
   ```

5. Copie literalmente a linha `psmd.supported.types=...` exibida para
   `config/local.properties`.
6. Apague `/tmp/psmd-payload.hex` depois da conferência. O arquivo pode conter
   IDs, nomes e outras informações do protocolo e não deve entrar no Git.

Se já existir um log autorizado que contenha o XML completo de
`SupportedRoutines`, use `--raw ARQUIVO`. O extrator só resolve o valor quando
encontra o bloco e seus dois atributos numéricos. Ausência do bloco retorna
`SUPPORTED_ROUTINES_NOT_FOUND` e código diferente de zero; nesse caso não
preencha a propriedade.

O script cria em `bin/outputs/` um relatório `supported-types-discovery-*.log`
que contém o valor derivado, versão e checksums do código, mas não contém a
captura. Revise esse relatório antes de commitá-lo. A captura original permanece
fora do repositório.

### Alternativa quando o ODS não pode executar

Localize primeiro qual bundle contém a implementação, sem assumir que seja
`db2dbgm.jar`:

```bash
find "$ODS_HOME/plugins" -type f -name '*.jar' -print0 | while IFS= read -r -d '' jarfile; do
    if jar tf "$jarfile" | grep -q '^com/ibm/debug/spd/internal/core/RoutineService.class$'; then
        printf '%s\n' "$jarfile"
    fi
done
```

`db2dbgm.jar` não substitui esse bundle: ele implementa o Session Manager. Para
obter o valor estaticamente é necessário inspecionar o corpo de
`RoutineService.getRoutineType(ArrayList)` e, se ele consultar o registro de
extensões Eclipse, também as extensões registradas pela instalação. Uma simples
lista de métodos ou os callers já coletados não resolve o par. Não commitar JAR,
classe, bytecode integral ou código decompilado. Se essa for a única opção,
registrar somente a conclusão `type:language` e a identificação/hash do bundle.

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

Cada script grava saída em `bin/outputs/`. Para a próxima análise, commite os
logs revisados `build-*.log`, `supported-types-discovery-*.log` e
`test-local-*.log`; depois execute e commite `run-*.log`. Não anexe novamente
outputs que já estejam no branch.
