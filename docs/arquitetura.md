# Arquitetura e desenvolvimento · Palco Player v1.2.0

Como a versão estável carrega arquivos, decide a próxima faixa e entrega o áudio ao sistema. Referência para manter, testar e distribuir o produto.

[Leia também: Manual do usuário](manual.md)

**Sumário**

- [Visão do produto](#visao)
- [Mapa da arquitetura](#mapa)
- [Organização do repositório](#repositorio)
- [Componentes e pontos de manutenção](#componentes)
- [Estado, arquivos e ciclo de vida](#dados)
- [Fluxos de execução e casos de borda](#fluxos)
- [Desenvolver e testar uma alteração](#desenvolvimento)
- [Distribuição e integração dos guias](#distribuicao)

<a name="visao"></a>

## Visão do produto

O Palco Player v1.2.0 é uma aplicação web estática de reprodução local, voltada ao uso em eventos. O navegador executa o HTML, o CSS e o JavaScript de um único arquivo, `index.html`. A seleção e a reprodução das músicas acontecem no aparelho de quem abriu a página. Hospedar esse arquivo muda o meio de distribuição do aplicativo; cada aparelho continua responsável por seus arquivos e por sua fila.

**Referência da implementação:** branch `main`, revisão `f0d3fca`, versão `1.2.0`. O aceite registrado em 20/10/2026 trata da melhoria de repetição em celular. O [código da versão](https://github.com/DanielZani/Palco-Player/blob/f0d3fcaba599217377b2bcdde7cbf059678250db/index.html) e o [registro de aceite](https://github.com/DanielZani/Palco-Player/blob/f0d3fcaba599217377b2bcdde7cbf059678250db/releases/v1.2.0.md) fixam a base desta referência.

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
| Branch `deploy/v1.2.0-hostinger` | Preparação de hospedagem com Docker, NGINX, configuração de porta, healthcheck e proposta de publicação. Abrange uma camada separada da aplicação. |
| `docs/arquitetura.html` e `docs/manual.html` | Referência técnica e manual do usuário. São páginas estáticas autônomas com links relativos entre si. |

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

**VPS Hostinger.** A proposta versionada publica um NGINX não privilegiado na porta 8080 do contêiner, com mapeamento padrão para `127.0.0.1:18712` no host. O proxy externo termina HTTPS. O Dockerfile da proposta inclui só `index.html`; a regra genérica de NGINX retorna 404. Para servir os guias, inclua os dois arquivos na imagem e permita explicitamente os dois caminhos. O [manual de hospedagem](manual.md#servidor) traz as instruções e os testes. Referências da proposta: [Dockerfile](https://github.com/DanielZani/Palco-Player/blob/72fff687976c3e16e447a2e34b4fafef11edf6b2/deploy/Dockerfile), [NGINX](https://github.com/DanielZani/Palco-Player/blob/72fff687976c3e16e447a2e34b4fafef11edf6b2/deploy/default.conf) e [Compose](https://github.com/DanielZani/Palco-Player/blob/72fff687976c3e16e447a2e34b4fafef11edf6b2/docker-compose.yml).

**Links para a próxima versão.** A partir do `index.html` na raiz, estes são os destinos previstos. Se os links forem acionados durante um evento, abrir o guia em outra aba permite consultar as instruções mantendo a sessão e a playlist abertas.

```html
<a href="docs/manual.html" target="_blank" rel="noopener">Manual do usuário (nova aba)</a>
<a href="docs/arquitetura.html" target="_blank" rel="noopener">Documentação técnica (nova aba)</a>
```

Ao testar uma distribuição em subdiretório, por exemplo `/palco/`, mantenha os destinos relativos. Confira a raiz, cada página interna e um link de seção do manual. O teste de `/healthz` verifica o contêiner, mas cada HTML precisa de uma verificação própria de conteúdo.
