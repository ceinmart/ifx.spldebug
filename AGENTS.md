# AGENTS.md

**Versão:** 1.1

**Data:** 2026-09-11T12:34:07Z

**Criado por:** ChatGPT / GPT-5.6 Sol

Regras para qualquer agente ou assistente que trabalhe neste repositório.

## Continuidade Web / Codex

- Ler este arquivo, `README.md`, `docs/architecture.md` e `docs/commands.md` antes de alterar código.
- Motor Java independente de terminal: JDBC/DRDA, PSMD e estado ficam no núcleo.
- Python será uma interface CLI/TUI futura; VS Code terá adaptador DAP próprio.
- Preservar contratos estruturados de solicitação, resposta e evento. Não misturar logs e futuro transporte JSON.
- Manter TODOS os comandos conhecidos no catálogo, incluindo pendentes. Distinguir recurso implementado, planejado e contrato desconhecido; não alegar cobertura exaustiva do produto IBM.
- Fonte SPL é somente para consulta e indicação de execução: não criar funções de edição, compilação ou alteração da rotina por causa da interface de fonte.
- Toda versão deve incluir scripts de compilação e teste básico. Scripts públicos têm versão no nome; classes Java conservam nomes estáveis e versão no cabeçalho.
- `bin/outputs/` guarda resultados versionáveis; ler outputs novos do mantenedor antes de repetir coletas. Não confundir testes locais com integração Informix.
- O levantamento histórico foi recuperado de anexos em 2026-09-11. As conclusões reproduzíveis ficam na arquitetura; dumps originais não devem entrar no Git.
- Se faltar evidência, procurar primeiro nos levantamentos e histórico/anexos acessíveis. Só pedir reenvio quando realmente não estiver disponível.

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
