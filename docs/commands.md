<!-- v0.1.1 | 2026-09-11T19:30:37Z | Criado com auxílio de ChatGPT. -->
# Catálogo estruturado do debugger

Contrato público do **projeto**, não API IBM. Abrange todos os comandos e
recursos de depuração identificados até esta versão nos levantamentos e nos
requisitos de interface. Não afirma esgotar recursos de todas as versões PSMD.
Novas evidências devem ampliar este catálogo antes de implementar o comando.

Fonte executável: `src/main/java/ifx/spldebug/Commands.java`.
`Main --catalog` lista nome, status e parâmetros, inclusive os não implementados.
`CAPABILITIES` retorna o catálogo na resposta estruturada do núcleo.

## Status

- **IMPLEMENTED_EXPERIMENTAL (I):** caminho implementado; integração real pendente.
- **PENDING (P):** recurso planejado a partir de evidência ou requisito de UI.
- **CONTRACT_UNKNOWN (?):** token/recurso conhecido, contrato ou semântica insuficiente.

P e ? retornam `success=false`, `code=NOT_IMPLEMENTED`; não enviam PSMD.
Status I não significa que o Informix aceitou o comando em teste real.

## Operações

| Comando | Parâmetros do projeto | Status | Destino/evidência |
| --- | --- | --- | --- |
| CAPABILITIES | nenhum | I | Catálogo local, sem rede |
| STATUS | nenhum | I | Estado, clientID, connectionID, routineID, linha |
| INITIALIZE | configuração entregue ao construtor | I | InitializeClient + ClientRequest/Options |
| EXECUTE | call; ausente: call.file da configuração | I | Worker JCC, marca DEBUGINFO, StepInto inicial, execução |
| CONTINUE | conexão corrente | I | ConnectionRequest/Run |
| DISCONNECT | sessão corrente | I | Terminate se pendente, TerminateClient e cleanup JDBC |
| PAUSE | connectionID | P | Pause |
| STEP_INTO | connectionID | P | StepInto; apenas uso interno na partida está implementado |
| STEP_OVER | connectionID | P | StepOver |
| STEP_RETURN | connectionID | P | StepReturn |
| STEP_OUT | connectionID | ? | Token StepOut, não presumir equivalência com StepReturn |
| RUN_TO_LINE | connectionID, routineID, line | P | RunToLine, rid e line |
| END | connectionID | ? | End; não presumir igualdade com Terminate |
| TERMINATE | connectionID | P | Terminate; uso interno de cleanup já existe |
| BREAKPOINT_ADD_LINE | routineID, line, enabled, hitMode, hitCount | P | AddLineBreakPt |
| BREAKPOINT_ADD_VARIABLE | routineID, variable, condition, hitMode, hitCount | P | AddVarBreakPt; condição é campo planejado, gramática pendente |
| BREAKPOINT_REMOVE | routineID, breakpointID | P | RemoveBreakPt |
| BREAKPOINT_REMOVE_ALL | routineID | P | RemoveAllBreakPts |
| BREAKPOINT_ENABLE | routineID, breakpointID | P | EnableBreakPt |
| BREAKPOINT_DISABLE | routineID, breakpointID | P | DisableBreakPt |
| BREAKPOINT_LIST | routineID | P | Modelo local; não inventar comando PSMD de listagem |
| STACK | connectionID | P | Reports CallStack/StackFrame; solicitação wire ainda não definida |
| FRAME_SELECT | frameID | P | Contexto local da interface |
| VARIABLES | frameID | P | Reports de variáveis do frame |
| VARIABLE_GET | frameID, variableID | P | GetVar |
| VARIABLE_SET | frameID, variableID, value, type | P | SetVar; tratamento de tipos/nulos pendente |
| VARIABLE_SET_LENGTH | variableID, length | P | SetLen |
| SOURCE_GET | routineID, origin, path opcional | P | Fonte somente leitura: runtime, catálogo ou arquivo |
| SOURCE_MAP | routineID | ? | LineMap observado; correspondência runtime/fonte pendente |
| ROUTINES | connectionID | P | Modelo de rotinas recebido; não inventar comando remoto |
| ROUTINE_ADD | routineID, options | ? | AddRoutine observado; direção/contexto a confirmar |
| OPTIONS | sessionTimeout, maxVarReportSize | P | Options; sessionTimeout=300 usado internamente na POC |
| TRACE | scope, mode | ? | Trace observado |
| TRACE_MODE | LineByLine, Variables, Statements, Timings | ? | TraceMode e opções observadas |
| MANAGER_PING | nenhum | P | Tipo de transporte 2; XML ainda não implementado |
| MANAGER_END | nenhum | P | EndManager/tipo 0; nunca usado no cleanup do cliente |

