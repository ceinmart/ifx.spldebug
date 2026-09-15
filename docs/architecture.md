# Informix SPL Debugger — Arquitetura Técnica

**Versão:** 1.5

**Data:** 2026-09-15T14:10:00Z

**Criado por:** ChatGPT / GPT-5.6 Sol  
**Status:** código experimental v0.1.1; bootstrap real aprovado; registro do runtime Informix pendente

## 1. Objetivo

Construir um debugger interativo para SPL do IBM/HCL Informix sem depender da interface gráfica do IBM Optim Development Studio.

A primeira implementação deverá ser um cliente texto, semelhante ao `gdb`, capaz de validar o protocolo e depois servir de base para um VS Code Debug Adapter.

Arquitetura pretendida:

```text
+-----------------------------+
| spldbg                      |
| cliente texto / futuro DAP  |
+-------------+---------------+
              |
              | PSMD TCP
              v
+-----------------------------+
| IBM Session Manager         |
| db2dbgm.jar                 |
| standalone default :4554    |
+-------------+---------------+
              ^
              |
              | PSMD TCP
              |
+-------------+---------------+
| Informix Debug Runtime      |
| SPL interpreter / p-code    |
+-------------+---------------+
              ^
              |
              | DRDA
              |
+-------------+---------------+
| conexão JDBC executora      |
| db2jcc4.jar                 |
+-----------------------------+
```

## 2. Base do levantamento

A arquitetura foi consolidada a partir de:

- documentação IBM/HCL sobre debugging de SPL;
- `db2dbgm.jar` distribuído com Informix;
- `db2jcc4.jar`;
- componentes do IBM Optim Development Studio 2.2.1 relacionados a Stored Procedure Debugger;
- desmontagem de bytecode Java com `javap` para identificar fluxos, formatos e contratos internos.

Os resultados abaixo distinguem fatos observados diretamente no código/documentação de hipóteses ainda não validadas em execução real.

## 3. Componentes necessários

| Componente | Necessário | Função |
|---|---:|---|
| Informix 14.10 | Sim | Executa a SPL e fornece o runtime de debug |
| Listener DRDA Informix | Sim | Permite ao JCC registrar `CLIENT DEBUGINFO` e executar a SPL |
| `db2jcc4.jar` | Sim na arquitetura inicial | Conexão DRDA e ativação da sessão de debugger |
| `db2dbgm.jar` | Sim | IBM Debug Session Manager |
| Java | Sim | Executar Session Manager e cliente inicial |
| ODS | Não | Usado somente como referência de engenharia reversa |
| `com.ibm.debug.spd...jar` | Não deve ser dependência | Referência para entendimento do protocolo |

O projeto não deve redistribuir componentes proprietários IBM/HCL.

## 4. Ativação da sessão no Informix

Antes da execução da procedure, a conexão JDBC que executará a SPL recebe o `debugInfo`.

Formato identificado no ODS:

```text
M<SM_HOST>:<SM_PORT>,I<CLIENT_IP>,P<CLIENT_PID>,T789,C<CONNECTION_ID>,L<TRACE_LEVEL>
```

Opcionalmente:

```text
,J<PORT_MANAGER_HOST>:<PORT_MANAGER_PORT>
```

Para o primeiro debugger SPL interessa inicialmente:

```text
M<host>:<port>,I<ip>,P<pid>,T789,C<connectionId>,L<trace>
```

O ODS chama a conexão JCC por meio de `DB2Connection.setDB2ClientDebugInfo(debugInfo)`.

A análise do JCC mostrou que isso é convertido para:

```sql
SET CLIENT DEBUGINFO '<debugInfo>'
```

pela conexão DRDA, usando o fluxo normal de SQLSTT. Não há necessidade de implementar DRDA bruto na primeira versão.

Para limpar a sessão, o ODS utiliza:

```text
M0:0,I0,P0,T0,C0,L0
```

## 5. Identificadores de correlação

O protocolo trabalha com três identificadores principais:

```text
clientID
connectionID
routineID
```

A hierarquia lógica observada é:

```text
Client
  |
  +-- Connection
  |      |
  |      +-- Routine
  |      +-- Routine
  |
  +-- Connection
         |
         +-- Routine
```

