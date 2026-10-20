# Palco Player v1.2 — relatório de testes

Data: 20/10/2026. Fonte testada: `index.html`, também reproduzida na base de desenvolvimento do MVP 2.

| Cenário | Resultado |
|---|---|
| Importar três faixas WAV de teste | PASS |
| Reprodução local no Chromium | PASS |
| Ativar repetição da faixa atual e conferir `audio.loop` | PASS |
| Avançar manualmente mantendo repetição da faixa selecionada | PASS |
| Reiniciar faixa ao término (fallback do evento `ended`) | PASS |
| Ativar repetição da playlist e desativar repetição individual | PASS |
| Voltar da última faixa para a primeira | PASS |
| Desativar repetição e encerrar na última faixa | PASS |
| Modo aleatório sem repetição encerra após uma rodada | PASS |
| Testar larguras 280, 320, 360, 390, 430 e 760 px | PASS |
| Controles visíveis sem rolagem horizontal | PASS |
| Erros JavaScript capturados nos testes | 0 |

**Método:** testes funcionais em Chromium automatizado (Playwright), com três arquivos de áudio WAV de teste, eventos de fim de reprodução e verificação de DOM e estado do áudio. Não foi testado em um aparelho Samsung físico nem numa caixa Bluetooth real nesta execução.

**Publicação:** alteração registrada no GitHub. Sem implantação automática na VPS Hostinger.

**Critérios adicionais para validação no celular real:** tocar a mesma música por dois ciclos, alternar repetição sem interromper a reprodução e confirmar áudio pela caixa Bluetooth.
