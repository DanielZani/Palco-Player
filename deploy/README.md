# Palco Player v1.2.0 — preparacao para VPS Hostinger

Projeto pessoal, fora da DOP. Zeus e OpenClaw NAO participam. Codigo estavel permanece inalterado em `main/index.html`. A branch `deploy/v1.2.0-hostinger` contem apenas arquivos de publicacao e nao representa deploy realizado.

## Escopo / seguranca
- A pagina estatica `index.html` e servida por NGINX nao privilegiado em um container sem acesso de escrita ao sistema de arquivos, sem banco de dados ou upload das musicas.
- Porta local proposta: `127.0.0.1:18712`, sem exposicao direta na Internet.
- O proxy HTTPS e DNS de `player.zani.ia.br` devem ser integrados **apos** inspecao da VPS. Nao assumir que proxy, Docker Manager, portas ou IP estao livres.
- Nao utilizar credenciais em arquivos do GitHub, scripts ou conversa. Chaves da Hostinger apenas em GitHub Actions Secrets, quando autorizado.
- O MVP 2 OneDrive nao esta incluso. Nao alterar outros servicos, proxies ou containers, especialmente os da DOP.

## Etapas / gates
1. **Definicao** — publico alvo: v1.2.0, source `main`, pagina estatica, subdominio `player.zani.ia.br`.
2. **Desenho** — levantamento de DNS A/AAAA, SO, Docker e Docker Compose, proxy existente, certificados, backups e conflitos de portas. Nenhum cambio antes deste levantamento.
3. **Desenvolvimento** — imagem NGINX com copia de `index.html` e compose isolado; revisar compatibilidade do Docker Manager Hostinger e o contexto de build no runtime real.
4. **Teste** — validar container `healthy`, resposta de `/healthz`, HTML, HTTPS e acesso real por Android. Validar os botoes de repeticao, musica local, aleatorio e Bluetooth. No navegador, upload e armazenamento de audio permanecem locais.
5. **Deploy** — registrar baseline/backup e plano de retorno. Implantar sem substituir outros virtual hosts; conectar proxy a 18712 e configurar TLS no subdominio. Somente considerar publicado apos verificar HTTPS, resposta da aplicacao e teste no Samsung.

## GitHub Actions (futuro)
O workflow `.github/workflows/publicar-hostinger.yml` e manual (`workflow_dispatch`) e so executa na `main`. Requer que esta branch seja revisada e mesclada, que a VPS suporte o metodo Docker da Hostinger, e que sejam configurados de forma segura:
- `HOSTINGER_API_KEY` como GitHub Actions **Secret**;
- `HOSTINGER_VM_ID` como GitHub Actions **Variable**.

A documentacao oficial da Hostinger lista estes requisitos: https://www.hostinger.com/support/deploy-to-hostinger-vps-using-github-actions/

**Importante:** a acao de implantacao publica inicialmente o container apenas no loopback. O roteamento DNS/HTTPS no proxy da VPS e uma etapa separada a validar no ambiente real. A Hostinger pode exigir ajuste do contexto de build Docker no seu Docker Manager.

## Rollback
Antes de aplicar, registrar commit SHA/versao anterior, compose, configuracoes de proxy e snapshot/backup. Se qualquer verificacao falhar, desfazer apenas o vhost novo `player.zani.ia.br` e o container `palco-player`, restaurando a configuracao capturada. Nao alterar os demais servicos. Sem snapshot inspecionado e rollback testavel, nao prosseguir ao deploy.

## Estado em 20/10/2026
- Codigo de `main`: v1.2.0 verificado no GitHub.
- Pacote de hospedagem: proposto na branch de deploy, sem ensaio na VPS.
- DNS e HTTPS: nao verificados.
- VPS: sem acesso administrativo nesta conversa.
- Publicacao em producao: NAO CONCLUIDA.
