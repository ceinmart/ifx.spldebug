/* v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
 * Console mínimo; a renderização fica aqui e não no motor de depuração.
 */
package ifx.spldebug;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import static ifx.spldebug.Commands.*;

public final class Main {
    public static final String VERSION="0.1.0";
    public static void main(String[] args) {
        int rc;
        try { rc=run(args); }
        catch(Exception e) { System.err.println("FAIL "+Engine.errorCode(e)); rc=1; }
        System.exit(rc);
    }
    private static int run(String[] args) throws Exception {
        if(args.length==0||args[0].equals("--help")) {
            System.out.println("spldbg v"+VERSION+"\n--catalog | --probe CONFIG | --run CONFIG [--auto]\nConsole: continue, status, capabilities, quit; demais nomes do catálogo retornam NOT_IMPLEMENTED.");
            return 0;
        }
        if(args[0].equals("--catalog")) { catalog(); return 0; }
        if(args.length<2||args.length>3||(!args[0].equals("--run")&&!args[0].equals("--probe"))||
                (args.length==3&&!args[2].equals("--auto"))) throw new IllegalArgumentException("INVALID_ARGUMENTS");
        Config config=Config.load(args[1]); config.validate();
        boolean auto=args.length==3;
        boolean probe=args[0].equals("--probe");
        BlockingQueue<String> input=new LinkedBlockingQueue<>();
        if(!auto&&!probe) {
            Thread reader=new Thread(() -> {
                try(BufferedReader in=new BufferedReader(new InputStreamReader(System.in,StandardCharsets.UTF_8))) {
                    String s; while((s=in.readLine())!=null) input.put(s.trim());
                    input.put("quit");
                } catch(Exception e) { input.offer("quit"); }
            },"spldbg-console"); reader.setDaemon(true); reader.start();
        }
        Engine engine=new Engine(config,Main::printEvent);
        Thread hook=new Thread(() -> { try { engine.close(); } catch(Exception e) { System.err.println("CLEANUP_FAILED "+Engine.errorCode(e)); } },"spldbg-cleanup");
        Runtime.getRuntime().addShutdownHook(hook);
        boolean passed=false;
        try {
            require(engine,Command.INITIALIZE);
            if(probe) passed=true;
            else {
                require(engine,Command.EXECUTE);
                long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(config.number("run.timeout.seconds",60,1,3600));
                while(engine.state()!=Engine.State.COMPLETED&&engine.state()!=Engine.State.FAILED) {
                    if(System.nanoTime()>deadline) throw new IOException("RUN_TIMEOUT");
                    if(auto&&engine.state()==Engine.State.STOPPED) require(engine,Command.CONTINUE);
                    String command=input.poll(50,TimeUnit.MILLISECONDS);
                    if(command!=null) {
                        if(command.equalsIgnoreCase("quit")) break;
                        if(command.equalsIgnoreCase("capabilities")) { catalog(); continue; }
                        try {
                            Command c=Command.valueOf(command.toUpperCase(Locale.ROOT));
                            // INITIALIZE/EXECUTE são dirigidos pelo ciclo --run nesta versão.
                            if(c==Command.INITIALIZE||c==Command.EXECUTE||c==Command.DISCONNECT) System.out.println("USE_RUN_OR_QUIT");
                            else { Response r=engine.dispatch(request(c)); System.out.println("RESPONSE "+r.requestID+" "+r.success+" "+r.code); }
                        } catch(IllegalArgumentException e) { System.out.println("UNKNOWN_COMMAND"); }
                    }
                }
                passed=engine.passed();
            }
        } finally {
            try { engine.close(); } finally { Runtime.getRuntime().removeShutdownHook(hook); }
        }
        System.out.println((passed?"PASS ":"FAIL ")+(probe?"SESSION_MANAGER_PROBE":"INFORMIX_POC_STOP_CONTINUE_COMPLETE_CLEANUP"));
        return passed?0:1;
    }
    private static Request request(Command c) { return new Request(UUID.randomUUID().toString(),c,Collections.emptyMap()); }
    private static void require(Engine engine,Command command) throws IOException {
        Response r=engine.dispatch(request(command)); if(!r.success) throw new IOException(r.code);
    }
    static void catalog() {
        System.out.println("command\tstatus\tparameters");
        for(Command c:Command.values()) System.out.println(c+"\t"+c.status+"\t"+c.parameters);
    }
    private static String safe(String s) { return s.replaceAll("[^A-Za-z0-9_.:=/-]","?"); }
    private static synchronized void printEvent(Event e) {
        System.out.println(Instant.now()+" "+safe(e.type)+" clientID="+safe(e.clientID)+" connectionID="+safe(e.connectionID)+" routineID="+safe(e.routineID)+" line="+safe(e.line));
    }
}
