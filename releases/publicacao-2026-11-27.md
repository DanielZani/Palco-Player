# Publicação de 27/11/2026

A candidata mantém a versão funcional 1.2.0. O destino previsto do player e dos dois guias é https://player.zani.ia.br. O repositório armazena os fontes. A VPS serve conteúdo estático. As músicas são escolhidas e reproduzidas no dispositivo de quem usa o player.

| Etapa | Resultado exigido |
|---|---|
| Definição | Distribuir a versão local no domínio já definido pelo projeto, preservando áudio, fila e controles. |
| Desenho | Um pacote por revisão Git com três HTML permitidos. Markdown é a fonte única de cada guia. Desktop coordena DNS, canário, ativação, verificação e retorno. |
| Desenvolvimento | Script Windows, transação isolada na VPS e instruções para a sessão autenticada de DNS. Registro do evento em PR. |
| Teste | Conferir hashes, navegação dos guias, reprodução de arquivos locais, controles e preservação da fila ao abrir ajuda. |
| Deploy | Conferir permissões, VPS e proxy reais, DNS autoritativo, TLS público, três páginas e áudio no computador e no celular. Registrar revisão publicada, horário e evidências. |

O nome da máquina, a sessão SSH, a chave de host verificada, os endereços da VPS, as capturas do painel DNS e as evidências administrativas ficam no contexto privado do operador. A abertura do PR sinaliza disponibilidade do pacote. O aceite exige resultados da instalação real. A versão anterior e o estado DNS original devem poder ser restaurados sem interferência em outros serviços.

## Evidências anteriores à publicação

- Duas faixas WAV sintéticas em Chromium 158, nas larguras de 1280 e 390 px. A reprodução, pausa, avanço e repetição funcionaram. A fila foi preservada ao abrir os guias e reiniciou ao recarregar. O tráfego observado limitou-se a quatro GET de páginas por sessão.
- Treze grupos de testes da transação da VPS em simulação passaram, incluindo repetição, conflito de hostname, pacote adulterado depois da preparação e retorno a uma revisão anterior.
- A consulta ao DNS público de 27/11/2026 retornou NXDOMAIN para player.zani.ia.br. O teste da aplicação publicada, o aceite no Windows e o aceite no Android aguardam a operação no ambiente de destino.
