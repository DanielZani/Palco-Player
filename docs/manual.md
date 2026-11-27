# Manual do usuário · Palco Player v1.2.0

Do primeiro arquivo à última faixa: prepare sua playlist, escolha a saída de som e opere o player durante o evento.

[Leia também: Arquitetura e desenvolvimento](arquitetura.md)

<a name="comecar"></a>

## Começar em três passos

1. Abra o **Palco Player** no navegador. Se ele já está hospedado, basta abrir o endereço do site. Para usar uma cópia no aparelho, siga a orientação de [uso local](#local).
2. Toque em **+ Adicionar músicas**, escolha dois ou três arquivos de áudio e confirme no seletor. Confira a quantidade na seção **Playlist do evento**. A primeira música fica selecionada.
3. Toque em **▶ Reproduzir**. Confira se o tempo começa a avançar e se o som sai no dispositivo desejado. Para iniciar por outra música, toque no nome dela.

> **Antes de preparar um evento:** a playlist vale para a página aberta. Fechar ou recarregar a página perde a seleção e a ordem. Para reconstruir a sequência facilmente, guarde os áudios em uma pasta e numere os nomes dos arquivos, como `01 Abertura.mp3` e `02 Entrada.mp3`.

<a name="local"></a>

## Usar localmente no computador ou celular

### Obter o arquivo correto

O aplicativo estável é o arquivo **index.html**. Para a v1.2.0, abra o [código desta versão no GitHub](https://github.com/DanielZani/Palco-Player/blob/f0d3fcaba599217377b2bcdde7cbf059678250db/index.html) e use **Download raw file** (baixar o arquivo original), se disponível. Outra opção é baixar o [ZIP da versão estável](https://github.com/DanielZani/Palco-Player/archive/f0d3fcaba599217377b2bcdde7cbf059678250db.zip) e extraí-lo. Abra o HTML extraído. Salvar a página de visualização do GitHub pode baixar a interface do GitHub.

**Para obter o produto completo**, no GitHub abra **Actions → Gerar player e documentação**, escolha a execução bem-sucedida da revisão desejada e baixe o artefato **palco-player-site** (requer acesso ao download de artefatos). Extraia o ZIP e abra o arquivo `index.html`. Outra opção é gerar a mesma pasta a partir da revisão, conforme a [documentação técnica](arquitetura.md#geracao).

**Para ter a documentação offline**, guarde `arquitetura.html` e `manual.html` na subpasta `docs`, ao lado de `index.html` na pasta principal. Os links entre os três arquivos usam essa disposição. O ZIP histórico da v1.2.0 contém o player original e antecede a criação destes guias.

### No computador, inclusive Windows 11

1. Crie uma pasta **Palco-Player**, coloque o arquivo `index.html` nela e confira a extensão. No Explorador de Arquivos, você pode habilitar a exibição das extensões para distinguir `.html` de `.html.txt`.
2. Clique com o botão direito no arquivo e escolha **Abrir com** e um navegador, como Chrome ou Edge. Você também pode usar **Ctrl+O** no navegador e selecionar o arquivo. O título visível deve ser **Palco Player**.
3. Use **+ Adicionar músicas**. No seletor do Windows, **Ctrl** permite marcar arquivos separados e **Shift** permite marcar uma sequência. Clique em **Abrir** e depois em **▶**. Ajuste o volume ou escolha a saída nas configurações de som do computador.

### No celular Android, inclusive Samsung Galaxy

1. Baixe o HTML ou transfira a pasta do computador para o celular. Se recebeu um ZIP, extraia-o no gerenciador de arquivos. Em um Samsung, procure **Meus Arquivos → Downloads**.
2. Toque no `index.html` e escolha um navegador compatível, se o Android oferecer essa opção. A tela deve mostrar **Escolha as músicas**, **Controle a reprodução** e **Playlist do evento**.
3. Toque em **+ Adicionar músicas**. No seletor, abra a pasta dos áudios, selecione um ou vários e confirme. Em alguns seletores, manter o primeiro arquivo pressionado habilita a seleção múltipla.
4. Se o celular abrir apenas uma prévia, tente **Abrir com** no gerenciador. Se nenhum navegador puder executar o HTML local nesse aparelho, abra a versão hospedada pelo endereço HTTPS. As músicas continuam sendo escolhidas no celular.

Com a página local aberta e os arquivos disponíveis no aparelho, a reprodução funciona offline. Se o áudio estiver apenas na nuvem, baixe-o antes de ficar sem conexão.

<a name="servidor"></a>

## Instalar em servidor web ou VPS

**Quem hospeda** publica o player e as duas páginas de documentação. **Quem ouve** abre o endereço no próprio navegador e escolhe suas músicas. Cada navegador mantém sua própria playlist. Os arquivos de áudio do evento ficam nos aparelhos que os selecionaram.

### Opção A · Site estático em servidor existente

1. Extraia o pacote **palco-player-site** da revisão escolhida ou use a pasta `dist/` gerada a partir dela. O conteúdo pronto para publicar tem esta estrutura:

```text
palco-player/
  index.html
  docs/
    arquitetura.html
    manual.html
```

2. No painel de hospedagem ou no servidor administrado, escolha um site, subdomínio ou diretório dedicado. No painel que gerencia o site, identifique a **raiz pública** (document root). Se publicar sob um caminho, por exemplo `/palco/`, crie a pasta correspondente dentro dessa raiz.
3. Use o gerenciador de arquivos do provedor ou SFTP para copiar o **conteúdo** de `palco-player/` para o destino. Preserve a pasta `docs` e os nomes em minúsculas. Em instalação existente, guarde uma cópia dos três arquivos que serão substituídos.
4. Configure o servidor para servir `index.html` como página inicial e os dois caminhos `docs/*.html` como arquivos HTML estáticos. Para um subdomínio novo, aponte o DNS para a VPS e associe o nome ao site e ao certificado HTTPS pelo mecanismo já usado no servidor.
5. Abra a raiz do site e depois diretamente `docs/manual.html` e `docs/arquitetura.html`. Confira os títulos de cada página. No celular, importe uma música local, toque, pause e retome. Se algo falhar após uma atualização, restaure os arquivos e a configuração anterior daquele site.

### Opção B · VPS Hostinger com Docker e proxy HTTPS

O repositório contém uma **proposta de implantação** no [PR de preparação da Hostinger](https://github.com/DanielZani/Palco-Player/pull/1). O exemplo usa NGINX no contêiner e um proxy HTTPS na VPS. O domínio previsto é `player.zani.ia.br`; confirme sua configuração no ambiente antes de utilizá-lo.

1. O administrador identifica o proxy e a rede existentes, o domínio, o mecanismo de certificado, as versões de Docker/Compose e uma porta de loopback livre. O pacote sugere `127.0.0.1:18712`. Registre a configuração do site e a versão anterior para retorno.
2. Prepare uma cópia de trabalho com `docker-compose.yml`, `deploy/Dockerfile` e `deploy/default.conf` da [revisão de hospedagem](https://github.com/DanielZani/Palco-Player/tree/72fff687976c3e16e447a2e34b4fafef11edf6b2), a revisão aprovada do produto e seu pacote gerado em `dist/` na raiz do contexto Docker. Para cada atualização, use a saída da geração da mesma revisão.
3. **Inclua os guias no pacote.** O Dockerfile original copia somente o player. Na integração inicial, substitua a cópia isolada de `index.html` pelas três linhas abaixo. Elas usam o pacote gerado. No bloco `server` de `deploy/default.conf`, acrescente as duas rotas exatas antes da regra genérica que retorna 404. O exemplo utiliza o `root` já definido no pacote.

```dockerfile
COPY dist/index.html /usr/share/nginx/html/index.html
COPY dist/docs/manual.html /usr/share/nginx/html/docs/manual.html
COPY dist/docs/arquitetura.html /usr/share/nginx/html/docs/arquitetura.html
```

```nginx
location = /docs/manual.html     { try_files $uri =404; }
location = /docs/arquitetura.html { try_files $uri =404; }
```

4. Se o provedor construir diretamente de um checkout limpo, a preparação da imagem precisa gerar `dist/` nessa construção ou receber o artefato da revisão; a pasta gerada não acompanha o checkout. Na pasta de trabalho da implantação, o administrador valida o Compose, constrói a imagem e verifica o serviço. Estes comandos exemplificam a configuração original e a porta padrão em um ambiente preparado:

```sh
docker compose config --quiet
docker compose up -d --build web
docker compose ps
curl -fsS http://127.0.0.1:18712/healthz
curl -fI http://127.0.0.1:18712/
curl -fI http://127.0.0.1:18712/docs/manual.html
curl -fI http://127.0.0.1:18712/docs/arquitetura.html
```

5. Espere o serviço ficar saudável. O primeiro endereço de teste deve responder `ok`; os três HTML devem retornar HTTP 200. Se a porta foi alterada por `PALCO_LOCAL_PORT`, use a porta escolhida nos testes e no proxy.
6. Configure o host virtual no proxy existente para encaminhar a raiz **e os caminhos de documentação** ao serviço. Para proxy no próprio host, o destino proposto é `http://127.0.0.1:18712`. Para proxy em outro contêiner, use a rede e o destino acessível a partir dele. Habilite o certificado do subdomínio e confirme o DNS.
7. Em outra conexão, abra os três endereços HTTPS em um navegador. O primeiro deve exibir o player e os demais os respectivos guias. No Android, teste duas faixas e a saída de áudio. Se falhar, retire apenas a nova rota ou restaure o host virtual e a versão anterior do serviço do player.

Consulte o [roteiro de implantação do projeto](https://github.com/DanielZani/Palco-Player/blob/72fff687976c3e16e447a2e34b4fafef11edf6b2/deploy/README.md), o [guia de arquivos estáticos e proxy do NGINX](https://nginx.org/en/docs/beginners_guide.html) e a [referência do Docker Compose](https://docs.docker.com/reference/cli/docker/compose/up/).

<a name="playlist"></a>

## Criar, organizar e limpar a playlist

1. **Escolher os arquivos.** Em **1 · Escolha as músicas**, toque em **+ Adicionar músicas**. O player aceita tipo de arquivo `audio/*` e reconhece extensões MP3, M4A, MP4, AAC, WAV, OGG, OGA, Opus, FLAC e WebM. O navegador precisa conseguir decodificar o áudio.
2. **Importar uma pasta.** Toque em **Adicionar pasta**, escolha a pasta no seletor e confirme. Em navegadores sem suporte a pastas, use a seleção de vários arquivos. Para músicas do OneDrive pessoal, use o OneDrive no seletor do aparelho se disponível, ou baixe as faixas para Downloads e importe os arquivos.
3. **Conferir a ordem.** O player ordena cada lote por nome ou caminho com ordenação numérica e o acrescenta ao fim da lista. O nome exibido vem do arquivo sem a extensão. Arquivos com o mesmo nome, tamanho e data de modificação são tratados como duplicados.
4. **Acrescentar músicas.** Repita a seleção quantas vezes precisar. Confira a mensagem de quantidade adicionada e o total em **3 · Playlist do evento**. Importar um novo lote preserva os anteriores.
5. **Reordenar.** Toque em **↑** ou **↓** ao lado da faixa até chegar à posição desejada. Cada toque move uma posição. É possível mover a faixa que está tocando e continuar ouvindo.
6. **Remover.** Toque em **×** na linha da música. O item sai da lista imediatamente e o arquivo original continua no aparelho. Remover a faixa em reprodução interrompe o som. Use **▶** ou toque em outra faixa para continuar.
7. **Limpar tudo.** Toque em **Limpar lista** e confira a quantidade na confirmação. Cancele para manter a lista ou confirme para interromper a reprodução e esvaziá-la. Para desfazer uma remoção, importe novamente o arquivo e ajuste sua posição.

A v1.2.0 trabalha com **uma playlist por página aberta**. Não há comando para salvar, nomear, exportar ou recuperar a lista em outra sessão.

<a name="reproduzir"></a>

## Reproduzir e controlar a música

| Controle | Como operar e o que observar |
|---|---|
| **▶ Reproduzir / Pausar** | Inicia a faixa selecionada. Toque no mesmo botão para pausar e novamente para retomar do ponto atual. |
| **Nome da faixa na lista** | Toque para reproduzi-la diretamente. Escolher uma faixa diferente carrega o arquivo correspondente. |
| **Próxima** | Avança para a próxima faixa ou sorteia outra no aleatório. Em ordem normal, com repetição da lista desligada, o avanço manual na última informa que ela é a última. |
| **Anterior** | Depois de três segundos de reprodução, volta ao início da faixa atual. Até três segundos, tenta a anterior na lista ou consulta o histórico no aleatório. |
| **Barra de posição** | Arraste para adiantar ou voltar dentro da música. O controle fica disponível quando o navegador obtém a duração do arquivo. |
| **Indicadores** | O painel mostra nome, posição da faixa, tempo decorrido e duração. A lista destaca a faixa atual e mostra uma nota musical enquanto ela toca. |
| **Controles do aparelho** | Se o navegador disponibilizar controles de mídia, use os comandos de reproduzir, pausar, próxima e anterior. O sistema pode também oferecer busca por posição ou saltos para frente e para trás. |

<a name="modos"></a>

## Escolher aleatório e repetição

Os botões mostram o estado **sim** ou **não**. Toque de novo no botão ativo para desligá-lo. **↻ Música** e **↻ Playlist** são exclusivos entre si. **⇄ Aleatório** pode ser combinado com qualquer um deles.

| Quero… | Como configurar | O que acontece ao terminar a faixa |
|---|---|---|
| Ouvir a lista uma vez | Aleatório, Música e Playlist em **não** | Segue a ordem e para no final da última. |
| Ouvir em ordem, continuamente | Playlist em **sim**, Aleatório em **não** | Depois da última, volta à primeira. |
| Repetir uma música | Música em **sim** | Reinicia a faixa atual. Se você escolher outra faixa manualmente, a nova passa a repetir. |
| Sortear uma rodada | Aleatório em **sim**, ambas as repetições em **não** | Sorteia as próximas e encerra quando se esgota a rodada automática. |
| Sortear continuamente | Aleatório e Playlist em **sim** | Ao esgotar as opções da rodada, inicia outra. |

**Exemplo de evento.** Para tocar uma música de recepção até a abertura, escolha a faixa, ative **↻ Música** e dê play. Quando chegar a hora do programa, desligue **↻ Música**, confira se **⇄ Aleatório** está em **não** e toque diretamente na primeira faixa do programa.

<a name="saida"></a>

## Som, Bluetooth e encerramento

1. No Android, emparelhe a caixa ou o fone Bluetooth nas configurações do sistema. No painel de mídia do celular, selecione esse dispositivo como saída. No Windows, use o seletor de saída de som do sistema.
2. Inicie uma faixa e ajuste o volume pelos botões ou controles do aparelho. Confira se o tempo avança no player e se o áudio realmente sai da caixa escolhida. Em eventos, faça essa conferência com o mesmo aparelho, navegador e caixa que serão usados.
3. Mantenha a página aberta enquanto precisar da playlist. Use **Pausar** para um intervalo. Ao final, use **Limpar lista** se desejar esvaziá-la ou feche a página. Os arquivos de música permanecem no dispositivo.

<a name="problemas"></a>

## Resolver problemas frequentes

| Sintoma | O que fazer |
|---|---|
| Vejo código ou uma prévia do arquivo. | Extraia o ZIP, confirme que está abrindo o arquivo original `index.html` no navegador e procure o botão **+ Adicionar músicas**. No celular, a versão HTTPS é uma alternativa. |
| “Nenhuma música nova encontrada.” | Confira a seleção, a extensão e se as músicas já estão na lista. Faça um teste com um MP3 ou WAV local conhecido. |
| O seletor de pasta ou o OneDrive não aparece. | Use **+ Adicionar músicas** para seleção múltipla. Para OneDrive, baixe os arquivos no aparelho antes de importar. |
| A faixa não toca ou o player pula um arquivo. | Confirme que o arquivo está disponível por inteiro. Teste outro áudio. Em erro de mídia, o player pode tentar outra faixa. Se o problema estiver em um formato, use uma cópia em formato compatível com o navegador. |
| O tempo avança, mas a caixa está muda. | Confira o volume de mídia, a saída selecionada e o pareamento Bluetooth. Faça um teste pelo alto-falante do dispositivo para localizar a causa. |
| A mesma música sempre reinicia, ou a lista volta ao começo. | Verifique **↻ Música** e **↻ Playlist**. Deixe os dois em **não** para encerrar ao final. |
| A lista sumiu quando voltei. | Se a página foi recarregada, fechada ou descartada pelo navegador, importe a pasta outra vez. Pastas com arquivos numerados facilitam recompor a ordem. |
| O site abre, mas um guia retorna 404. | Confira o caminho `docs/`, maiúsculas e minúsculas, a cópia dos dois HTML e as rotas no servidor. Em Docker, reconstrua a imagem após incluir os arquivos e a configuração. |
