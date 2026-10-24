# 🔋 Guia Prático — Nobreak NHS por SNMP (Zabbix 7.0+)

![Zabbix](https://img.shields.io/badge/Zabbix-7.0%2B-D40000?style=flat&logo=zabbix&logoColor=white)
![SNMP](https://img.shields.io/badge/SNMP-v2c-1E88E5?style=flat)
![UPS MIB](https://img.shields.io/badge/UPS--MIB-RFC%201628-4CAF50?style=flat)

**Template revisado a partir da resposta SNMP fornecida para NHS Laser Senoidal 3500VA, firmware LSPWM(KV30_0) V.28.** São **35 itens próprios (33 SNMP diretos e dois calculados), 19 triggers próprios e oito gráficos**, em formato Zabbix 7.0. O ping e seus alertas são herdados do **Template ICMP**, como no APC existente; sua quantidade depende desse template instalado.

---

## 📁 1. Arquivos e referências

| Caminho na raiz do repositório | Finalidade |
| :--- | :--- |
| `Zabbix Templates/Nobreak/NHS/Template Nobreak NHS SNMPv2.yaml` | Arquivo atualizado; nome técnico preservado: `Template Nobreak NHS SNMP`. |
| `Zabbix Templates/Nobreak/NHS/UPS-MIB_RFC-1628.mib` | MIB usada para conferir os OIDs e escalas. |
| `Zabbix Templates/Nobreak/APC/Template Nobreak APC UPS SNMP.yaml` | Referência preservada; também vincula `Template ICMP`. |
| `Architecture/Arquitetura_Template_Zabbix.md` | Padrões de identificação, coleta e migração. |

Fontes: [módulo e MIB NHS](https://nhs.com.br/modulo-ethernet-web-gerenciavel-nhs/), [itens SNMP Zabbix 7.0](https://www.zabbix.com/documentation/7.0/en/manual/config/items/itemtypes/snmp), [itens calculados](https://www.zabbix.com/documentation/7.0/en/manual/config/items/itemtypes/calculated) e [ordem de operações do importador 7.0](https://github.com/zabbix/zabbix/blob/release/7.0/ui/include/classes/import/CConfigurationImport.php).

---

## 🛠️ 2. Configuração obrigatória

No host, crie a macro `{$SNMP_COMMUNITY}` com a comunidade autorizada, preferencialmente como **Secret text**. Nenhuma comunidade padrão é incluída no YAML.

| Campo da interface SNMP do host | Valor |
| :--- | :--- |
| Endereço | `<192.168.1.X>` — endereço da placa NHS |
| Porta | `161` |
| SNMP version | **SNMPv2** — versão 2 |
| SNMP community | `{$SNMP_COMMUNITY}` |

**SNMP version é uma configuração da interface, não uma macro `snmpversion`.** O servidor/proxy precisa alcançar UDP/161. Os OIDs numéricos dispensam instalar a MIB nesse servidor. A revisão consulta cada OID diretamente; não utiliza `walk[]`, itens mestres ou dependentes.

O template com nome técnico **Template ICMP** deve existir no Zabbix antes da importação. O YAML apenas referencia esse template existente e não inclui sua definição. Confirme o vínculo em **Data collection → Templates → Template Nobreak NHS → Templates**. Habilite **Create new** em **Template linkage** na importação para adicionar o vínculo. O template ICMP requer `fping` e acesso ICMP no servidor/proxy responsável; vincular o template não instala nem configura `fping`.

> 💡 As macros, severidades, destino e dependências de ping pertencem ao `Template ICMP` instalado. Confira nele as configurações usadas pelo APC. Os checks ICMP locais da revisão anterior do NHS foram removidos para evitar duplicação.

---

## 🔄 3. Atualização segura em duas etapas (MANDATÓRIO para a revisão com walks)

Exporte e guarde um backup do template existente. Exporte também o histórico que precisar preservar dos itens a excluir: a exportação do template contém configuração, não os dados históricos.

O importador Zabbix 7.0 remove objetos ausentes **antes** de atualizar os itens. Excluir um mestre quando os itens ainda são dependentes pode removê-los em cascata. Por isso, use o mesmo YAML em duas importações:

1. **Primeira importação — conversão:** em **Data collection → Templates → Import**, habilite atualização dos objetos existentes, criação dos novos e criação de vínculos. Deixe **Delete missing de Items DESMARCADO**. Pode remover os triggers ausentes deste template. Revise a prévia e aplique.
2. Confira no template e no host que os itens mantidos foram convertidos: **Carga da bateria**, por exemplo, deve ser **SNMP agent**, com OID `1.3.6.1.2.1.33.1.2.4.0`, sem item mestre. Os dois itens calculados devem ser **Calculated**. Antes de excluir os walks, filtre **Dependent item** no NHS e confirme que não há itens mantidos ou personalizados dependendo deles.
3. **Segunda importação — limpeza:** somente depois da conversão confirmada, importe novamente o mesmo YAML e marque **Delete missing para Items e Triggers**, apenas no escopo deste template. A prévia deve listar os 11 itens antigos removidos abaixo, e preservar os 35 itens mantidos. Reveja exclusões adicionais caso o template tenha personalizações.
4. Confira o vínculo ao **Template ICMP**, execute os itens SNMP e acompanhe **Monitoring → Latest data**. Consultas diretas e cálculos têm intervalo padrão de um minuto; os cálculos podem precisar de mais um ciclo para receber seus dados de origem.

**Não use Unlink and clear.** Nome técnico, UUID do template e UUIDs/chaves dos 35 itens mantidos foram preservados. A mudança de tipo precisa ser aplicada por **Update existing**. O histórico dos itens excluídos é perdido no Zabbix; os itens mantidos não devem ser recriados durante a atualização. Dados históricos anteriores não são recalculados.

| Itens retirados do NHS | Motivo |
| :--- | :--- |
| Dois mestres de dados brutos | Consultas diretas substituem os walks. |
| Dois diagnósticos dos walks | Sem resposta mestre para analisar nesta revisão. |
| Descrição dos alarmes, troca de bateria, desligamento iminente e perda de comunicação | Não há linhas da tabela de alarmes na resposta enviada. Contagem de alarmes mantida. |
| Disponibilidade, perda de pacotes e latência ICMP locais | Substituídos pela herança do `Template ICMP`. |

A contagem de alarmes era zero; a ausência de linhas nesse instante **não comprova que o firmware nunca ofereça a tabela**. A revisão não infere esses alarmes específicos sem evidência.

---

## 📊 4. Medições confirmadas e unidades

Os 28 OIDs UPS-MIB usados abaixo estavam presentes na resposta fornecida. Os cinco objetos de sistema (`sysContact`, `sysDescr`, `sysLocation`, `sysName` e `sysUpTime`) foram mantidos porque já apareciam com coleta nas capturas. Presença de OID não comprova precisão física da leitura.

| Medição | Valor da resposta após escala | Tratamento |
| :--- | :--- | :--- |
| Fabricante / modelo | NHS Sistemas de Energia / Laser Senoidal 3500VA | Texto; sem vínculo de inventário. |
| Firmware do nobreak / agente | LSPWM(KV30_0) V.28 / NHS UPS Agent | Dois itens de texto. |
| Estado da bateria | Bateria normal (2) | Estados em português. |
| Tempo em bateria | 0 s | Já vem em segundos; sem multiplicador de TimeTicks. |
| Autonomia estimada | 999 min | Minutos; valor preservado. |
| Carga da bateria | 100% | Percentual. |
| Tensão / corrente da bateria | 163,6 V / 0,1 A | Valores brutos × 0,1. Corrente admite sinal. |
| Temperatura da bateria | 0 °C | Valor preservado; sensor precisa de confirmação. |
| Quantidade de linhas de entrada / saída | 1 / 1 | Monitorar índice 1; não somar linhas 2 e 3 zeradas. |
| Tensão de entrada / saída | 130 V / 122 V | Sem escala adicional. |
| Corrente de entrada / saída | 0 A / 3 A | Valores brutos × 0,1. |
| Frequência de entrada / saída | 60 Hz / 60 Hz | Valores brutos × 0,1. |
| Potência ativa de entrada / saída | 0 W / 346 W | Medição própria, distinta de VA. |
| Carga da saída | 11% | Percentual da capacidade. |
| Fonte da saída | Rede elétrica normal (3) | Bateria, bypass e AVR com nomes operacionais. |
| Alarmes ativos | 0 | Contagem; descrição específica não coletada nesta revisão. |
| Resultado / detalhes do último autoteste | Nenhum teste iniciado (6) / texto “0” | Somente leitura; não inicia testes. |
| Potência nominal aparente / ativa | 3500 VA / 3150 W | Valores informados pelo nobreak. |

**Estado da bateria:** `1` = Estado desconhecido; `2` = Bateria normal; `3` = Bateria baixa; `4` = Bateria esgotada. O Zabbix pode exibir também o código numérico.

Dois itens são calculados no Zabbix: **Operando em bateria** usa fonte da saída igual a 5 ou tempo em bateria maior que zero; **Potência aparente de saída** multiplica as últimas leituras de tensão e corrente (122 × 3 = 366 VA na amostra). Consultas independentes podem ocorrer em instantes distintos; esse cálculo não representa potência ativa nem uma amostra simultânea garantida. Sem leituras recentes de ambas as origens, os cálculos ficam indisponíveis, sem retornar zero artificial.

O uptime da placa usa TimeTicks × 0,01 em segundos. A MIB não define número de série padronizado para este template; não inventar OIDs proprietários APC. O template não monitora configuração de desligamento, comandos de controle ou linhas adicionais sem necessidade operacional confirmada.

---

## 🚨 5. Triggers e parâmetros

| Condição | Severidade/comportamento |
| :--- | :--- |
| Uptime da placa sem coleta | Average; verificar comunicação SNMP. |
| Medição essencial sem coleta, com uptime recente | Average; carga da bateria, tensões ou fonte da saída ausentes. |
| Operando em bateria | Warning. |
| Bateria baixa / esgotada / desconhecida | Average / Disaster / Warning. |
| Carga da bateria abaixo de 90% | Average; janela de 5 min, recuperação em 95%. |
| Temperatura acima de 40 °C | High; janela de 3 min, recuperação abaixo de 38 °C. |
| Autonomia abaixo de 10 min em bateria | Disaster. |
| Autonomia de 10 a menos de 20 min em bateria | High; faixa exclusiva. |
| Autonomia indisponível em bateria | Warning. |
| Entrada / saída sem tensão | Average / Disaster; janela de 2 min. |
| Carga da saída de 85 a menos de 95% / a partir de 95% | Warning / High; faixas exclusivas. |
| Fonte da saída sem energia / bypass | Disaster / Warning. AVR não significa automaticamente falta de rede. |
| Contagem de alarmes maior que zero | Warning; identificar o alarme na interface NHS. |
| Último autoteste com erro | Average; não executa teste. |

Os 19 triggers próprios exigem dados recentes para avaliar as grandezas. Os alertas ICMP adicionais são os definidos no template vinculado.

| Macro | Padrão | Uso |
| :--- | :--- | :--- |
| `{$NHS.POLL.INTERVAL}` | `1m` | Consultas diretas e cálculos. |
| `{$NHS.NODATA}` | `5m` | Janela de ausência de dados; maior que o intervalo de coleta. |
| `{$NHS.INPUT.INDEX}` / `{$NHS.OUTPUT.INDEX}` | `1` / `1` | Linha monitorada. |
| `{$NHS.BATTERY.CHARGE.MIN}` / `{$NHS.BATTERY.CHARGE.RECOVERY}` | `90` / `95` | Limite e recuperação de carga. |
| `{$NHS.BATTERY.TEMP.MAX}` / `{$NHS.BATTERY.TEMP.HYST}` | `40` / `2` | Temperatura máxima e histerese. |
| `{$NHS.RUNTIME.HIGH}` / `{$NHS.RUNTIME.CRIT}` | `20` / `10` | Limites em minutos; HIGH maior que CRIT. |
| `{$NHS.RUNTIME.UNKNOWN}` | `0` | Filtro desativado; valor positivo só após confirmação de sentinela. |
| `{$NHS.OUTPUT.LOAD.WARN}` / `{$NHS.OUTPUT.LOAD.CRIT}` | `85` / `95` | Limites percentuais; WARN menor que CRIT. |

---

## 🔍 6. Dados ausentes ou suspeitos

Em **Data collection → Hosts → Items**, confira tipo **SNMP agent**, OID, intervalo, status habilitado e coluna **Info**. Use **Test** para consultar o item e **Execute now** para pedir uma coleta normal; confirme o horário em **Monitoring → Latest data**. Se o teste funciona e a coleta agendada não ocorre, investigar a versão/configuração, fila e logs do servidor ou proxy responsável.

**Um valor vazio na tela não comprova ausência de OID.** Fabricante, modelo, tensão da bateria e fonte da saída estavam na resposta real, embora vazios nas capturas. A captura posterior confirmou item dependente e mestre corretos; não comprovou erro de importação para a Carga da bateria. A causa da falta de valores dos mestres não foi identificada com acesso ao servidor. A consulta direta reduz essa dependência operacional, mas precisa ser homologada.

Temperatura 0 °C, entrada em zero e autonomia 999 min vieram da placa. Compare com a interface web no mesmo instante; não descartar zeros indiscriminadamente. `999` não é sentinela definida pela RFC 1628. Somente após confirmação da NHS, configure `{$NHS.RUNTIME.UNKNOWN}=999`; esse valor gerará erro explicativo e o alerta de autonomia indisponível poderá abrir durante operação em bateria.

> 💡 Não inclua comunidade real em comandos, arquivos ou capturas. Prefira o teste de itens com a macro do host. Nenhuma consulta deste template envia SNMP SET, desligamento ou autoteste.

---

## ✅ 7. Validação e homologação

Validação local da revisão 7.0-2: YAML, UUIDs preservados e sem duplicação, chaves, macros, referências de gráficos/triggers/dependências e vínculo ICMP. Os 28 OIDs UPS-MIB conferem com a MIB e a resposta fornecida; escalas e valores foram reprocessados localmente. Cenários de bateria, ausência de dados, limites de autonomia/carga e indisponibilidade dos cálculos foram exercitados. O filtro JavaScript de sentinela foi testado em Node.

**Esses testes não executam o motor de expressões do Zabbix, o Duktape, a importação real nem consultas SNMP ao equipamento.** A homologação da revisão direta permanece para o ambiente de destino. Os históricos anteriores não são corrigidos retroativamente.

- [ ] Backup do template e dos históricos necessários antes da limpeza.
- [ ] Template ICMP existente e vínculo adicionado.
- [ ] Primeira importação sem excluir itens; 33 itens SNMP e dois calculados convertidos.
- [ ] Nenhum item mantido/personalizado depende dos antigos mestres antes da segunda importação.
- [ ] Segunda importação remove somente os 11 itens previstos e triggers antigos ausentes.
- [ ] SNMPv2, porta 161 e macro da comunidade configuradas na interface do host.
- [ ] Coleta automática atualiza fabricante/modelo, tensão da bateria, fonte e demais OIDs confirmados.
- [ ] Cálculos atualizam depois das origens; bateria em português e gráficos com unidades corretas.
- [ ] Ping e alertas herdados funcionam conforme configuração do Template ICMP.
- [ ] Valores 0 °C e 999 min comparados com o fabricante/interface, sem presumir medição útil.
- [ ] Alertas validados em host de homologação, sem cortar alimentação nem iniciar autoteste de produção.