Parâmetros futuros são nomes semânticos, não promessa de formatos aceitos pelo
servidor. A v0.1.1 ainda usa strings; tipagem de valores/IDs deve evoluir antes
de habilitar edição de variáveis ou suporte a múltiplas conexões.
O console só aceita comandos sem argumentos nesta fase; EXECUTE é disparado
pelo modo `--run` e usa a chamada do arquivo de configuração.

## Mensagens de transporte e operações internas

Não expor todas as mensagens do servidor como comandos do usuário.

| Família | Mensagens conhecidas | Uso na v0.1.1 |
| --- | --- | --- |
| Cliente/manager | EndManager=0, Ping=2, InitializeClient=10, SendClientCommands=20, manager commands=25, RecvClientReports=30, TerminateClient=40 | 10/25/30/40 implementados |
| Envelopes | ClientRequest, ConnectionRequest, RoutineRequests, SendClientCommands | Dois primeiros implementados; demais pendentes |
| Agrupamentos | SendVarCommands, SendBkPtCommands | Tokens do manager; não implementados |
| Runtime | PreEnterRoutine=1000, EnterRoutine=1010, ExitRoutine=1020, InitializeRoutine=1030, PutDebugReports=1040, PutMgrDebugReports=1041, GetDebugCommands=1050, TerminateRoutine=1060 | Pertencem ao runtime Informix; cliente não os envia |
| Gestão runtime | SetMgrInfo=1070, GetMgrInfo=1080, PingMgr=1090, SetPortRange=1100, ReservePort=1110, ReserveAlternatePort=1120, ReleasePort=1130 | Fora da POC; cliente não os envia |

## Reports/eventos

Reports identificados incluem AtLine, AtBreak, AtBreakPt, AtException, Failure,
AddRoutine, CallStack, StackFrame, VarDefine, VarValue, RoutineText, LineMap,
Diagnostics/DiagVar, TimedOut e eventos de entrada/saída. Não são comandos.

O motor reconhece parada por AtLine/AtBreakPt/AtBreak e falhas por
AtException/Failure. Identifica presença de AddRoutine/CallStack/RoutineText/LineMap,
mas não decodifica fonte/stack/variáveis. Outros elementos são percorridos para
encontrar eventos conhecidos; conteúdo não é apresentado como suporte funcional.
Não deduzir linha/routineID quando o report não os fornecer.

Eventos locais de ciclo de vida: READY, CALL_STARTED, ENTRY_STEP_REQUESTED, CONTINUED, CALL_COMPLETED,
FAILED, DEBUGINFO_CLEARED, ROLLBACK_COMPLETED, JDBC_CLOSED, CLIENT_TERMINATED,
CLOSED e falhas de cleanup. Cada evento inclui timestamp e identificadores.

## Contrato interno e evolução

Request contém id, enum command e mapa arguments. Response preserva requestID,
success, code e data. Event é independente da resposta: ACCEPTED não significa
que a rotina terminou. O núcleo não imprime, colore nem lê teclado.

Futura ponte JSON e DAP devem traduzir estes objetos, sem colocar PSMD/JCC no
Python. Não implementar simultaneidade entre frontends sobre a mesma sessão
na primeira versão. Não incluir funções de edição de fonte ou migração de banco.