`connectionID` é particularmente importante porque também é incluído no `CLIENT DEBUGINFO` como `C<connectionId>`, permitindo correlacionar a conexão executora com a sessão mantida pelo Session Manager.

## 6. Session Manager

O Session Manager é implementado por `db2dbgm.jar`.

Foram identificados três modos no ODS:

```text
Builtin     -> default 4555
Server      -> default 4553
Standalone  -> default 4554
```

Para a primeira versão do projeto deve ser usado o modo **Standalone**, por ser o mais simples de reproduzir e observar.

Exemplo documentado de inicialização:

```bash
export CLASSPATH=${INFORMIXDIR}/bin/db2dbgm.jar:$CLASSPATH
java com.ibm.db2.psmd.mgr.Daemon -port 4554 -log /tmp/psmd.log
```

O Session Manager aceita conexões TCP de ambos os lados do mecanismo:

```text
Debugger Client  ----\
                     >---- Session Manager
Informix Runtime ----/
```

A evidência atual indica que ambos os peers conectam inbound ao Session Manager; não foi observado o manager iniciando conexão de retorno para o Informix.

## 7. Inicialização PSMD

O protocolo identificado no ODS é PSMD versão `3.3`.

Fluxo inicial:

```text
InitializeClient
ClientRequest
ConnectionRequest
RoutineRequests
```

Estrutura conceitual do bootstrap:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PSMDRequest version="3.3">
    <InitializeClient clientID="...">
        <SupportedRoutines>
            ...
        </SupportedRoutines>
    </InitializeClient>
</PSMDRequest>
```

Depois da inicialização, o cliente envia requests associados ao `clientID`, `connectionID` e `routineID`.

## 8. Framing TCP

Cada mensagem PSMD possui um cabeçalho binário de 20 bytes:

| Offset | Tamanho | Campo |
|---:|---:|---|
| 0 | 2 | `byteOrder` |
| 2 | 2 | `messageType` |
| 4 | 4 | `xmlMsgSize` |
| 8 | 4 | `xmlDataSize` |
| 12 | 4 | `binDataSize` |
| 16 | 4 | `F0` |

O marcador de byte order observado é `0xDB2D`.

Após o header seguem, conforme os tamanhos indicados:

```text
XML message
XML data
binary data
```

O XML é UTF-8.

## 9. Tipos de mensagem

### Cliente -> Session Manager

| Tipo | Código |
|---|---:|
| END_MANAGER | 0 |
| PING_MANAGER | 2 |
| INITIALIZE_CLIENT | 10 |
| SEND_ROUTINE_COMMAND | 20 |
| SEND_MANAGER_COMMAND | 25 |
| RECV_DEBUG_REPORTS | 30 |
| TERMINATE_CLIENT | 40 |

### Runtime/Server -> Session Manager

| Tipo | Código |
|---|---:|
| PRE_ENTER_ROUTINE | 1000 |
| ENTER_ROUTINE | 1010 |
| EXIT_ROUTINE | 1020 |
| INITIALIZE_ROUTINE | 1030 |
| PUT_DEBUG_REPORTS | 1040 |
| PUT_MGR_DEBUG_REPORTS | 1041 |
| GET_DEBUG_COMMANDS | 1050 |
| TERMINATE_ROUTINE | 1060 |
| SET_MGR_INFO | 1070 |
| GET_MGR_INFO | 1080 |
| PING_MGR | 1090 |
| SET_PORT_RANGE | 1100 |
| RESERVE_PORT | 1110 |
| RESERVE_ALTERNATE_PORT | 1120 |
| RELEASE_PORT | 1130 |

`999` aparece como `CLIENT_REQUESTS_MARKER`, separando claramente as duas famílias de mensagens.

## 10. Comandos de execução

O Session Manager suporta os modos:

```text
Pause
StepInto
StepOver
StepReturn
RunToLine
Run
Terminate
```

Valores internos identificados:

```text
1004  Pause
1008  StepInto
1012  StepOver
1016  StepReturn
1020  RunToLine
1024  Run
1028  End
1032  Terminate
```

O cliente deve trabalhar semanticamente com os nomes, mantendo os números confinados à camada de protocolo.

## 11. Breakpoints

O protocolo suporta pelo menos:

- line breakpoints;
- variable breakpoints;
- enable/disable;
- hit count / hit mode.

Métodos identificados no ODS incluem:

```text
composeAddLineBkpt
composeRtnRequest_AddLineBkpts
composeAddVarBkpt
composeRtnRequest_AddVarBkpts
```

A primeira POC deve implementar apenas breakpoint de linha.

## 12. Variáveis e stack

Foram identificados comandos explícitos:

```text
GetVar
SetVar
SetLen
```

O protocolo também transporta call stack, stack frames e variáveis de frame.

Mapeamento futuro possível para DAP:

```text
PSMD CallStack   -> DAP stackTrace
PSMD variables   -> DAP variables
PSMD GetVar      -> DAP evaluate
PSMD SetVar      -> DAP setVariable
```

Esse mapeamento é uma decisão de arquitetura do projeto, não terminologia oficial IBM.

## 13. Reports e modelo assíncrono

O cliente solicita reports por meio de `RecvClientReports`.

O ODS gera esse request com:

```text
clientID
 timeout=2000
