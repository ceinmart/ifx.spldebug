/* v0.1.3 | 2026-09-15T17:27:25Z | Atualizado com auxílio de ChatGPT.
 * Configuração externa. Nenhuma credencial ou SQL é impresso automaticamente.
 */
package ifx.spldebug;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

public final class Config {
    private final Properties values;
    public Config(Properties values) { this.values=new Properties(); this.values.putAll(values); }
    public static Config load(String file) throws IOException {
        Properties p=new Properties();
        try(Reader r=Files.newBufferedReader(Paths.get(file),StandardCharsets.UTF_8)) { p.load(r); }
        return new Config(p);
    }
    public String required(String key) {
        String s=values.getProperty(key,"").trim();
        if(s.isEmpty()) throw new IllegalArgumentException("MISSING_CONFIG_"+key);
        return s;
    }
    public int number(String key,int fallback,int min,int max) {
        int n=Integer.parseInt(values.getProperty(key,Integer.toString(fallback)).trim());
        if(n<min||n>max) throw new IllegalArgumentException("INVALID_CONFIG_"+key);
        return n;
    }
    public int timeout() { return number("socket.timeout.ms",10000,3000,60000); }
    public int runtimeRegistrationGrace() { return number("runtime.registration.grace.ms",1000,0,10000); }
    // O runtime Informix observado trata L como chave de trace; limitar a 0/1 na POC.
    public int debugTraceLevel() { return number("debug.trace.level",0,0,1); }
    public String call() throws IOException {
        String sql=new String(Files.readAllBytes(Paths.get(required("call.file"))),StandardCharsets.UTF_8).trim();
        if(sql.endsWith(";")) sql=sql.substring(0,sql.length()-1).trim();
        if(!sql.matches("(?is)^(CALL|EXECUTE\\s+(PROCEDURE|FUNCTION))\\s+.*"))
            throw new IllegalArgumentException("CALL_FILE_MUST_CONTAIN_ONE_ROUTINE_INVOCATION");
        return sql;
    }
    public void validate() {
        required("sm.host"); number("sm.port",4554,1,65535); timeout();
        runtimeRegistrationGrace(); debugTraceLevel();
        number("run.timeout.seconds",60,1,3600);
        String ip=required("client.ip");
        if(!ip.matches("[0-9]{1,3}(\\.[0-9]{1,3}){3}")) throw new IllegalArgumentException("CLIENT_IPV4_REQUIRED");
        for(String n:ip.split("\\.")) if(Integer.parseInt(n)>255) throw new IllegalArgumentException("INVALID_CLIENT_IPV4");
        // Obter com discover-supported-types-v0.1.1.sh; nunca deduzir de T789.
        Psmd.initialize("validate",required("psmd.supported.types"));
        String host=required("sm.host");
        if(!host.matches("[A-Za-z0-9.-]+")) throw new IllegalArgumentException("SM_HOST_DNS_OR_IPV4_REQUIRED");
    }
}
