<!-- v1.1.0 | 2026-09-13T19:22:10Z | Atualizado com auxílio de ChatGPT. -->
# Levantamentos técnicos

Esta pasta mantém apenas resultados resumidos de engenharia reversa e inventários úteis para futuras implementações.

Os dumps integrais de `javap`, bytecode e demais conteúdos extraídos de componentes IBM/HCL **não são versionados** neste repositório, para evitar redistribuição desnecessária de material proprietário.

O documento consolidado e normativo do projeto permanece em [`../architecture.md`](../architecture.md).

## Conteúdo inicial

- `x20-additional-classes.txt`: classes adicionais identificadas como relevantes no componente Stored Procedure Debugger do ODS.
- `x20-clientcomposer-methods.txt`: inventário dos métodos públicos/protegidos do `ClientComposer` relacionados ao protocolo PSMD.
- `x20-request-methods.txt`: inventário dos métodos de `RequestToSessionManager`.
- `x21-supported-routines.md`: coleta estática para localizar a implementação de `RoutineService` e derivar `psmd.supported.types` sem executar o ODS.

Esses arquivos são referências de levantamento; não constituem API pública nem contrato estável do projeto.
