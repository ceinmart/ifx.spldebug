# ifx.spldebug

<!-- v0.1.0 | 2026-09-11T12:34:07Z | Atualizado com auxílio de ChatGPT. -->

`ifx.spldebug` é um projeto experimental para construir um debugger interativo de **SPL do IBM/HCL Informix**, inicialmente como cliente texto e, após validação do protocolo, como base para integração com o VS Code por meio de um Debug Adapter.

O projeto busca reproduzir, de forma independente, o fluxo de depuração utilizado pelas ferramentas IBM: conexão DRDA/JCC, `SET CLIENT DEBUGINFO`, Session Manager (`db2dbgm.jar`) e protocolo PSMD.

## Escopo inicial

- validar uma POC mínima de depuração SPL;
- conectar ao Session Manager;
- iniciar uma sessão de debug via JCC/DRDA;
- executar uma stored procedure;
- receber eventos de linha/breakpoint;
- suportar `continue`, `step`, breakpoints, stack e variáveis de forma incremental;
- posteriormente expor o mecanismo por um VS Code Debug Adapter.

## Dependências externas

O repositório **não deve distribuir** JARs, binários ou código proprietário da IBM/HCL. Componentes como `db2jcc4.jar` e `db2dbgm.jar` devem ser obtidos pelo usuário a partir de instalações/licenças válidas do Informix ou dos respectivos produtos IBM/HCL.

## Licença

O código e a documentação originais deste repositório são disponibilizados sob a **MIT License**. Essa licença não se aplica a componentes, bibliotecas, protocolos documentados por terceiros ou artefatos IBM/HCL eventualmente necessários em tempo de execução.

Veja também [`docs/architecture.md`](docs/architecture.md) para o levantamento técnico consolidado.

## Primeira versão: 0.1.0 experimental

Motor Java, console texto e scripts estão implementados. Compilação e testes
locais foram executados com OpenJDK 17, gerando classes compatíveis com Java 8.
**Ainda não foi executada integração com Informix/JCC.** O par numérico
`psmd.supported.types` do SPL Informix continua pendente de confirmação; não há
valor padrão inventado. Sem esse dado, os testes de integração param no preflight.

- [Compilar e testar no servidor](docs/poc-v0.1.0.md)
- [Catálogo de comandos e pendências](docs/commands.md)
- [Resultados versionáveis](bin/outputs/README.md)

Para verificar a versão sem banco, executar `bash bin/test-v0.1.0.sh`.
O script compila, executa testes locais e lista todos os comandos/status.
Não precisa de JAR IBM nem acesso à internet nesse teste.