```

Reports identificados incluem:

```text
AtBreakpoint
AtLine
AtException
CallStack
StackFrame
Failure
```

Portanto o cliente deve possuir uma rotina/event-loop dedicada à recepção de reports, em vez de operar apenas como request/reply síncrono.

## 14. Sequência prevista de uma sessão

```text
1. Iniciar Session Manager.
2. Cliente conecta ao Session Manager.
3. InitializeClient(clientID).
4. Abrir conexão JDBC/DRDA executora.
5. Criar connectionID.
6. Aplicar CLIENT DEBUGINFO na conexão JDBC.
7. Criar ClientRequest / ConnectionRequest.
8. Configurar breakpoints.
9. Executar CALL da procedure pela conexão marcada.
10. Informix debugger runtime conecta ao Session Manager.
11. Runtime envia eventos de entrada/inicialização da routine.
12. Cliente recebe AtLine / AtBreakpoint / stack / variáveis / exceptions.
13. Cliente envia Step/Run/RunToLine/SetVar/GetVar conforme necessário.
14. Runtime envia EXIT_ROUTINE.
15. Cliente envia TerminateClient.
16. Limpar CLIENT DEBUGINFO com M0:0,I0,P0,T0,C0,L0.
17. Fechar conexão JDBC.
```

## 15. POC mínima recomendada

A primeira implementação deve comprovar somente:

```text
conectar ao Session Manager
        -> InitializeClient
        -> abrir DRDA
        -> setDB2ClientDebugInfo
        -> executar CALL simples
        -> receber primeiro AtLine/AtBreakpoint
        -> Run/Continue
        -> TerminateClient
