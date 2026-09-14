<!--
Versão: v1.0.1
Criado em: 2026-09-14T18:51:29Z
Atualizado em: 2026-09-14T18:55:10Z
Criado por: Codex (ChatGPT)
Projeto: ifx.spldebug
Finalidade: documentar a coleta das implementações de IRoutineService.
-->
# Coleta x22 — provedores de IRoutineService

## Evidência que motivou a coleta

O bytecode real de `RoutineService.getRoutineType(ArrayList)` não adiciona
tipos diretamente. Ele obtém todos os serviços registrados por
`RoutineServiceExtensionManager.getAllServices()` e chama
`IRoutineService.getRoutineType(ArrayList)` em cada implementação.

Por isso o resultado vazio do x21 é correto: os números pertencem aos provedores,
não à classe central.

## Autoteste

```bash
cd ~/ifx.spldebug
bash bin/test-x22.sh
```

O resultado esperado é `PASS X22_SELF_TEST`. O teste usa somente JAR sintético;
os pares `1:2,3:4` validam o coletor e não representam o Informix.

## Executar sobre o ODS preservado

O diretório `x21` da coleta anterior precisa continuar disponível:

```bash
cd /home/informix/tmp/spl.debug

bash ~/ifx.spldebug/bin/x22.sh \
  --ods-root /home/informix/tmp/spl.debug/ods-2.2.1.1 \
  --x21-output /home/informix/tmp/spl.debug/x21 \
  --output /home/informix/tmp/spl.debug/x22
```

O x22:

1. extrai nomes de classes dos metadados Eclipse relevantes coletados pelo x21;
2. localiza essas classes nos JARs do ODS;
3. desmonta somente as classes candidatas;
4. seleciona as que expõem `getRoutineType(ArrayList)`;
5. deriva strings numéricas adicionadas à lista e converte `TL` para `T:L`.

## Resultados

- `x22/x22-summary.txt`: resumo sanitizado com JAR, classe provedora e associação de cada par, apropriado para revisão;
- `x22-private.tar.gz`: bytecode e índices completos, fora do Git.

Somente use `psmd.supported.types` quando o resumo apresentar
`discovery_status=RESOLVED_STATIC_REVIEW` e os pares forem conferidos. Outros
estados significam que a implementação foi localizada parcialmente ou calcula os
valores de modo não coberto pelo extrator.

Se continuar sem resolução, enviar em ordem alfabética:

- `x22-private.tar.gz` — anexar à conversa, nunca commitar;
- `x22-summary.txt` — pode ser copiado para `bin/outputs/` após revisão.
