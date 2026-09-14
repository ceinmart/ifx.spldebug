/* v0.1.1 | 2026-09-11T19:30:37Z | Criado com auxílio de ChatGPT.
 * Valida a configuração type:language e extrai somente esses pares de uma
 * captura do InitializeClient, sem reproduzir o conteúdo proprietário capturado.
 */
package ifx.spldebug;

import java.nio.charset.StandardCharsets;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class SupportedTypes {
    private static final Pattern BLOCK=Pattern.compile(
            "<SupportedRoutines\\b[^>]*>(.*?)</SupportedRoutines\\s*>",
            Pattern.CASE_INSENSITIVE|Pattern.DOTALL);
    private static final Pattern ROUTINE=Pattern.compile("<Routine\\b([^>]*)/?>",Pattern.CASE_INSENSITIVE);
    private static final Pattern TYPE=attribute("type");
    private static final Pattern LANGUAGE=attribute("language");

    private static Pattern attribute(String name) {
        return Pattern.compile("\\b"+name+"\\s*=\\s*(['\\\"])([0-9]+)\\1",Pattern.CASE_INSENSITIVE);
    }

    public static String normalize(String input) {
        Set<String> result=new LinkedHashSet<>();
        for(String raw:input.split(",",-1)) {
            String pair=raw.trim();
            if(!pair.matches("[0-9]+:[0-9]+"))
                throw new IllegalArgumentException("PSMD_TYPES_REQUIRED_TYPE_LANGUAGE");
            String[] values=pair.split(":",-1);
            checkInteger(values[0]); checkInteger(values[1]);
            result.add(values[0]+":"+values[1]);
        }
        if(result.isEmpty()) throw new IllegalArgumentException("PSMD_TYPES_REQUIRED_TYPE_LANGUAGE");
        return String.join(",",result);
    }

    public static String discover(byte[] observedPayload) {
        // ISO-8859-1 mantém relação byte/caractere e tolera o header binário PSMD.
        String text=new String(observedPayload,StandardCharsets.ISO_8859_1);
        Matcher block=BLOCK.matcher(text);
        Set<String> result=new LinkedHashSet<>();
        while(block.find()) {
            Matcher routine=ROUTINE.matcher(block.group(1));
            while(routine.find()) {
                Matcher type=TYPE.matcher(routine.group(1));
                Matcher language=LANGUAGE.matcher(routine.group(1));
                if(type.find()&&language.find()) result.add(type.group(2)+":"+language.group(2));
            }
        }
        if(result.isEmpty()) throw new IllegalArgumentException("SUPPORTED_ROUTINES_NOT_FOUND");
        return normalize(String.join(",",result));
    }

    private static void checkInteger(String value) {
        try { Integer.parseInt(value); }
        catch(NumberFormatException e) { throw new IllegalArgumentException("PSMD_TYPE_OR_LANGUAGE_OUT_OF_RANGE"); }
    }

    private SupportedTypes() {}
}
