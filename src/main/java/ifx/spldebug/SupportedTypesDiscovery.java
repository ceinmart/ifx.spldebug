/* v0.1.1 | 2026-09-11T19:30:37Z | Criado com auxílio de ChatGPT.
 * CLI restrita para derivar psmd.supported.types de XML bruto ou tcp.payload.
 */
package ifx.spldebug;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

public final class SupportedTypesDiscovery {
    public static void main(String[] args) throws Exception {
        if(args.length!=2||(!args[0].equals("--raw")&&!args[0].equals("--tshark-hex")))
            throw new IllegalArgumentException("USAGE_RAW_OR_TSHARK_HEX_FILE");
        Path input=Paths.get(args[1]);
        byte[] bytes=args[0].equals("--raw")?Files.readAllBytes(input):decodeHex(input);
        String value=SupportedTypes.discover(bytes);
        System.out.println("DISCOVERY_STATUS=RESOLVED");
        System.out.println("psmd.supported.types="+value);
    }

    static byte[] decodeHex(Path input) throws Exception {
        List<String> lines=Files.readAllLines(input,StandardCharsets.US_ASCII);
        ByteArrayOutputStream result=new ByteArrayOutputStream();
        for(String line:lines) {
            String hex=line.replaceAll("[\\s:]","");
            if(hex.isEmpty()) continue;
            if(!hex.matches("[0-9A-Fa-f]+")||(hex.length()&1)!=0)
                throw new IllegalArgumentException("INVALID_TSHARK_HEX_INPUT");
            for(int i=0;i<hex.length();i+=2) result.write(Integer.parseInt(hex.substring(i,i+2),16));
        }
        return result.toByteArray();
    }

    private SupportedTypesDiscovery() {}
}
