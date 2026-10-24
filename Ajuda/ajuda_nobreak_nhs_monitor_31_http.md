# 🔋 Guia Prático do NHS Nobreak Monitor 3.1 por HTTP (Zabbix 7.0)

![Zabbix](https://img.shields.io/badge/Zabbix-7.0_LTS-D40000?style=flat&logo=zabbix&logoColor=white)
![NHS](https://img.shields.io/badge/NHS-Nobreak_Monitor_3.1-0066AA?style=flat)
![HTTP](https://img.shields.io/badge/Coleta-HTTP_Agent-1976D2?style=flat)

Este guia configura o **Template Nobreak NHS Monitor 3.1 (HTTP)** para o software **NHS Nobreak Monitor 3.1 - Sistema de Monitoramento de Nobreaks**. O template HTTP é independente do NHS SNMP e não deve ser usado no Monitor **4.0 beta**.

---

## 📁 1. Arquivos e requisitos

| Arquivo / recurso | Finalidade |
| :--- | :--- |
| `Zabbix Templates/Nobreak/NHS/Template Nobreak NHS Monitor 3.1 HTTP.yaml` | Template novo, exportação 7.0. |
| `Zabbix Templates/Nobreak/NHS/Template Nobreak NHS SNMPv2.yaml` | Template existente para a interface SNMP; preservado. |
| `GET /status` | Estados e medições atuais. |
| `GET /equipamento` | Modelo, versões e parâmetros nominais. |

- NHS Nobreak Monitor **3.1** em execução e comunicando com o nobreak.
- Servidor/proxy Zabbix 7.0 com suporte a HTTP agent/libcurl e acesso às duas páginas.
- Respostas HTTP 200 sem sessão de login ou redirecionamento.
- Identificação `NHS Nobreak Monitor 3.1 -` presente nas páginas, conforme o HTML fornecido.

O método HTTP agent executa as consultas no **servidor Zabbix** ou no **proxy responsável pelo host**; não exige um agente no computador monitorado. [Documentação oficial](https://www.zabbix.com/documentation/7.0/en/manual/config/items/itemtypes/http).

> 💡 Se o computador NHS estiver em outro local, o servidor precisa de acesso privado à rede remota ou o host deve ser monitorado por um proxy com esse acesso. O fato de a página abrir no navegador do Windows não demonstra que o coletor Zabbix consegue acessá-la.

---

## ⚙️ 2. Importação e associação ao host

1. Em **Data collection → Templates → Import**, selecionar o novo YAML. Manter criação de novos objetos habilitada. O nome técnico é `Template Nobreak NHS Monitor 3.1 HTTP`.
2. Associar **Template Nobreak NHS Monitor 3.1 (HTTP)** ao host do computador que executa o Monitor.
3. Em **Macros**, configurar `{$NHS.HTTP.URL}` com a URL base acessível ao servidor/proxy, por exemplo `http://<ip_do_computador>:2001`, sem barra final e sem `/status` ou `/equipamento`.
4. Verificar os dois itens de coleta em **Latest data**. Executar **Execute now** nos mestres para antecipar a primeira consulta; dependentes não precisam de execução separada.
5. Confirmar os valores reais, os dois indicadores **Página válida** e os diagnósticos vazios.

Para reimportar a revisão **7.0-3** após uma tentativa anterior, habilitar **Create new** e **Update existing** para triggers e os demais objetos do template. Esta revisão corrige o campo de mínimo do gráfico (`yaxismin`) e inclui a expressão de recuperação na referência ao alerta crítico. As chaves e UUIDs foram preservados.

O valor herdado de URL é `http://127.0.0.1:2001`; funciona apenas quando o Monitor estiver no próprio computador do coletor. **Para o Monitor remoto, sobrescrever obrigatoriamente a macro no host com a URL literal real.** Não colocar `{HOST.CONN}` ou outra macro dentro desse valor. Não é necessário criar uma interface Agent/SNMP apenas para a coleta HTTP. O destino deve ser o computador do Monitor, não a placa SNMP do nobreak.

`localhost` e `127.0.0.1` referem-se ao próprio servidor/proxy que executa a consulta. Usá-los somente quando o Monitor realmente estiver acessível nesse computador.

As chaves novas usam `nhs.http.*`, sem vínculos de inventário ou herança de ICMP. Não é necessário remover o NHS SNMP nem executar **Unlink and clear**. Se ambos forem vinculados ao mesmo host, eles podem gerar alertas independentes para o mesmo problema físico; selecionar a coleta adequada à operação.

---

## 🛠️ 3. Macros

| Macro | Padrão | Uso |
| :--- | :--- | :--- |
| `{$NHS.HTTP.URL}` | `http://127.0.0.1:2001` | URL base do Monitor vista pelo coletor; sobrescrever para o endereço remoto. |
| `{$NHS.HTTP.INTERVAL}` | `1m` | Coleta de `/status`. |
| `{$NHS.HTTP.EQUIPMENT.INTERVAL}` | `30m` | Coleta de `/equipamento`. |
| `{$NHS.HTTP.TIMEOUT}` | `10s` | Timeout por requisição. |
| `{$NHS.HTTP.NODATA}` | `5m` | Prazo sem status e limite de frescor para alertas. |
| `{$NHS.HTTP.EQUIPMENT.NODATA}` | `2h` | Prazo sem equipamento. |
| `{$NHS.HTTP.PROBLEM.WINDOW}` | `2m` | Janela de amostras dos alertas de carga. |
| `{$NHS.HTTP.LOAD.WARN}` | `85` | Carga elevada acima de 85%. |
| `{$NHS.HTTP.LOAD.CRIT}` | `95` | Carga crítica a partir de 95%. |
| `{$NHS.HTTP.LOAD.HYST}` | `5` | Histerese em pontos percentuais. |
| `{$NHS.HTTP.INPUT.OK.MATCHES}` | `(?i)^OK$` | Estado de entrada aceito. |
| `{$NHS.HTTP.OUTPUT.OK.MATCHES}` | `(?i)^Normal$` | Estado de saída aceito. |
| `{$NHS.HTTP.BATTERY.OK.MATCHES}` | `(?i)^Carregada$` | Estado de bateria aceito. |

Manter os prazos de ausência de dados maiores que os respectivos intervalos. Usar `LOAD.WARN < LOAD.CRIT`, com histerese positiva menor que os limiares. `PROBLEM.WINDOW` opera sobre as amostras existentes; não exige uma quantidade mínima de amostras nem garante dois minutos completos de permanência após a primeira coleta.

---

## 📊 4. Itens, gráficos e alertas

O template possui **25 itens próprios**: dois mestres HTTP, quatro diagnósticos e 19 campos dependentes. Os campos de leitura são:

| Página | Dados |
| :--- | :--- |
| Status | Estado da entrada; tensão de entrada atual, mínima e máxima registradas; estado da saída; tensão de saída; carga do nobreak em %; estado da bateria; tensão DC da bateria. |
| Equipamento | Modelo; versão da placa; firmware; tipo e quantidade de baterias; tensão nominal do banco; tensão de entrada nominal; limites de subtensão/sobretensão configurados; tensão de saída nominal. |

Os quatro gráficos mostram entrada/saída, entrada e extremos registrados, tensão do banco de baterias com sua referência nominal e percentual de carga do nobreak.

Na revisão **7.0-4**, o alerta **NHS HTTP: Página /status sem coleta HTTP** tem severidade **Disaster**, com prazo padrão de cinco minutos sem amostras. O alerta de ausência de `/equipamento` mantém **Warning**, com prazo padrão de duas horas. Para aplicar a nova severidade, reimportar o YAML com **Update existing** habilitado para triggers.

Os nove alertas cobrem ausência de consulta das duas páginas, erro de interpretação das duas páginas, alteração dos três estados e dois níveis de carga. Carga elevada usa a faixa acima de 85% e abaixo de 95%, com recuperação abaixo de 80% ou transição para carga crítica. Carga crítica usa 95% ou mais, recuperando abaixo de 90%. A janela de min/max e a dependência do alerta elevado em relação ao crítico reduzem sobreposição. Os valores de carga acima de 100% são preservados.

Os estados textuais são mantidos como informados pelo software. Os padrões **OK**, **Normal** e **Carregada** são os únicos estados normais demonstrados pelos arquivos fornecidos. Um texto diferente gera um aviso genérico; isso não permite concluir automaticamente operação em bateria, bypass ou desligamento. Por exemplo, se o equipamento apresentar um estado de recarga considerado normal na sua operação, conferir esse texto e ajustar explicitamente a regex da bateria antes de aceitá-lo.

Alertas de estados/carga só abrem e recuperam com dados recentes e página válida. Uma perda de coleta não é tratada como recuperação física de um problema já aberto. Campos ausentes, vazios, negativos ou com unidade inválida invalidam a leitura da página; os dependentes ficam não suportados, preservando o histórico anterior. Nenhum valor ausente é convertido em zero ou estado normal.

---

## 🌐 5. Diagnóstico por leitura

No computador que executa o **servidor/proxy Zabbix**, verificar a página de status usando o endereço real do Monitor:

```bash
curl --fail --silent --show-error --max-time 10 'http://<ip_do_computador>:2001/status'
```

Verificar a página de equipamento:

```bash
curl --fail --silent --show-error --max-time 10 'http://<ip_do_computador>:2001/equipamento'
```

Executar com o contexto de rede do coletor; em instalações com contêineres, um teste no host externo ao contêiner pode não reproduzir seu acesso. Para HTTPS, configurar a cadeia de confiança e o nome do certificado no coletor; o template mantém validação TLS habilitada.

| Sintoma | Verificação |
| :--- | :--- |
| Mestre não suportado | URL, rota privada/proxy, porta, resposta HTTP 200 e timeout. |
| Página inválida / diagnóstico preenchido | Versão 3.1, título e tabelas esperados. O erro informa campo ausente ou unidade inválida. |
| Versão incompatível | Página sem identificação 3.1 ou versão 4.0 beta; não contornar a checagem para reutilizar esse template. |
| Dependentes antigos | Conferir primeiro os mestres e diagnósticos; não interpretar valor antigo como nova leitura. |
| Estado diferente do esperado | Conferir o texto no Monitor e a regex configurada. Não reinterpretar estados desconhecidos por suposição. |

As consultas do template usam exclusivamente `GET /status` e `GET /equipamento`. Não acionam comandos de nobreak, autoteste, atualização de configuração ou desligamento.

---

## 🔍 6. Limitações e validação

- **Compatibilidade:** somente NHS Nobreak Monitor 3.1 com o layout observado; o 4.0 beta requer outro template. O parser confere a identificação de versão nas duas páginas.
- **Mostradores:** o HTML de `/graficos_gauge` contém espaços preenchidos pelo JavaScript, sem valores adicionais. A captura mostra as mesmas quatro medições já obtidas em `/status`. Temperatura e corrente do carregador dependem de endpoints/scripts que não foram fornecidos com valores; não foram criados itens fictícios.
- **Unidades:** tensão da bateria é V, carga do nobreak é %. Não calcular percentual de bateria, autonomia, potência ativa/aparente ou frequência sem dados próprios.
- **Nominais e extremos:** mínima/máxima de entrada são extremos registrados pelo software. Os limites configurados são itens informativos; não geram alertas de faixa elétrica nesta versão. A amostra de equipamento mostra entrada nominal de 120 V, enquanto o status mostra 226,2 V, sem comprovar qual faixa automática está ativa no momento.
- **Atualidade física:** um HTTP recente comprova nova consulta ao Monitor, mas as páginas não fornecem um timestamp da amostra serial/USB. Se o Monitor mantiver valores antigos após perder a comunicação física, o template não consegue distinguir isso apenas pela data de consulta HTTP.
- **Evidência:** YAML relido com PyYAML; parser e dependentes executados no Duktape instalado na VM de teste, com status real, reprodução das tabelas de equipamento previamente lidas e casos inválidos. O arquivo original de equipamento deixou de estar disponível antes da execução dos testes; sua reprodução mantém rótulos e valores observados, sem representar uma nova coleta real. As expressões de alertas foram avaliadas por um modelo local do subconjunto utilizado, sem afirmar equivalência completa ao motor Zabbix. Importação no Zabbix 7.0, associação ao host com template de SO e coleta HTTP real permanecem pendentes no destino.

O manual oficial documenta a interface web na porta 2001 e a separação entre equipamento e status. O layout, os rótulos e a versão 3.1 desta implementação foram conferidos nos arquivos fornecidos pelo proprietário. [Manual NHS](https://nhs.com.br/wp-content/uploads/manuais/Manual-NHSUPS-SW-3030.pdf).

A organização do YAML segue o formato de exportação do Zabbix 7.0. [Especificação oficial](https://www.zabbix.com/documentation/7.0/en/manual/xml_export_import/templates).