```

Somente após esse fluxo funcionar devem ser adicionados:

- step into / over / return;
- stack;
- variáveis;
- alteração de variáveis;
- breakpoints completos;
- VS Code Debug Adapter.

## 16. Caminhos IBM alternativos observados

No ODS também existem referências a:

```text
DB2DEBUG.DBG_InitializeClient(...)
SYSPROC.DBG_InitializeClient(...)
DB2DEBUG.DBG_SendClientRequests(...)
SYSPROC.DBG_SendClientRequests(...)
```

Essas rotinas comprovam que o componente IBM suporta mais de um backend/geração do Unified Debugger.

Não há evidência suficiente para afirmar que essas procedures são necessárias no Informix 14.10. O caminho priorizado neste projeto permanece:

```text
SET CLIENT DEBUGINFO
+
Session Manager TCP
+
Informix debugger runtime
```

## 17. Dependências proprietárias e licença

O projeto deverá implementar seu próprio cliente PSMD.

Não devem ser copiados ou redistribuídos:

- código decompilado do ODS;
- `db2jcc4.jar`;
- `db2dbgm.jar`;
- outros artefatos proprietários IBM/HCL.

A estratégia recomendada é exigir que o usuário aponte para cópias legítimas desses JARs provenientes de sua instalação/licença.

## 18. Grau de confiança atual

| Item | Confiança |
|---|---|
| DRDA necessário para o fluxo estudado | Alta |
| Session Manager / `db2dbgm.jar` | Alta |
| porta standalone 4554 | Alta |
| `SET CLIENT DEBUGINFO` no JCC | Alta |
| formato `M...,I...,P...,T789,C...,L...` | Alta |
| framing PSMD | Alta |
| hierarquia Client -> Connection -> Routine | Alta |
| commands / variables / breakpoints / reports | Alta |
| runtime servidor conectando inbound ao Session Manager | Alta, ainda a validar em execução real |
| necessidade de `DB2DEBUG.DBG_*` no Informix | Não estabelecida |
| protocolo interno do AGS Server Studio | Desconhecido |

## 19. Próxima etapa

O levantamento está fechado o suficiente para iniciar uma POC mínima.

A próxima etapa do projeto deve validar o caminho real ponta a ponta antes de qualquer implementação de VS Code.

## 20. Decisões de implementação v0.1.1

O motor Java concentra PSMD, JDBC e ciclo de vida. O console atual é um consumidor
do motor. Python CLI/TUI e DAP permanecem futuros consumidores independentes.
Não há dependência do VS Code em Python nem dependência do motor em interface.

O contrato interno tem solicitação identificada, resposta correlacionada e
eventos assíncronos imutáveis. A ponte futura poderá usar JSON por linha em
stdin/stdout de um processo Java filho, com logs em stderr. Isso será um
protocolo próprio versionado, não DAP. A v0.1.1 **não implementa essa ponte**.

Um worker possui a conexão JDBC executora. Outro solicita reports. Cada
round-trip PSMD usa seu próprio socket com timeout, evitando que o polling
bloqueie o stream dos comandos. Essa escolha de conexão por round-trip é
decisão experimental do projeto e precisa de teste contra o manager real.
O estado central é NEW / READY / RUNNING / STOPPED / COMPLETED / FAILED / CLOSED.
Uma chamada pode terminar antes do ACK de Run; o ACK não pode sobrescrever
COMPLETED. Encerramento usa Terminate quando há execução pendente e
TerminateClient; o worker limpa DEBUGINFO, faz rollback e fecha JDBC.
Timeout no cleanup é falha explícita, nunca PASS.

A v0.1.1 aceita uma sessão, uma conexão e uma chamada por processo. Usa StepInto
internamente para pedir a parada inicial após identificar a conexão nos reports
(se ainda não houve parada) e Run para continuar. A operação
interativa de stepping fica pendente. No teste automático, continuar cada
parada recebida até a conclusão ou timeout. Não instalar SPL nem alterar schema.

## 21. Evidências adicionais recuperadas

Foram acessados os arquivos abaixo, fora do repositório. As observações não
comprovam interoperabilidade com uma instalação Informix real.

| Evidência | Conclusão observada |
| --- | --- |
| `xml_protocol.txt`, ClientComposer | `SupportedRoutines` contém `Routine` com atributos numéricos `type` e `language`. |
| `connection_routine_flow.txt`, SessionClient | Compatibilidade compara pares de tipo/linguagem; lista vazia não é um curinga. |
| `debug_info.txt`, ClientSessionManager.generateClientId | `clientID` é IP + dois-pontos + identificador P; deve coincidir com os campos I/P de DEBUGINFO. |
| `psmd_flow.txt`, MessageHeader | Envio big-endian, marcador DB2D, F0=0 no construtor de request. A semântica geral de F0 permanece aberta. |
| `connection_routine_flow.txt`, ClientUtility | ClientRequest/ConnectionRequest usam tipo 25; SendClientCommands usa tipo 20. |
| `connection_routine_flow.txt`, SessionClientThread/SessionClient | ConnectionRequest antes de EnterRoutine encontra conexão inexistente e retorna -120. Solicitar StepInto só após observar a conexão nos reports. |
| `xml_protocol.txt`, ClientComposer | RecvClientReports usa clientID e timeout=2000. TerminateClient usa clientID. |
| `psmd_flow.txt`, ClientUtility.readReply | Resposta XML possui rc no primeiro nó filho. A POC exige PSMDReply/Reply com rc=0. |
| `reports.txt`, PSMDTokens | Nomes observados: AtLine, AtBreak, AtBreakPt, AtException, RoutineText, LineMap. AtBreakpoint é nome conceitual/classe, não o token usado nesta POC. |

O par específico foi confirmado pela coleta x22 no bytecode de
`com.ibm.debug.spd.spl.internal.core.SPLRoutineService`. Esse provedor adiciona
as strings `04` e `14`; pelo contrato confirmado do `ClientComposer`, elas viram
`<Routine type="0" language="4"/>` e `<Routine type="1" language="4"/>`.
Portanto o cliente deste projeto deve configurar
`psmd.supported.types=0:4,1:4`. `T789` continua sendo um campo independente.

O ODS completo anunciaria também pares fornecidos pelos plugins Java, PL/SQL e
SQL. Eles não devem ser copiados para este projeto: `SupportedRoutines` declara
as capacidades do cliente, e este cliente implementa somente Informix SPL. As
evidências e o procedimento reproduzível ficam em
`levantamentos/x22-routine-service-providers.md`.

Uma captura autorizada de `InitializeClient` continua sendo evidência válida se
um ambiente executável surgir futuramente. O extrator
`discover-supported-types-v0.1.1.sh` permanece disponível, mas não é requisito
para a coleta atual.

## 22. Fonte SPL: visualização, sem edição

A fonte futura deverá ser associada à identidade exata da rotina e a um mapa
entre posição do runtime e linha exibida. Não assumir que rid PSMD seja procid,
nem que seqno ou posição no arquivo coincida automaticamente com a linha PSMD.

Origens planejadas:

1. Conteúdo do runtime, se RoutineText/LineMap forem efetivamente recebidos e
   seus formatos forem confirmados. Hoje há evidência dos tokens, não garantia
   de que o Informix forneça o fonte por esse caminho.
2. Catálogo do banco: SYSPROCBODY armazena texto de criação sob datakey T,
   identificado por procid e seqno. Resolver sobrecarga/schema/assinatura antes
   de recuperar, preservar texto e verificar o mapeamento de linhas.
3. Arquivo local indicado explicitamente, somente leitura, com correspondência
   de versão validada pelo usuário e mapeamento conhecido.

Fonte oficial para o catálogo: [HCL Informix 14.10 — SYSPROCBODY](https://help.hcl-software.com/hclinformix/1410/sqr/ids_sqr_051.html).
A implementação de SOURCE_GET e SOURCE_MAP é futura. Não criar editor,
invocação de Vim/Nano ou recompilação por consequência dessa funcionalidade.

## 23. Pendências para validar ponta a ponta

- Confirmar versão exata do JCC e compatibilidade com a versão do Informix; o par SPL já foi resolvido.
- Confirmar o endereço de retorno do servidor Informix até o Session Manager.
- Identificar por que o runtime não registrou a rotina SPL no teste real.
- Confirmar parada inicial por StepInto, formato/envelope dos reports, correlação,
  Run e limpeza. Parser recusa respostas incompatíveis explicitamente.
- Conferir resultado e eventuais timeouts no encerramento, inclusive interrupção.
- Somente depois habilitar os comandos pendentes e iniciar ponte Python/DAP.

Os scripts e a evidência local ficam descritos em `poc-v0.1.1.md`; o catálogo
completo do escopo conhecido do projeto fica em `commands.md` e `Commands.java`.

## 24. Resultado real de 2026-09-15

O teste com Informix confirmou `InitializeClient`, `Options`, conexão JCC/DRDA,
aplicação de `CLIENT DEBUGINFO` sem exceção, execução da `CALL`, limpeza do
atributo, rollback, fechamento JDBC e `TerminateClient`. A mesma chamada também
foi validada por `dbaccess`.

O log privado do Session Manager não contém `EnterRoutine`, identificação de
rotina ou report de linha para essa execução. Isso localiza a falha entre a
marcação da conexão e o registro do runtime Informix; não há evidência de que
`StepInto` tenha sido simplesmente enviado tarde. A POC agora diferencia esse
caso como `NO_DEBUG_RUNTIME_REGISTRATION` e emite `DEBUGINFO_APPLIED` após o JCC
aceitar a marcação. Uma janela configurável curta permite ao polling consumir
um registro que tenha chegado simultaneamente ao retorno da chamada.
