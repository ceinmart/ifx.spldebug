/* v0.1.3 | 2026-09-15T17:27:25Z | Atualizado com auxílio de ChatGPT.
 * Núcleo sem terminal: executa JDBC em worker próprio e recebe reports em outro.
 * API interna estruturada para console, futura ponte Python e futuro DAP.
 */
package ifx.spldebug;

import java.io.*;
import java.lang.management.ManagementFactory;
import java.lang.reflect.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Consumer;
import org.w3c.dom.*;
import static ifx.spldebug.Commands.*;

public final class Engine implements AutoCloseable {
    public enum State { NEW, READY, RUNNING, STOPPED, COMPLETED, FAILED, CLOSED }
    private final Config config;
    private final Consumer<Event> sink;
    private final ExecutorService jdbcWorker=worker("spldbg-jdbc"), reportsWorker=worker("spldbg-reports");
    private final String clientID, connectionID="1", pid;
    private volatile State state=State.NEW;
    private volatile boolean closing, registered, sawStop, continued;
    private volatile boolean connectionSeen, entryRequested;
    private volatile String routineID="", line="", failure="";
    private final CountDownLatch runtimeRegistered=new CountDownLatch(1);
    private Connection connection;
    private Future<?> execution, poll;

    public Engine(Config config,Consumer<Event> sink) {
        this.config=config; this.sink=sink;
        pid=ManagementFactory.getRuntimeMXBean().getName().split("@")[0];
        if(!pid.matches("[0-9]+")) throw new IllegalStateException("NUMERIC_PID_UNAVAILABLE");
        // Contrato observado: clientID precisa coincidir com I e P de CLIENT DEBUGINFO.
        clientID=config.required("client.ip")+":"+pid;
    }
    private static ExecutorService worker(String name) {
        return Executors.newSingleThreadExecutor(r -> { Thread t=new Thread(r,name); t.setDaemon(true); return t; });
    }
    public State state() { return state; }
    public boolean passed() { return state==State.COMPLETED&&sawStop&&continued; }
    public String failure() { return failure; }
    private void emit(String type) { sink.accept(new Event(type,clientID,connectionID,routineID,line)); }
    private Psmd.Frame exchange(int type,String xml) throws Exception {
        Psmd.Frame frame=Psmd.exchange(config.required("sm.host"),config.number("sm.port",4554,1,65535),config.timeout(),type,xml);
        emit("PSMD_REPLY_type="+type+"_F0="+frame.flags+"_xml="+frame.data.length+"_bin="+frame.binary.length);
        return frame;
    }
    public Response dispatch(Request request) {
        if(request.command.status!=Status.IMPLEMENTED_EXPERIMENTAL)
            return new Response(request.id,false,"NOT_IMPLEMENTED");
        try {
            switch(request.command) {
                case CAPABILITIES:
                    Map<String,String> catalog=new LinkedHashMap<>();
                    for(Command c:Command.values()) catalog.put(c.name(),c.status+";"+c.parameters);
                    return new Response(request.id,true,"CATALOG_V0.1.1",catalog);
                case STATUS:
                    Map<String,String> details=new LinkedHashMap<>();
                    details.put("clientID",clientID); details.put("connectionID",connectionID);
                    details.put("routineID",routineID); details.put("line",line);
                    return new Response(request.id,true,state.name(),details);
                case INITIALIZE: initialize(); break;
                case EXECUTE: execute(request.arguments.containsKey("call")?request.arguments.get("call"):config.call()); break;
                case CONTINUE: resume(); break;
                case DISCONNECT: close(); break;
                default: return new Response(request.id,false,"NOT_IMPLEMENTED");
            }
            return new Response(request.id,true,"ACCEPTED");
        } catch(Exception e) {
            String code=errorCode(e);
            emit("COMMAND_FAILED_"+request.command+"_"+code);
            return new Response(request.id,false,code);
        }
    }
    private synchronized void initialize() throws Exception {
        if(closing||state!=State.NEW) throw new IllegalStateException("INVALID_STATE");
        config.validate();
        // Mesmo se a resposta se perder, tentar TerminateClient no cleanup.
        registered=true;
        exchange(10,Psmd.initialize(clientID,config.required("psmd.supported.types")));
        exchange(25,Psmd.options(clientID));
        state=State.READY; emit("READY");
    }
    private synchronized void execute(String sql) throws Exception {
        if(closing||state!=State.READY) throw new IllegalStateException("INVALID_STATE");
        String url=config.required("jdbc.url"), user=config.required("jdbc.user");
        if(!url.startsWith("jdbc:db2:")) throw new IllegalArgumentException("JCC_DRDA_URL_REQUIRED");
        String password=System.getenv("SPLDBG_PASSWORD");
        if(password==null) throw new IllegalArgumentException("MISSING_ENV_SPLDBG_PASSWORD");
        Class.forName("com.ibm.db2.jcc.DB2Driver");
        state=State.RUNNING;
        poll=reportsWorker.submit(() -> {
            try {
                while(!closing&&state!=State.COMPLETED&&state!=State.FAILED) {
                    Psmd.Frame f=exchange(30,Psmd.client(clientID,"RecvClientReports"));
                    if(f.data.length>0) consume(Psmd.parse(f.data).getDocumentElement(),"","");
                    synchronized(this) {
                        // ConnectionRequest antes de EnterRoutine retorna -120 no manager observado.
                        if(connectionSeen&&!entryRequested&&!sawStop&&state==State.RUNNING&&!closing) {
                            exchange(25,Psmd.execution(clientID,connectionID,"StepInto"));
                            entryRequested=true; emit("ENTRY_STEP_REQUESTED");
                        }
                    }
                    // Proteção contra manager retornando imediatamente sem reports.
                    if(f.data.length==0) Thread.sleep(50);
                }
            } catch(Exception e) { if(!closing) fail(e); }
        });
        execution=jdbcWorker.submit(() -> {
            boolean marked=false;
            try {
                DriverManager.setLoginTimeout(config.timeout()/1000);
                connection=DriverManager.getConnection(url,user,password);
                connection.setAutoCommit(false);
                marked=true;
                setDebugInfo(connection,debugInfo());
                emit("DEBUGINFO_APPLIED");
                if(closing||state==State.FAILED) throw new IllegalStateException("EXECUTION_CANCELLED");
                emit("CALL_STARTED");
                try(Statement statement=connection.createStatement()) {
                    boolean result=statement.execute(sql);
                    // Drena todos os resultados sem registrar valores ou SQL no output.
                    while(true) {
                        if(result) try(ResultSet rows=statement.getResultSet()) { while(rows.next()) {} }
                        else if(statement.getUpdateCount()==-1) break;
                        result=statement.getMoreResults(Statement.CLOSE_CURRENT_RESULT);
                    }
                }
                if(!closing&&state!=State.FAILED) {
                    if(!connectionSeen&&config.runtimeRegistrationGrace()>0)
                        runtimeRegistered.await(config.runtimeRegistrationGrace(),TimeUnit.MILLISECONDS);
                    if(!connectionSeen) fail(new IOException("NO_DEBUG_RUNTIME_REGISTRATION"));
                    else if(!sawStop) fail(new IOException("NO_DEBUG_STOP_EVENT"));
                    else { state=State.COMPLETED; emit("CALL_COMPLETED"); }
                }
            } catch(Exception e) { if(!closing) fail(e); }
            finally {
                if(connection!=null) {
                    if(marked) try { setDebugInfo(connection,"M0:0,I0,P0,T0,C0,L0"); emit("DEBUGINFO_CLEARED"); }
                    catch(Exception e) { failCleanup(e); }
                    // A POC não confirma alterações feitas pela rotina.
                    try { connection.rollback(); emit("ROLLBACK_COMPLETED"); } catch(Exception e) { failCleanup(e); }
                    try { connection.close(); emit("JDBC_CLOSED"); } catch(Exception e) { failCleanup(e); }
                }
            }
        });
    }
    private String debugInfo() {
        return "M"+config.required("sm.host")+":"+config.number("sm.port",4554,1,65535)+",I"+config.required("client.ip")+",P"+pid+",T789,C"+connectionID+",L0";
    }
    private static void setDebugInfo(Connection c,String value) throws Exception {
        Class<?> api=Class.forName("com.ibm.db2.jcc.DB2Connection");
        Object target=api.isInstance(c)?c:c.unwrap(api);
        try { api.getMethod("setDB2ClientDebugInfo",String.class).invoke(target,value); }
        catch(InvocationTargetException e) { if(e.getCause() instanceof Exception) throw (Exception)e.getCause(); throw e; }
    }
    /** Herdar IDs de containers, mas nunca inventar linha/routineID se ausentes. */
    private void consume(Element element,String inheritedConnection,String inheritedRoutine) throws Exception {
        String c=element.hasAttribute("connectionID")?element.getAttribute("connectionID"):inheritedConnection;
        String r=element.hasAttribute("rid")?element.getAttribute("rid"):inheritedRoutine;
        String name=element.getTagName();
        if(element.hasAttribute("clientID")&&!element.getAttribute("clientID").equals(clientID)) throw new IOException("REPORT_CLIENT_MISMATCH");
        if(!c.isEmpty()&&!c.equals(connectionID)) throw new IOException("REPORT_CONNECTION_MISMATCH");
        if(c.equals(connectionID)) { connectionSeen=true; runtimeRegistered.countDown(); }
        if(name.equals("Failure")) throw new IOException("PSMD_REPORT_FAILURE");
        if(name.equals("AtException")) throw new IOException("PSMD_AT_EXCEPTION");
        if(name.equals("AtLine")||name.equals("AtBreakPt")||name.equals("AtBreak")) {
            synchronized(this) {
                if(!closing&&(state==State.RUNNING||state==State.STOPPED)) {
                    routineID=r; line=element.getAttribute("line"); sawStop=true;
                    state=State.STOPPED; emit(name);
                }
            }
        } else if(name.equals("RoutineText")||name.equals("LineMap")||name.equals("AddRoutine")||name.equals("CallStack")) {
            sink.accept(new Event(name,clientID,c,r,""));
        }
        for(Node child=element.getFirstChild();child!=null;child=child.getNextSibling())
            if(child instanceof Element) consume((Element)child,c,r);
    }
    private synchronized void resume() throws Exception {
        if(closing||state!=State.STOPPED) throw new IllegalStateException("INVALID_STATE");
        exchange(25,Psmd.execution(clientID,connectionID,"Run"));
        continued=true;
        // O CALL pode terminar antes de chegar a confirmação de Run.
        if(state==State.STOPPED) state=State.RUNNING;
        emit("CONTINUED");
    }
    private void fail(Exception e) { failure=errorCode(e); state=State.FAILED; emit("FAILED_"+failure); }
    private void failCleanup(Exception e) { failure="CLEANUP_"+errorCode(e); state=State.FAILED; emit(failure); }
    static String errorCode(Exception e) {
        if(e instanceof SQLException) {
            SQLException s=(SQLException)e; return "SQLSTATE_"+s.getSQLState()+"_CODE_"+s.getErrorCode();
        }
        String msg=e.getMessage();
        boolean safe=msg!=null&&(msg.matches("[A-Z0-9_.:-]{1,120}")||msg.matches("(?:MISSING_CONFIG|INVALID_CONFIG)_[a-z.]{1,50}"));
        return safe?msg:e.getClass().getSimpleName();
    }
    @Override public void close() throws IOException {
        synchronized(this) { if(closing||state==State.CLOSED) return; closing=true; }
        Exception problem=null;
        if(registered) {
            if(connectionSeen&&execution!=null&&!execution.isDone()) {
                try { exchange(25,Psmd.execution(clientID,connectionID,"Terminate")); }
                catch(Exception e) { problem=e; }
            }
            try { exchange(40,Psmd.client(clientID,"TerminateClient")); registered=false; emit("CLIENT_TERMINATED"); }
            catch(Exception e) { problem=e; }
        }
        reportsWorker.shutdownNow(); jdbcWorker.shutdown();
        try {
            if(!jdbcWorker.awaitTermination(10,TimeUnit.SECONDS)) {
                problem=new IOException("JDBC_CLEANUP_TIMEOUT"); jdbcWorker.shutdownNow();
            }
            if(!reportsWorker.awaitTermination(config.timeout()+1000L,TimeUnit.MILLISECONDS)) problem=new IOException("REPORT_CLEANUP_TIMEOUT");
        } catch(InterruptedException e) { Thread.currentThread().interrupt(); problem=new IOException("CLEANUP_INTERRUPTED"); }
        if(problem!=null) { failCleanup(problem); throw new IOException(failure); }
        if(!failure.isEmpty()) throw new IOException(failure);
        state=State.CLOSED; emit("CLOSED");
    }
}
