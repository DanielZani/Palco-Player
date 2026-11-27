# Palco Player

Reprodutor pessoal de músicas para computador e celular. O navegador toca arquivos escolhidos no próprio aparelho pela saída de som selecionada no sistema, inclusive Bluetooth.

## Versão estável: v1.2.0

Consulte o [registro de versão e aceite v1.2.0](./releases/v1.2.0.md) e o arquivo [VERSION](./VERSION). O arquivo [index.html](./index.html) é a versão estável mais recente para arquivos locais. Os arquivos HTML funcionam sem instalação de APK e sem bibliotecas externas para reprodução local.

### Funcionalidades

- Importar músicas do armazenamento local (MP3, WAV, M4A, AAC, FLAC, OGG, entre outros, dependendo do navegador).
- Criar e reorganizar a playlist; selecionar, remover e avançar/voltar faixas.
- Reprodução aleatória opcional.
- **Repetir música:** mantém a faixa selecionada em repetição contínua, até desativar a opção.
- **Repetir playlist:** retorna à primeira música após a última; no modo aleatório, inicia outra rodada.
- Os dois modos de repetição são mutuamente exclusivos; ambos podem ficar desligados.
- Com os dois desligados, a playlist termina ao chegar ao fim.
- Saída de áudio e volume gerenciados pelo sistema do aparelho (incluindo Bluetooth).

### Como usar

1. Abra `index.html` no computador ou no celular. Na distribuição hospedada, o endereço de acesso é `https://player.zani.ia.br/` após a publicação.
2. Toque em **Adicionar músicas** (ou **Adicionar pasta**, se o navegador permitir).
3. Escolha os arquivos, conecte a caixa Bluetooth e toque em **Play**.
4. Selecione **↻ Música** para repetir apenas a faixa atual ou **↻ Playlist** para repetir a lista toda. Toque novamente no botão ativo para desligar.

No rodapé, **Manual do usuário** e **Documentação técnica** abrem em outra aba. Para voltar à playlist que já está tocando, retorne à aba original.

O HTML **não armazena** os arquivos de áudio na nuvem e a seleção de arquivos é perdida ao recarregar/fechar a página.

## Histórico

- **v1.2.0** — validada pelo usuário no celular em 20/10/2026; introduz repetição individual de música e repetição da playlist em botões separados; corrige o fim do modo aleatório sem repetição.
- **v1.1** — melhoria de layout da lista no Android, preservada em [versoes/Palco_Player_v1.1.html](./versoes/Palco_Player_v1.1.html).

## MVP 2 — OneDrive pessoal

O MVP 2 com acesso direto ao OneDrive pessoal é uma evolução **não homologada**. Exige hospedagem HTTPS, registro de aplicativo Microsoft e testes reais de autenticação e streaming. Não considerar a integração disponível na versão estável.

## Versionamento e publicação

Este GitHub é a fonte oficial do código. A candidata de 27/11/2026 reúne a reprodução local da v1.2.0 e seus dois guias para publicação na VPS Hostinger. Consulte o [procedimento de implantação](deploy/README.md). O aceite exige conferir a revisão servida pelo domínio, o certificado HTTPS, os três documentos e a reprodução de arquivos do aparelho. O registro de implantação reúne essas evidências e identifica a revisão em produção.

Este projeto pessoal não integra a DOP e não utiliza Zeus/OpenClaw.

## Documentação e pacote do produto

O [manual do usuário](docs/manual.md) e a [documentação técnica](docs/arquitetura.md) são as fontes das páginas web. Edite o Markdown ao revisar um guia. A geração automática reúne o player e as duas páginas no artefato **palco-player-site** do GitHub Actions. O [processo de geração e distribuição](docs/arquitetura.md#geracao) descreve a reprodução local e a integração com a hospedagem.
