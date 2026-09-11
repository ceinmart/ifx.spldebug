# AGENTS.md

**Versão:** 1.0  
**Data:** 2026-09-11  
**Criado por:** ChatGPT / GPT-5.6 Sol

Regras para qualquer agente ou assistente que trabalhe neste repositório.

## Escopo

- O projeto é dedicado exclusivamente ao **IBM/HCL Informix SPL Debugger**.
- O alvo principal é Informix 14.10 em Linux.
- Não introduzir comparações ou dependências de outros SGBDs, exceto quando indispensáveis para explicar componentes IBM usados pelo próprio mecanismo de debug.

## Ordem de implementação

- Primeiro validar uma **POC mínima em modo texto**, semelhante a um debugger de linha de comando.
- Não iniciar integração VS Code/DAP antes de o fluxo básico PSMD funcionar ponta a ponta.
- A POC mínima deve priorizar: Session Manager -> InitializeClient -> DRDA/JCC -> `CLIENT DEBUGINFO` -> execução de SPL -> primeiro evento de linha/breakpoint -> continue -> cleanup.
- Recursos como stack, variáveis, alteração de variáveis e breakpoints avançados entram somente após a POC básica.

## Evidência técnica

- Separar claramente fatos confirmados por documentação/bytecode de hipóteses ainda não validadas em execução real.
- Não inventar funções, procedures, parâmetros ou formatos do Informix.
- Quando um ponto estiver incerto, documentar a incerteza explicitamente.
- Atualizar `docs/architecture.md` quando um teste real confirmar ou invalidar uma hipótese relevante.

## Dependências proprietárias

- **Nunca commitar ou redistribuir** `db2jcc4.jar`, `db2dbgm.jar`, componentes do ODS, binários ou código decompilado IBM/HCL.
- O projeto pode depender desses componentes em runtime desde que o usuário forneça uma instalação/licença válida.
- O cliente PSMD deve ser implementação própria, baseada em comportamento observado e documentação, sem copiar código proprietário.

## Estrutura do repositório

- `src/`: código-fonte do projeto.
- `bin/`: artefatos compilados ou executáveis gerados pelo projeto.
- `docs/`: documentação técnica consolidada.
- `docs/levantamentos/`: apenas resultados de levantamento que sejam úteis e seguros de manter; evitar dumps integrais de bytecode/decompilação proprietária.

## Código e documentação

- Novos arquivos relevantes devem conter versão, data e indicação discreta de que foram criados com auxílio de ChatGPT/IA.
- Alterações relevantes incrementam a versão do arquivo/documento.
- Código deve conter comentários suficientes para ser entendido por alguém vendo o projeto pela primeira vez.
- Evitar abstrações prematuras; priorizar código observável e fácil de diagnosticar durante a POC.
- Logs de protocolo devem facilitar correlação por `clientID`, `connectionID` e `routineID`.

## Interação e coleta de evidências

- Quando solicitar arquivos ao mantenedor, listar os nomes **em ordem alfabética**.
- Antes de analisar uma coleta, validar se todos os arquivos solicitados foram recebidos.
- Se algum arquivo esperado estiver ausente, informar explicitamente qual está faltando antes de avançar.
- Arquivo com zero bytes pode ser aceito quando o próprio resultado esperado for vazio; registrar isso explicitamente.

## Commits

- Preferir commits pequenos e focados.
- Usar mensagens objetivas, por exemplo: `docs: ...`, `poc: ...`, `psmd: ...`, `jcc: ...`, `fix: ...`.
- Não incluir segredos, credenciais, tokens, dumps de produção ou dados sensíveis.
