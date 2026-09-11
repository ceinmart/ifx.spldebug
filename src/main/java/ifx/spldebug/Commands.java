/* v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
 * Contrato do projeto, independente de terminal e transporte. Não é a API IBM.
 */
package ifx.spldebug;

import java.util.*;

public final class Commands {
    public enum Status { IMPLEMENTED_EXPERIMENTAL, PENDING, CONTRACT_UNKNOWN }
    public enum Command {
        CAPABILITIES("", Status.IMPLEMENTED_EXPERIMENTAL),
        STATUS("", Status.IMPLEMENTED_EXPERIMENTAL),
        INITIALIZE("config", Status.IMPLEMENTED_EXPERIMENTAL),
        EXECUTE("call", Status.IMPLEMENTED_EXPERIMENTAL),
        CONTINUE("", Status.IMPLEMENTED_EXPERIMENTAL),
        DISCONNECT("", Status.IMPLEMENTED_EXPERIMENTAL),
        PAUSE("connectionID", Status.PENDING),
        STEP_INTO("connectionID", Status.PENDING),
        STEP_OVER("connectionID", Status.PENDING),
        STEP_RETURN("connectionID", Status.PENDING),
        STEP_OUT("connectionID", Status.CONTRACT_UNKNOWN),
        RUN_TO_LINE("connectionID,routineID,line", Status.PENDING),
        END("connectionID", Status.CONTRACT_UNKNOWN),
        TERMINATE("connectionID", Status.PENDING),
        BREAKPOINT_ADD_LINE("routineID,line,enabled,hitMode,hitCount", Status.PENDING),
        BREAKPOINT_ADD_VARIABLE("routineID,variable,condition,hitMode,hitCount", Status.PENDING),
        BREAKPOINT_REMOVE("routineID,breakpointID", Status.PENDING),
        BREAKPOINT_REMOVE_ALL("routineID", Status.PENDING),
        BREAKPOINT_ENABLE("routineID,breakpointID", Status.PENDING),
        BREAKPOINT_DISABLE("routineID,breakpointID", Status.PENDING),
        BREAKPOINT_LIST("routineID", Status.PENDING),
        STACK("connectionID", Status.PENDING),
        FRAME_SELECT("frameID", Status.PENDING),
        VARIABLES("frameID", Status.PENDING),
        VARIABLE_GET("frameID,variableID", Status.PENDING),
        VARIABLE_SET("frameID,variableID,value,type", Status.PENDING),
        VARIABLE_SET_LENGTH("variableID,length", Status.PENDING),
        SOURCE_GET("routineID,origin,path", Status.PENDING),
        SOURCE_MAP("routineID", Status.CONTRACT_UNKNOWN),
        ROUTINES("connectionID", Status.PENDING),
        ROUTINE_ADD("routineID,options", Status.CONTRACT_UNKNOWN),
        OPTIONS("sessionTimeout,maxVarReportSize", Status.PENDING),
        TRACE("scope,mode", Status.CONTRACT_UNKNOWN),
        TRACE_MODE("LineByLine,Variables,Statements,Timings", Status.CONTRACT_UNKNOWN),
        MANAGER_PING("", Status.PENDING),
        MANAGER_END("", Status.PENDING);

        public final String parameters;
        public final Status status;
        Command(String parameters, Status status) { this.parameters=parameters; this.status=status; }
    }

    public static final class Request {
        public final String id;
        public final Command command;
        public final Map<String,String> arguments;
        public Request(String id, Command command, Map<String,String> arguments) {
            this.id=Objects.requireNonNull(id); this.command=Objects.requireNonNull(command);
            this.arguments=Collections.unmodifiableMap(new LinkedHashMap<>(arguments));
        }
    }
    public static final class Response {
        public final String requestID, code;
        public final boolean success;
        public final Map<String,String> data;
        public Response(String id, boolean success, String code) {
            this(id,success,code,Collections.emptyMap());
        }
        public Response(String id, boolean success, String code, Map<String,String> data) {
            this.requestID=id; this.success=success; this.code=code;
            this.data=Collections.unmodifiableMap(new LinkedHashMap<>(data));
        }
    }
    /** Eventos imutáveis: nenhum código ANSI, fonte SQL ou valor de variável nos logs da POC. */
    public static final class Event {
        public final String timestamp=java.time.Instant.now().toString();
        public final String type, clientID, connectionID, routineID, line;
        public Event(String type, String client, String connection, String routine, String line) {
            this.type=type; this.clientID=client; this.connectionID=connection;
            this.routineID=routine; this.line=line;
        }
    }
    private Commands() {}
}
