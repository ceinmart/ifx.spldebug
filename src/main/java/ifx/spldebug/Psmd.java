/* v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
 * Implementação própria de framing e XML baseada nos contratos observados x18/x20.
 */
package ifx.spldebug;

import java.io.*;
import java.net.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import javax.xml.parsers.*;
import org.w3c.dom.*;
import org.xml.sax.SAXException;
import org.xml.sax.helpers.DefaultHandler;

public final class Psmd {
    static final int MAX_FRAME=8*1024*1024;
    public static String escape(String s) {
        return s.replace("&","&amp;").replace("\"","&quot;").replace("<","&lt;").replace(">","&gt;").replace("'","&apos;");
    }
    static String envelope(String body) {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?><PSMDRequest version=\"3.3\">"+body+"</PSMDRequest>";
    }
    public static String initialize(String id, String pairs) {
        StringBuilder routines=new StringBuilder();
        for(String pair:pairs.split(",",-1)) {
            if(!pair.matches("[0-9]+:[0-9]+")) throw new IllegalArgumentException("PSMD_TYPES_REQUIRED_TYPE_LANGUAGE");
            String[] p=pair.split(":");
            routines.append("<Routine type=\"").append(p[0]).append("\" language=\"").append(p[1]).append("\"/>");
        }
        return envelope("<InitializeClient clientID=\""+escape(id)+"\"><SupportedRoutines>"+routines+"</SupportedRoutines></InitializeClient>");
    }
    public static String client(String id, String operation) {
        if(!operation.equals("TerminateClient")&&!operation.equals("RecvClientReports")) throw new IllegalArgumentException("INVALID_OPERATION");
        return envelope("<"+operation+" clientID=\""+escape(id)+"\""+(operation.equals("RecvClientReports")?" timeout=\"2000\"":"")+"/>");
    }
    public static String options(String id) {
        return envelope("<ClientRequest clientID=\""+escape(id)+"\"><Options sessionTimeout=\"300\"/></ClientRequest>");
    }
    public static String execution(String id, String connection, String op) {
        if(!op.equals("StepInto")&&!op.equals("Run")&&!op.equals("Terminate")) throw new IllegalArgumentException("INVALID_OPERATION");
        return envelope("<ConnectionRequest clientID=\""+escape(id)+"\" connectionID=\""+escape(connection)+"\"><"+op+"/></ConnectionRequest>");
    }
    public static Document parse(byte[] xml) throws Exception {
        DocumentBuilderFactory f=DocumentBuilderFactory.newInstance();
        f.setFeature("http://apache.org/xml/features/disallow-doctype-decl",true);
        f.setFeature("http://xml.org/sax/features/external-general-entities",false);
        f.setFeature("http://xml.org/sax/features/external-parameter-entities",false);
        f.setXIncludeAware(false); f.setExpandEntityReferences(false);
        DocumentBuilder b=f.newDocumentBuilder();
        b.setErrorHandler(new DefaultHandler() { @Override public void fatalError(org.xml.sax.SAXParseException e) throws SAXException { throw e; } });
        return b.parse(new ByteArrayInputStream(xml));
    }
    public static final class Frame {
        public final int type, flags;
        public final byte[] message, data, binary;
        Frame(int type,int flags,byte[] message,byte[] data,byte[] binary) {
            this.type=type; this.flags=flags; this.message=message; this.data=data; this.binary=binary;
        }
    }
    public static byte[] encode(int type,String xml) throws IOException {
        byte[] bytes=xml.getBytes(StandardCharsets.UTF_8);
        if(bytes.length>MAX_FRAME) throw new IOException("FRAME_TOO_LARGE");
        ByteBuffer b=ByteBuffer.allocate(20+bytes.length).order(ByteOrder.BIG_ENDIAN);
        b.putShort((short)0xDB2D).putShort((short)type).putInt(bytes.length).putInt(0).putInt(0).putInt(0).put(bytes);
        return b.array();
    }
    public static Frame read(InputStream input) throws IOException {
        DataInputStream in=new DataInputStream(input);
        byte[] header=new byte[20]; in.readFully(header);
        ByteBuffer b=ByteBuffer.wrap(header);
        int marker=b.getShort()&65535;
        if(marker==0x2DDB) b.order(ByteOrder.LITTLE_ENDIAN);
        else if(marker!=0xDB2D) throw new IOException("INVALID_BYTE_ORDER");
        int type=b.getShort()&65535, m=b.getInt(),d=b.getInt(),n=b.getInt(),flags=b.getInt();
        if(m<0||d<0||n<0||(long)m+d+n>MAX_FRAME) throw new IOException("INVALID_FRAME_LENGTH");
        byte[] msg=new byte[m],data=new byte[d],bin=new byte[n];
        in.readFully(msg); in.readFully(data); in.readFully(bin);
        return new Frame(type,flags,msg,data,bin);
    }
    /** Um socket por round-trip: polling nunca compartilha o stream dos comandos. */
    public static Frame exchange(String host,int port,int timeout,int type,String xml) throws Exception {
        try(Socket s=new Socket()) {
            s.connect(new InetSocketAddress(host,port),timeout); s.setSoTimeout(timeout);
            s.getOutputStream().write(encode(type,xml)); s.getOutputStream().flush();
            Frame f=read(s.getInputStream()); checkReply(f); return f;
        }
    }
    static void checkReply(Frame f) throws Exception {
        if(f.message.length==0) throw new IOException("MISSING_PSMD_REPLY");
        Document doc=parse(f.message);
        NodeList replies=doc.getElementsByTagName("Reply");
        if(!doc.getDocumentElement().getTagName().equals("PSMDReply")||replies.getLength()!=1) throw new IOException("UNEXPECTED_PSMD_REPLY");
        Element reply=(Element)replies.item(0);
        if(!reply.hasAttribute("rc")) throw new IOException("MISSING_RC");
        int rc=Integer.parseInt(reply.getAttribute("rc"));
        if(rc!=0) throw new IOException("PSMD_RC_"+rc);
    }
    private Psmd() {}
}
