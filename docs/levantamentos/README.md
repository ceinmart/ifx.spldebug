<!-- v1.2.0 | 2026-09-14T19:49:58Z | Atualizado com auxílio de ChatGPT. -->
# Levantamentos técnicos

Esta pasta mantém apenas resultados resumidos de engenharia reversa e inventários úteis para futuras implementações.

Os dumps integrais de `javap`, bytecode e demais conteúdos extraídos de componentes IBM/HCL **não são versionados** neste repositório, para evitar redistribuição desnecessária de material proprietário.

O documento consolidado e normativo do projeto permanece em [`../architecture.md`](../architecture.md).

## Conteúdo inicial

- `x20-additional-classes.txt`: classes adicionais identificadas como relevantes no componente Stored Procedure Debugger do ODS.
- `x20-clientcomposer-methods.txt`: inventário dos métodos públicos/protegidos do `ClientComposer` relacionados ao protocolo PSMD.
- `x20-request-methods.txt`: inventário dos métodos de `RequestToSessionManager`.
- `x21-supported-routines.md`: coleta estática para localizar a implementação de `RoutineService` e derivar `psmd.supported.types` sem executar o ODS.
- `x22-routine-service-providers.md`: identifica os provedores de `IRoutineService` e confirma `0:4,1:4` para Informix SPL.

Esses arquivos são referências de levantamento; não constituem API pública nem contrato estável do projeto.
