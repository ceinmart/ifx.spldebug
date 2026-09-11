<!-- v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT. -->
# Executar a POC v0.1.0

## Estado real

Código experimental implementado e testado localmente, sem integração Informix
executada. Falta confirmar o par tipo/linguagem de SPL para SupportedRoutines.
Sem esse valor os modos probe/run recusam a configuração antes de abrir sockets.
Os testes locais podem ser executados imediatamente e não dependem desse dado.

## Compilação e teste local

Requisitos: Linux, Bash, Java com compilador (JDK 8 ou superior), `tee` e `date`.
Não é preciso Maven/Gradle, rede ou dependências IBM para compilar.
`JAVA_HOME` é opcional; se definido, deve apontar para o JDK desejado.
Executar na raiz do checkout:

```bash
# v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
bash bin/build-v0.1.0.sh
bash bin/test-v0.1.0.sh
```

O teste também recompila. Resultado esperado: `PASS BUILD` e
`PASS LOCAL_PROTOCOL`, com códigos zero. Casos cobrem header conhecido, bytes
UTF-8, leituras fragmentadas, endianess, truncamento, limites, XML seguro,
retorno de erro e comandos pendentes. Vetores sintéticos são testes unitários,
nunca evidência de compatibilidade Informix.

## Preparar integração

Usar ambiente de teste com Informix 14.10, listener DRDA, banco com logging,
rotina de teste existente e permissão para executá-la. O driver deve ser JCC
`db2jcc4.jar`, fornecido pelo mantenedor, e o manager `db2dbgm.jar`.
Os scripts não instalam nem distribuem JARs. Compatibilidade dos JARs com a
JVM utilizada ainda precisa ser confirmada no ambiente.

Copiar `config/poc-v0.1.0.properties.example` para `config/local.properties` e
preencher os campos vazios com valores reais. Colocar em `config/call.sql`
somente uma chamada da rotina de teste escolhida; esse arquivo é ignorado pelo
Git. Caminhos relativos são resolvidos a partir da raiz ao executar os exemplos.

| Campo | Valor a fornecer |
| --- | --- |
| sm.host / sm.port | Endereço do manager acessível ao cliente e ao servidor Informix; padrão de porta 4554. |
| client.ip | IPv4 real usado na identidade do cliente. IPv6 não suportado nesta POC. |
| psmd.supported.types | Pares numéricos type:language separados por vírgula, confirmados por evidência. Valor SPL ainda pendente; não confundir com T789. |
| jdbc.url | URL JCC real do listener DRDA, começando por jdbc:db2:. Sem senha na URL. |
| jdbc.user | Login com permissão de execução. |
| call.file | Caminho para uma chamada CALL ou EXECUTE PROCEDURE/FUNCTION fornecida pelo mantenedor. |
| run.timeout.seconds | Prazo máximo do teste; padrão 60 segundos. |
| socket.timeout.ms | Prazo de conexão/leitura PSMD; padrão 10000 ms. |

Exportar `JCC_JAR` e `DBGM_JAR` com os caminhos completos dos JARs reais.
Não há caminhos fictícios neste documento. O script pergunta a senha via
terminal; alternativamente recebe `SPLDBG_PASSWORD` no ambiente, sem imprimi-la.

O motor usa autoCommit=false e rollback, sem commit próprio. Isso não desfaz
efeitos externos, commits internos ou operações não transacionais da rotina;
escolher uma rotina de teste adequada. Não executa CREATE/DROP automaticamente.

## Manager e testes

No host escolhido para o manager, iniciar em um terminal separado:

```bash
# v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
bash bin/session-manager-v0.1.0.sh
```

No cliente, após confirmar SupportedRoutines e preencher configuração:

```bash
# v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
bash bin/run-v0.1.0.sh --probe config/local.properties
bash bin/run-v0.1.0.sh --run config/local.properties --auto
```

Probe faz InitializeClient/Options/TerminateClient; não acessa JDBC.
O teste automático inicia a chamada, aguarda parada, envia Continue, espera
conclusão e executa cleanup. PASS exige essa sequência. Timeout, ausência de
parada, erro PSMD/SQL, configuração faltante ou cleanup incompleto retornam erro.
Sem `--auto`, o console aceita `continue`, `status`, `capabilities` e `quit`;
os nomes pendentes do catálogo retornam `NOT_IMPLEMENTED`.

## Resultados e próxima coleta

Cada script grava saída, versão, horário UTC, commit e status em `bin/outputs/`.
Os logs próprios não incluem valores, fonte, SQL, senha ou URL. Logs do manager
com sufixo `.private.log` são ignorados por poderem conter dados de depuração.
Revisar também o output da JVM/manager antes de publicá-lo.

Commitar logs revisados no mesmo branch da POC. Para análise, os grupos esperados,
em ordem alfabética, são: `build-*.log`, `run-*.log`, `test-local-*.log`.
O próximo passo imediato é executar teste local e confirmar SupportedRoutines.
Não é necessário anexar novamente outputs já commitados.
