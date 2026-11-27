# Arquitetura e desenvolvimento · Palco Player v1.2.0

Como a versão estável carrega arquivos, decide a próxima faixa e entrega o áudio ao sistema. Referência para manter, testar e distribuir o produto.

[Leia também: Manual do usuário](manual.md)

<a name="visao"></a>

## Visão do produto

O Palco Player v1.2.0 é uma aplicação web estática de reprodução local, voltada ao uso em eventos. O navegador executa o HTML, o CSS e o JavaScript de um único arquivo, `index.html`. A seleção e a reprodução das músicas acontecem no aparelho de quem abriu a página. Hospedar esse arquivo muda o meio de distribuição do aplicativo; cada aparelho continua responsável por seus arquivos e por sua fila.

**Referência histórica da lógica de reprodução:** branch `main`, revisão `f0d3fca`, versão `1.2.0`. O aceite registrado em 20/10/2026 trata da melhoria de repetição em celular. O [código da versão](https://github.com/DanielZani/Palco-Player/blob/f0d3fcaba599217377b2bcdde7cbf059678250db/index.html) e o [registro de aceite](https://github.com/DanielZani/Palco-Player/blob/f0d3fcaba599217377b2bcdde7cbf059678250db/releases/v1.2.0.md) fixam a base desta referência.

<a name="mapa"></a>

## Mapa da arquitetura

| Fluxo | Caminho |
|---|---|
| Entrada de músicas | Seletor do aparelho → objetos File → filtro e ordenação → playlist em memória |
| Comandos | Botões da página ou Media Session → lógica JavaScript → seleção da faixa e modo |
| Caminho do áudio | File selecionado → URL temporária → elemento `<audio>` → saída do sistema → caixa ou fone |
| Retorno à tela | Eventos do elemento `<audio>` → tempo, duração e estado → controles e lista |
| Distribuição | Arquivo local ou servidor estático → navegador. A música escolhida segue pelo caminho local do áudio. |

A aplicação usa as APIs do navegador diretamente. A interface, a lógica e a reprodução compartilham o mesmo documento, sem etapa de compilação ou biblioteca externa de execução. O servidor de hospedagem pode entregar os HTML sem receber músicas, metadados da playlist ou comandos de reprodução. O áudio é decodificado pelo navegador e encaminhado pelo sistema operacional, que também administra o volume e o Bluetooth.

<a name="repositorio"></a>

## Organização do repositório

| Local | Papel |
|---|---|
| `main/index.html` (arquivo na raiz da branch) | Implementação estável. O CSS está em `<style>`. O corpo contém importação, reprodução e playlist. Um bloco `<script>` no fim registra os eventos e inicializa a tela. |
| `VERSION`, `README.md`, `releases/v1.2.0.md` | Número da versão, escopo funcional e evidências de aceite. |
| `docs/testes-v1.2.md` | Relatório de cenários e resultados em Chromium. O relatório documenta os ensaios; o arquivo não é um executor de testes. |
| `versoes/Palco_Player_v1.1.html` | Cópia histórica anterior à introdução dos modos separados de repetição. |
| Branch `develop/mvp2-onedrive` | Linha reservada ao MVP 2 de acesso direto ao OneDrive pessoal, descrito no projeto como não homologado. Na estável, o arquivo pode chegar via seletor do sistema. |
| `deploy/` e `docker-compose.yml` | Procedimento de publicação e configuração do serviço dedicado na VPS. A revisão implantada é identificada no registro de implantação. |
| `docs/arquitetura.md` e `docs/manual.md` | Fontes editáveis da referência técnica e do manual de operação, legíveis no GitHub. |
| `scripts/gerar_site.py`, `scripts/guias.css` e `scripts/requirements-guias.txt` | Gerador, estilo de leitura e versões das dependências usadas no empacotamento. |
| `.github/workflows/gerar-site.yml` | Monta e valida a distribuição com o código e os dois documentos do checkout. |
| `dist/index.html` e `dist/docs/*.html` | Produto pronto para distribuição. O pacote contém o player e duas páginas estáticas para uso local ou hospedado. |

<a name="componentes"></a>

## Componentes e pontos de manutenção

A divisão a seguir descreve responsabilidades dentro do mesmo script. A função autoexecutável encapsula as variáveis da sessão. Os elementos são localizados pelo atributo `id`. Ao alterar a marcação, revise os identificadores que os manipuladores usam.

| Responsabilidade | Onde alterar no código | O que verificar em seguida |
|---|---|---|
| Selecionar, filtrar e ordenar arquivos | Inputs `files` e `folder`, expressão `allowed`, `key()`, `cleanName()`, `addFiles()` e `Intl.Collator` | Seleção múltipla, compatibilidade do seletor, duplicatas por lote e entre lotes, ordem numérica e estado da primeira faixa. |
| Exibir a playlist e editar a ordem | `render()`, `move()`, `remove()`, `clear()` | Faixa destacada, índice atual depois de mover ou remover, contagem e descarte do histórico aleatório. A limpeza pede confirmação. |
| Carregar mídia e alternar play/pausa | `playAt()`, `togglePlay()`, `releaseUrl()`, elemento `audio` | Troca de faixa, retomada da mesma posição, liberação do recurso anterior e resposta à rejeição de `play()`. |
| Avançar, voltar e sortear | `nextIndex()`, `next()`, `prev()` e evento `ended` | Fim automático versus avanço manual, primeira/última faixa, faixa única, retorno após três segundos e histórico de sorteio. |
| Repetir | `setRepeatMode()`, propriedade `audio.loop` e fallback de `ended` | Exclusividade dos modos, desligamento, troca manual de faixa com repetição ativa e fim de rodada. |
| Sincronizar tela e tratar erros | `status()`, `updateButtons()`, `updateNow()`, `render()` e eventos de mídia | Progresso, duração, destaque visual, faixa vazia, mensagens e botões desabilitados. |
| Atender controles de mídia do sistema | Bloco `navigator.mediaSession`, `MediaMetadata` e `setActionHandler()` | Metadados e ações suportadas pelo navegador. O título vem do nome do arquivo; artista e álbum recebem rótulos fixos do player. |
| Layout e acessibilidade | CSS responsivo, botões nativos, rótulos ARIA, região de status e barra de posição | Teclado, foco visível, nomes acessíveis, estado pressionado dos modos e ausência de rolagem horizontal. |

<a name="dados"></a>

## Estado, arquivos e ciclo de vida

| Estado | Conteúdo e duração |
|---|---|
| `tracks` | Array em memória de objetos `{ file }`. Cada `file` é uma referência fornecida pelo seletor. O critério de duplicidade concatena nome, tamanho e data de modificação; não compara o conteúdo binário. |
| `index` | Índice atual a partir de zero. `-1` representa ausência de faixa selecionada. A primeira importação seleciona a posição zero e aguarda o comando de reprodução. |
| `currentUrl` | URL temporária gerada por `URL.createObjectURL(file)` para a fonte ativa do elemento de áudio. `releaseUrl()` chama `URL.revokeObjectURL()`. |
| `shuffle` e `shuffleHistory` | Sinalizador do aleatório e histórico de índices usados para escolha e retorno. Mover ou remover faixas limpa esse histórico, pois os índices podem mudar. |
| `repeatMode` | Um de três valores, `off`, `track` ou `playlist`. Somente `track` ativa `audio.loop`. |
| `skipErrors` | Conta erros consecutivos no evento de erro de mídia. Um `play()` bem-sucedido zera o contador. |
| Estado do navegador | `audio.paused`, `currentTime` e `duration` alimentam os controles. A duração pode estar indisponível antes do carregamento dos metadados. |

**Persistência.** A v1.2.0 não grava a fila em banco, cookie, armazenamento local ou arquivo de playlist. Recarregar encerra o estado da sessão. A remoção de uma linha modifica o array em memória e preserva o arquivo original. O navegador só entrega à aplicação os arquivos escolhidos pelo usuário.

**Ciclo da URL.** Ao trocar de música, `playAt()` pausa, remove a fonte anterior, reinicializa o elemento, revoga a URL antiga, cria a nova e chama `audio.play()`. Pausar e retomar a mesma faixa reaproveita a fonte carregada. A remoção da faixa ativa, a limpeza e o manipulador de `beforeunload` também liberam a URL quando aplicável.

<a name="fluxos"></a>

## Fluxos de execução e casos de borda

### Importar e iniciar

O evento `change` envia os arquivos a `addFiles()` e limpa o valor do input para permitir nova seleção. O filtro aceita MIME iniciado por `audio/` ou extensão reconhecida. O lote novo é ordenado por caminho relativo ou nome sem extensão usando ordenação numérica em português do Brasil. A aplicação acrescenta o lote à fila, atualiza a contagem e desenha os controles. Um clique em uma linha chama `playAt(i)`.

### Terminar, voltar ou repetir

| Evento | Decisão da implementação |
|---|---|
| Fim natural, modo normal | `ended` chama `next(false)`. Sem sucessora, pausa, volta o tempo a zero e informa fim da playlist. |
| Fim natural, repetir faixa | `audio.loop` cuida do ciclo. Se o navegador disparar `ended`, o fallback volta a zero e tenta tocar novamente. |
| Última faixa, repetir playlist | No sequencial, `nextIndex()` devolve zero. No aleatório, esgotadas as opções, permite nova rodada. |
| Avanço manual | No sequencial sem repetição da lista, informa que a faixa é a última. No aleatório, o pedido manual permite renovar o conjunto de escolhas ao esgotar uma rodada. |
| Anterior | Com tempo acima de três segundos, reinicia a faixa. No começo, consulta o histórico aleatório se disponível ou recua na sequência. Na primeira, repetir playlist permite voltar à última. |
| Reordenar ou excluir | Reordenar ajusta `index` para preservar a identidade da faixa corrente. Remover a faixa corrente descarrega a fonte e seleciona o índice válido mais próximo; a retomada depende de ação do usuário. |
| Rejeição de reprodução ou erro de mídia | O `catch` de `playAt()` informa falha. O evento `error` aplica outra regra: informa formato não suportado e tenta outra faixa elegível enquanto a contagem de erros for inferior ao tamanho da fila. |

### Progresso e comandos externos

`timeupdate` sincroniza o tempo decorrido e a posição da barra. `durationchange` atualiza duração e habilitação. O controle de posição converte uma escala de 0 a 1000 em segundos. `playing` e `pause` atualizam o destaque e os botões. Em navegadores compatíveis, a Media Session registra `play`, `pause`, `nexttrack`, `previoustrack`, `seekto`, `seekbackward` e `seekforward`. Ações não oferecidas pelo sistema podem ficar indisponíveis. O salto relativo padrão é de dez segundos quando o sistema não informa o intervalo.

<a name="desenvolvimento"></a>

## Desenvolver e testar uma alteração

1. **Definir.** Parta da revisão estável identificada em `VERSION` e no registro de release. Descreva a jornada afetada, o resultado esperado e os cenários de borda. Exemplo: se a mudança altera o fim da última faixa, explicite o comportamento com cada modo de repetição e com avanço manual.
2. **Desenhar.** Identifique o ponto de manutenção na tabela de componentes. Registre quais eventos e estados mudam, inclusive o comportamento quando a fila está vazia ou tem só uma faixa.
3. **Desenvolver.** Em uma branch de trabalho, edite o `index.html` e abra a cópia local em um navegador. Para testar via HTTP, com Python 3 instalado, execute na raiz do projeto `python -m http.server 8000 --bind 127.0.0.1` (no Windows com launcher, `py -m http.server 8000 --bind 127.0.0.1`). Abra `http://127.0.0.1:8000/` no mesmo computador. Encerre esse servidor de desenvolvimento com **Ctrl+C**.
4. **Testar.** Execute a matriz abaixo e registre navegador, dispositivo, revisão, arquivos usados, resultado esperado e observado. Use um aparelho e uma saída física para validar áudio Bluetooth. O navegador de desktop permite testar lógica e layout.
5. **Publicar a versão aprovada.** Atualize identificação, registro da versão, evidências e guias afetados. Para distribuição hospedada, publique também os HTML da documentação e verifique os três endereços. Use a versão anterior dos arquivos e da configuração como referência para retorno.

### Matriz de regressão reproduzível

Prepare três arquivos de áudio curtos e distinguíveis, por exemplo `01 A.wav`, `02 B.wav` e `10 C.wav`. Use uma cópia de teste da página. Os cenários abaixo são um roteiro para manutenção. Os resultados históricos têm escopo próprio no [relatório de testes da v1.2](https://github.com/DanielZani/Palco-Player/blob/f0d3fcaba599217377b2bcdde7cbf059678250db/docs/testes-v1.2.md).

| Cenário | Ação | Resultado esperado |
|---|---|---|
| Importar | Adicionar os três arquivos de uma vez em ordem inversa e importar novamente o primeiro. | Ordem numérica A, B, C, total três e nenhum acréscimo duplicado. |
| Editar | Tocar B, mover B para cima, apagar outra faixa e depois apagar B. | Mover conserva o som de B; remover B interrompe a reprodução e preserva os arquivos. |
| Posição e pausa | Pausar e retomar, mover a barra e acionar Anterior após quatro segundos. | Retoma do ponto atual, busca a nova posição e volta ao início no último comando. |
| Repetir faixa | Ativar Música, aguardar dois ciclos e avançar manualmente. | A faixa repete; a nova faixa selecionada passa a repetir. |
| Repetir a lista | Ativar Playlist enquanto Música está ligada. Tocar a última e aguardar o fim. | Música desliga e a primeira faixa começa. Desligar Playlist e repetir o teste faz a reprodução encerrar. |
| Aleatório | Com a primeira faixa selecionada, ligar Aleatório e acompanhar sem intervenções até o fim da rodada; repetir com Playlist ligada. | Sem repetição, a rodada encerra. Com repetição da lista, começa nova rodada. |
| Limpeza e sessão | Cancelar Limpar lista, depois confirmar. Importar outra vez e recarregar. | Cancelar conserva a fila; confirmar e recarregar resultam em lista vazia. |
| Falha e saída física | Testar arquivo indisponível ou inválido; em seguida, tocar áudio válido pelo alto-falante e pela caixa pareada. | Falha apresenta mensagem; mídia válida toca na saída escolhida pelo sistema. Registrar o resultado no dispositivo. |
| Tela e documentação | Abrir em largura estreita e no desktop; percorrer sumário, abrir o outro guia e voltar ao player. | Leitura, foco e navegação possíveis; os três endereços retornam os documentos corretos. |

<a name="distribuicao"></a>

## Distribuição e integração dos guias

Na distribuição local, o usuário abre `index.html`. Na hospedada, o navegador o recebe por HTTP(S). As duas páginas de documentação usam CSS embutido, fontes do sistema e links relativos. Podem ser lidas diretamente do disco. Links de referência ao GitHub ou a fornecedores exigem conexão.

**VPS Hostinger.** O destino da distribuição é `https://player.zani.ia.br/`. O pacote gerado inclui a página inicial e as páginas `docs/manual.html` e `docs/arquitetura.html`. O fluxo de instalação, o servidor de origem, o encaminhamento pelo proxy HTTPS e o procedimento de retorno estão detalhados em `deploy/README.md` da mesma revisão. O script Windows `deploy/Publish-Palco.ps1` gera e envia o pacote. Na VPS, `deploy/vps-release.sh` verifica o manifesto, testa a cópia candidata e altera a rota exclusiva do Traefik. O Nexo retoma a mesma revisão depois que o executor confere o registro nominal no painel DNS. A promoção depende de conferir novamente o conteúdo público por HTTPS. Para o usuário do site, o [manual de hospedagem](manual.md#servidor) descreve como conferir o acesso e a reprodução.

**Links no player.** No rodapé do `index.html`, dois links relativos abrem os guias com `target="_blank"` e `rel="noopener"`. O usuário pode retornar à aba original sem perder a fila em memória. O pacote completo atende tanto a abertura local quanto a distribuição no domínio.

Ao testar uma distribuição em subdiretório, por exemplo `/palco/`, mantenha os destinos relativos. Confira a raiz, cada página interna e um link de seção do manual. O teste de `/healthz` verifica o contêiner, mas cada HTML precisa de uma verificação própria de conteúdo.

<a name="geracao"></a>

## Como os manuais passam do GitHub às páginas do produto

| Documento | Arquivo editado e revisado no GitHub | Página gerada no pacote | Destino a partir do player |
|---|---|---|---|
| Arquitetura e desenvolvimento | `docs/arquitetura.md` | `dist/docs/arquitetura.html` | `docs/arquitetura.html` |
| Manual do usuário | `docs/manual.md` | `dist/docs/manual.html` | `docs/manual.html` |

**Autoria.** Ao alterar um comportamento, atualize no mesmo PR as instruções de uso afetadas e descreva no guia técnico a implementação e os testes relevantes. Os títulos, exemplos e textos das páginas vêm dos Markdown. Uma melhoria no código ainda precisa ser descrita por quem a desenvolveu. O gerador reproduz essa descrição e prepara os links de navegação.

**Conversão.** O processo lê os dois Markdown em UTF-8, renderiza títulos, listas, tabelas e código, monta o sumário de cada HTML e incorpora o CSS. Âncoras como `servidor` são preservadas. Um link editorial como `manual.md#servidor` vira `manual.html#servidor` no produto. Endereços externos e exemplos em blocos de código conservam os destinos escritos pelo autor. As duas páginas abrem com a rede desligada quando os três HTML estão no aparelho.

**Construção.** Em push, pull request ou execução manual, o workflow **Gerar player e documentação** cria `dist/` com o player e as páginas da mesma revisão. O gerador confere destinos relativos e âncoras antes de liberar o pacote. Uma referência quebrada faz a construção falhar. Uma execução bem-sucedida disponibiliza o artefato **palco-player-site** nos detalhes da execução do GitHub Actions. Para distribuir uma versão integrada, use o artefato da revisão aprovada na branch de publicação. O histórico dos Markdown, do gerador e do estilo permite reconstruir cada versão sem versionar as saídas HTML.

**Reprodução local.** Na raiz do checkout, use Python 3.10 ou superior, preferencialmente em um ambiente virtual. No Windows, `py -3` também pode ser usado no lugar de `python`. Execute:

```sh
python -m pip install -r scripts/requirements-guias.txt
python scripts/gerar_site.py
```

Abra `dist/docs/manual.html` e `dist/docs/arquitetura.html` no navegador. Para simular um servidor, execute `python -m http.server 8000 --bind 127.0.0.1 --directory dist`. Abra a raiz e os dois caminhos de documentação em `http://127.0.0.1:8000/`. Dependências Python são necessárias apenas durante a construção.

**Publicação e retorno.** O artefato é a unidade de distribuição. Publique o conteúdo completo de uma única revisão e, se precisar reverter, restaure o pacote completo da revisão anterior. O Nexo coordena a execução pelo ChatGPT Desktop. A transição da candidata para versão publicada depende de conferir HTTPS e o conteúdo efetivamente servido na raiz e nos dois guias, abrir os links de ida e volta e reproduzir arquivos locais no computador e no celular. Registre no repositório o resultado por dispositivo, a revisão servida e a data. Após uma reversão, confira novamente a revisão e as três rotas.

### Histórico e validação desta estrutura

- A documentação partiu da leitura da v1.2.0 e do relatório de testes do player. Foram produzidos o guia técnico e o manual, com instruções de uso local, operação do evento e hospedagem.
- Na primeira entrega do PR #2 havia dois HTML editáveis. Depois foram incluídas cópias em Markdown porque a prévia dos arquivos HTML falhou no aplicativo ChatGPT. Daniel confirmou no celular a leitura das duas páginas apresentadas pelo GitHub.
- O PR #2 fixou as duas fontes Markdown, a geração dos dois HTML e os caminhos relativos para os links no player.
- Para verificar a sincronização em uma revisão de teste, altere uma frase em cada Markdown e gere o pacote. Procure a frase respectiva em cada HTML, abra os dois guias a partir do pacote e confira os links cruzados. Introduza temporariamente uma âncora inexistente em um link e confirme que o gerador falha. Descarte as alterações de teste.
- A homologação da distribuição inclui abrir os HTML efetivamente servidos pelo domínio no celular, consultar as seções e verificar o retorno ao player. A leitura confirmada no GitHub é um registro separado desse teste de publicação.

**Verificação da geração em 27/11/2026.** Com as dependências fixadas no projeto, duas construções dos mesmos fontes produziram os mesmos três arquivos byte a byte. Em cópia isolada, a inclusão de texto, negrito e uma seção nova em cada Markdown chegou ao HTML correspondente e ao sumário. O player permaneceu idêntico ao original. Os três arquivos responderam HTTP 200 sob um subdiretório. Um link cruzado com âncora inexistente foi rejeitado e o último pacote válido foi preservado. Esses ensaios cobrem geração, navegação e empacotamento. Naquela revisão, o player ainda não incluía os links para os guias.

**Candidata à publicação de 27/11/2026.** A integração acrescenta os dois links ao rodapé e mantém a lógica de importação e reprodução da v1.2.0. O ensaio histórico acima caracteriza a geração dos guias. A confirmação da revisão implantada exige a verificação do endereço público e o registro dos testes em produção.
