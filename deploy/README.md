# Publicar a v1.2.0 em player.zani.ia.br

O Nexo coordena o trabalho no Desktop autorizado. Work executa a preparação e o script, Sites permite conferir o pacote estático e Computer Use opera a sessão autenticada do provedor DNS. A VPS Hostinger entrega o HTML e os dois guias. Os arquivos de áudio ficam no aparelho do usuário. O PR e o acompanhamento do computador são eventos distintos.

## Preparação e retomada

1. Confirmar na superfície privada do Nexo o computador registrado, seu estado conectado, o nome real do Windows e a disponibilidade do Desktop. Reconectar à mesma tarefa após interrupção. Usar a branch desta publicação ou a revisão integrada em main, sempre com o SHA completo aprovado. Buscar no repositório oficial, conferir a origem e abrir checkout limpo separado. Uma revisão posterior exige nova conferência.
2. Confirmar a VPS no painel do provedor, seus IPs públicos, a impressão digital SSH confiável, a sessão PuTTY e a chave carregada no Pageant do usuário. Comparar a identidade antes da conexão. A autenticação interativa, quando indispensável, acontece na sessão privada. Preservar o snapshot ou backup corrente e o estado DNS anterior.
3. O Windows precisa de Git, PowerShell 5.1 ou posterior, Python 3.12 com venv e o lançador py, tar, curl, plink e pscp. A VPS precisa de Docker linux/amd64 e Python 3.9 ou posterior. A integração externa usa a rede Docker do proxy e o file provider do Traefik com diretório observado, entrada HTTPS e resolvedor ACME identificáveis. Confirmar esses recursos antes de afetar a rota. A instalação cria o serviço do Palco em paralelo aos existentes.
4. Preparar as variáveis **privadas** do exemplo com os valores confirmados na sessão e no repositório. As execuções devem usar um processo filho de PowerShell para que o código 20 retorne ao coordenador.

```powershell
$opcoes = @{
    Release          = $shaAprovado
    SourceRef        = $refConferida
    ExpectedComputer = $computadorRegistrado
    PuttySession     = $sessaoPutty
    HostKey          = $impressaoConfiavel
    IPv4             = $ipv4Confirmado
}
# Adicionar IPv6 somente se o endereço e o roteamento estiverem confirmados.
& .\deploy\Publish-Palco.ps1 @opcoes
```

O script verifica o checkout e constrói o site numa área temporária. O pacote de conteúdo admite somente index.html, docs/manual.html e docs/arquitetura.html. As somas SHA-256 são comparadas com os bytes servidos. O script Linux recebe o pacote e a configuração do servidor, verifica a integridade, prepara o contêiner da revisão e testa seu conteúdo antes de publicar a rota. O compose é uma opção para ensaiar a origem pelo loopback depois de gerar dist. O fluxo de produção usa a transação de release.

## DNS pelo Computer Use no Desktop

Quando o script retornar `DNS_PENDING` (código 20), o mesmo Nexo executa os passos abaixo no Windows. O responsável é o executor com acesso à conta do titular.

1. Na janela de trabalho dedicada, abrir o painel autenticado do Registro.br, selecionar exatamente **zani.ia.br** e conferir o serviço autoritativo e a edição de zona. Se a delegação apontar a outro operador, reconciliar o provedor antes de qualquer escrita. Preservar a delegação e o modo da zona.
2. Procurar o **nome exato player** na zona. Consultar A, AAAA, CNAME e eventual wildcard aplicável. Guardar o estado inicial e o horário no registro privado da tarefa. Conferir se há mudanças de outras pessoas aguardando salvar.
3. Se houver um CNAME ou um IP divergente no nome exato, interromper a promoção e informar o conflito. Se existir um registro idêntico, reutilizá-lo. Se o nome estiver livre e o painel permitir editar apenas essa mudança, criar A para o IPv4 confirmado da VPS. Criar AAAA apenas com IPv6 explicitamente conferido e roteado para a mesma VPS. Preservar os demais registros, a raiz e os servidores DNS.
4. Revisar a diferença no painel, salvar uma vez, reler a entrada nominal e registrar quais registros esta execução criou. Se o salvamento for incerto, consultar a zona antes de repetir. Registrar o resultado privadamente e retomar o mesmo SHA. O script confere a resolução pública antes de ativar a rota. Propagação pendente mantém o canário.
5. No retorno, remover somente registros criados nesta operação que ainda sejam exatamente iguais ao recibo. Preservar valores anteriores ou alterados por terceiros. Confirmar no painel e em DNS público. Não há segredo DNS no repositório.

## Publicação, aceite e retorno

Após a confirmação do DNS, o coordenador executa novamente `& .\deploy\Publish-Palco.ps1 @opcoes -DnsRecordVerified` após reler o nome exato no painel e verifica a emissão do certificado, a raiz e os três caminhos de arquivo por HTTPS. A verificação exige os bytes da revisão. Uma falha de transporte exige reconciliar a situação antes de repetir a ativação. O modo Verify permite repetir as leituras de aceitação. O modo Rollback restaura a rota anterior gerenciada ou retira a nova rota de uma primeira instalação.

```powershell
& .\deploy\Publish-Palco.ps1 @opcoes -Mode Verify
& .\deploy\Publish-Palco.ps1 @opcoes -Mode Rollback  # apenas quando o retorno for necessário
```

Em cada aparelho, abrir a raiz pública, selecionar dois arquivos locais, tocar, pausar, avançar e alternar os modos de repetição. Abrir cada guia e voltar à aba do player com a fila preservada. Registrar o teste no computador e no celular separadamente. Ao concluir, atualizar o [registro da publicação](../releases/publicacao-2026-11-27.md), o [README](../README.md), o [manual](../docs/manual.md) e a [referência técnica](../docs/arquitetura.md) com data, revisão servida, status e eventuais diferenças. Reconstruir e validar novamente se o conteúdo servido mudar. Guardar detalhes administrativos em evidência privada.
