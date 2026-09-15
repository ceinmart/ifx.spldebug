/* v0.1.6 | 2026-09-15T18:56:54Z | Atualizado com auxílio de ChatGPT.
 * Testes locais com vetores sintéticos declarados. Não simulam validação Informix.
 */
package ifx.spldebug;
import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.net.*;
import java.util.concurrent.*;
import java.util.*;
import org.w3c.dom.*;

public final class ProtocolTest {
    private static int checks;
    interface Action { void run() throws Exception; }
    static void check(boolean ok,String name) { if(!ok) throw new AssertionError(name); checks++; }
    static void rejects(Action a,String name) throws Exception {
        try { a.run(); } catch(Exception expected) { checks++; return; }
        throw new AssertionError("accepted "+name);
    }
    public static void main(String[] args) throws Exception {
        byte[] frame=Psmd.encode(10,"é");
        check(Arrays.equals(Arrays.copyOf(frame,20),new byte[]{(byte)0xdb,0x2d,0,10,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0}),"golden header, UTF8 byte count, F0 zero");
        InputStream fragmented=new FilterInputStream(new ByteArrayInputStream(frame)) {
            @Override public int read(byte[] b,int off,int len) throws IOException { return super.read(b,off,Math.min(1,len)); }
        };
        check(Arrays.equals(Psmd.read(fragmented).message,"é".getBytes(StandardCharsets.UTF_8)),"fragmented TCP read");
        rejects(() -> Psmd.read(new ByteArrayInputStream(Arrays.copyOf(frame,21))),"truncated payload");
        rejects(() -> Psmd.read(new ByteArrayInputStream(new byte[19])),"truncated header");
        byte[] invalid=frame.clone(); invalid[0]=0;
        rejects(() -> Psmd.read(new ByteArrayInputStream(invalid)),"byte order marker");
        ByteBuffer little=ByteBuffer.allocate(23).order(ByteOrder.LITTLE_ENDIAN);
        little.putShort((short)0xdb2d).putShort((short)30).putInt(1).putInt(1).putInt(1).putInt(7).put(new byte[]{1,2,3});
        Psmd.Frame decoded=Psmd.read(new ByteArrayInputStream(little.array()));
        check(decoded.flags==7&&decoded.type==30&&decoded.data[0]==2&&decoded.binary[0]==3,"little endian and all segments");
        ByteBuffer bad=ByteBuffer.wrap(frame.clone()); bad.putInt(4,Integer.MAX_VALUE);
        rejects(() -> Psmd.read(new ByteArrayInputStream(bad.array())),"oversized allocation");
        bad.putInt(4,-1);
        rejects(() -> Psmd.read(new ByteArrayInputStream(bad.array())),"negative length");
        Document init=Psmd.parse(Psmd.initialize("a&\"b","0:4,1:4").getBytes(StandardCharsets.UTF_8));
        check(((Element)init.getElementsByTagName("InitializeClient").item(0)).getAttribute("clientID").equals("a&\"b"),"XML escaping");
        check(init.getElementsByTagName("Routine").getLength()==2,"supported pair list");
        NodeList splRoutines=init.getElementsByTagName("Routine");
        check(((Element)splRoutines.item(0)).getAttribute("type").equals("0")&&
                ((Element)splRoutines.item(0)).getAttribute("language").equals("4")&&
                ((Element)splRoutines.item(1)).getAttribute("type").equals("1")&&
                ((Element)splRoutines.item(1)).getAttribute("language").equals("4"),"observed SPL supported pairs");
        String observed="<PSMDRequest><InitializeClient><SupportedRoutines><Routine language='2' type=\"1\"/>"+
                "<Routine type='3' language=\"4\"/></SupportedRoutines></InitializeClient></PSMDRequest>";
        check(SupportedTypes.discover(Psmd.encode(10,observed)).equals("1:2,3:4"),"discover supported types from framed XML");
        check(SupportedTypes.normalize("1:2, 1:2,3:4").equals("1:2,3:4"),"normalize supported types");
        Path hex=Files.createTempFile("spldbg-supported-types-",".hex");
        try {
            Files.write(hex,Arrays.asList("41:42", "4344"),StandardCharsets.US_ASCII);
            check(Arrays.equals(SupportedTypesDiscovery.decodeHex(hex),new byte[]{65,66,67,68}),"decode tshark payload hex");
        } finally { Files.deleteIfExists(hex); }
        rejects(() -> SupportedTypes.discover("<Routine type='1' language='2'/>".getBytes(StandardCharsets.US_ASCII)),"routine outside SupportedRoutines");
        rejects(() -> Psmd.initialize("x",""),"unknown supported types");
        rejects(() -> Psmd.initialize("x","SQL"),"non-numeric pair");
        check(Engine.errorCode(new java.sql.SQLException("private detail",null,-4228)).equals("SQLSTATE_NULL_CODE_-4228"),"null SQLSTATE remains structured");
        check(Engine.isJccDrdaUrl("jdbc:ids://host:9591/db:securityMechanism=3;"),"preferred Informix JCC URL");
        check(Engine.isJccDrdaUrl("jdbc:db2://host:9591/db:informixType=1;"),"compatible JCC URL");
        check(!Engine.isJccDrdaUrl("jdbc:informix-sqli://host:9088/db"),"reject non-JCC SQLI URL");
        rejects(() -> Psmd.parse("<!DOCTYPE x [<!ENTITY e SYSTEM 'file:///etc/passwd'>]><x>&e;</x>".getBytes(StandardCharsets.UTF_8)),"external entity");
        Psmd.checkReply(new Psmd.Frame(10,0,"<PSMDReply><Reply rc='0'/></PSMDReply>".getBytes(StandardCharsets.UTF_8),new byte[0],new byte[0])); checks++;
        rejects(() -> Psmd.checkReply(new Psmd.Frame(10,0,"<PSMDReply><Reply rc='-141'/></PSMDReply>".getBytes(StandardCharsets.UTF_8),new byte[0],new byte[0])),"remote error");
        // Servidor local de teste de transporte; não representa um Session Manager IBM.
        try(ServerSocket server=new ServerSocket(0,1,InetAddress.getLoopbackAddress())) {
            server.setSoTimeout(3000);
            FutureTask<Boolean> peer=new FutureTask<>(() -> {
                try(Socket socket=server.accept()) {
                    socket.setSoTimeout(3000);
                    Psmd.Frame request=Psmd.read(socket.getInputStream());
                    byte[] reply=Psmd.encode(10,"<PSMDReply><Reply rc='0'/></PSMDReply>");
                    for(byte b:reply) socket.getOutputStream().write(b&255);
                    socket.getOutputStream().flush();
                    return request.type==10&&request.flags==0;
                }
            });
            Thread thread=new Thread(peer,"local-transport-test"); thread.setDaemon(true); thread.start();
            Psmd.exchange(server.getInetAddress().getHostAddress(),server.getLocalPort(),3000,10,Psmd.initialize("local","1:2"));
            check(peer.get(4,TimeUnit.SECONDS),"loopback transport round-trip");
        }
        Properties p=new Properties(); p.setProperty("client.ip","127.0.0.1");
        check(new Config(p).runtimeRegistrationGrace()==1000,"runtime registration grace default");
        check(new Config(p).debugTraceLevel()==0,"debug trace default");
        p.setProperty("debug.trace.level","1");
        check(new Config(p).debugTraceLevel()==1,"debug trace enabled");
        p.setProperty("debug.trace.level","2");
        rejects(() -> new Config(p).debugTraceLevel(),"debug trace limit");
        p.remove("debug.trace.level");
        p.setProperty("runtime.registration.grace.ms","10001");
        rejects(() -> new Config(p).runtimeRegistrationGrace(),"runtime registration grace limit");
        p.remove("runtime.registration.grace.ms");
        try(Engine e=new Engine(new Config(p),event -> {})) {
            check(e.dispatch(new Commands.Request("catalog",Commands.Command.CAPABILITIES,Collections.emptyMap())).data.size()==Commands.Command.values().length,"capabilities completeness");
            for(Commands.Command c:Commands.Command.values()) if(c.status!=Commands.Status.IMPLEMENTED_EXPERIMENTAL) {
                Commands.Response r=e.dispatch(new Commands.Request("test",c,Collections.emptyMap()));
                check(!r.success&&r.code.equals("NOT_IMPLEMENTED")&&r.requestID.equals("test"),"pending command "+c);
            }
            check(!e.dispatch(new Commands.Request("test",Commands.Command.CONTINUE,Collections.emptyMap())).success,"continue outside stop");
        }
        System.out.println("PASS LOCAL_PROTOCOL checks="+checks+"; Informix/JCC não executados");
    }
}
