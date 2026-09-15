<!-- v0.1.2 | 2026-09-15T14:10:00Z | Atualizado com auxílio de ChatGPT. -->
# Resultados de compilação e testes

Os scripts salvam logs com versão, data/hora UTC, PID, commit e códigos de saída.
Arquivos `.log` são versionáveis. Após executar no servidor, revisar e commitar
somente os logs necessários; o assistente pode lê-los diretamente no GitHub.

Coletores temporários chamados `x*` e todos os seus outputs são exceção: devem
ser trocados somente pela conversa e nunca adicionados ao repositório.

`supported-types-discovery` contém somente os pares derivados do
`SupportedRoutines`; a captura usada como entrada pode conter dados do ambiente
e nunca deve ser copiada para esta pasta ou commitada.

`test-local` comprova somente testes locais. `SESSION_MANAGER_PROBE` comprova
inicialização/encerramento do manager. Apenas
`INFORMIX_POC_STOP_CONTINUE_COMPLETE_CLEANUP` representa o fluxo de integração.

O processo Java próprio não imprime senha, URL, chamada SQL, fonte nem valores
de variáveis. IDs/IPs aparecem para correlação. Rever mensagens provenientes
da JVM, driver ou manager antes de publicar qualquer log.
Logs IBM `*.private.log` ficam ignorados: podem conter dados de depuração.
Não commitar JARs, dumps proprietários nem configuração local.

Nesta entrega, logs de `run` com `MISSING_CONFIG`/`IllegalArgumentException`
foram testes negativos com a configuração vazia: comprovam retorno não zero e
registro da falha. Não houve tentativa de conexão com Informix nesses testes.
