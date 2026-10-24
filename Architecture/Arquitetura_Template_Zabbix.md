# 📐 Arquitetura e Padronização - Templates Zabbix (`zbx_*_template.yaml`)

Este documento estabelece as diretrizes arquiteturais, padrões de conformidade, regras anti-conflito e boas práticas para o desenvolvimento, exportação e manutenção de templates para o **Zabbix 7.0 LTS** no repositório.

---

## 📌 1. Visão Geral e Princípios Fundamentais

Templates Zabbix devem ser concebidos para ambientes corporativos heterogêneos. Um servidor de produção frequentemente acumula múltiplos templates associados simultaneamente (ex: Sistema Operacional, Banco de Dados, Aplicação Web e Periféricos/Nobreaks).

Por essa razão, o princípio fundamental no design de templates é a **Modularidade Não Invasiva**:
* **Não Colidir**: Nunca utilizar chaves, identificadores ou vinculações que possam entrar em conflito com o template do Sistema Operacional ou outros templates de serviço.
* **Ser Autocontido**: O template deve conter todos os seus itens, triggers, gráficos, valuemaps e macros com valores padrão funcionais.
* **Ser Universal e Portável**: Compatibilidade estrita com a especificação de exportação do Zabbix 7.0 LTS (YAML/JSON).

---

## 🏷️ 2. Nomenclatura e Identificação de Templates

### 2.1 Nome Técnico (`template`)
* **Regra Obrigatória:** O nome técnico é o identificador interno do host/template no Zabbix. Ele **NUNCA** deve conter caracteres especiais como `&`, `<`, `>`, `"`, `'` ou `/`.
* O uso de caracteres proibidos causa falhas imediatas na API e no importador Web do Zabbix (ex: erro `/1/host: invalid host name`).
* **Convenção de Nomenclatura:**
  `Template <Categoria> <Fabricante/Serviço> <Mecanismo>`
  * *Exemplo Correto:* `Template Nobreak APC UPS NUT`
  * *Exemplo Incorreto:* `Template Nobreak APC & Eaton (NUT)`

### 2.2 Nome Visível (`name`)
* O nome visível é exibido na interface gráfica (Frontend) do Zabbix. Deve ser claro e conter o método de coleta entre parênteses:
  * *Exemplo:* `Template Nobreak APC UPS NUT (Zabbix Agent)`

### 2.3 Grupo de Templates (`template_groups`)
* Todo template deve ser associado ao grupo oficial de templates do Zabbix (`Templates`), preservando o UUID padrão nativo da plataforma:
  ```yaml
  template_groups:
  - uuid: 7df96b18c230490a9a0a9e2307226338
    name: Templates
  ```

---

### 2.4 Descrição Operacional (`description`)

* Aplicar a todos os templates Zabbix criados ou atualizados.
* Incluir somente informações necessárias para instalar, configurar e fazer a coleta funcionar: requisitos, local de instalação do coletor, configuração do agente/UserParameter, interface do host, portas, macros com finalidade/valor padrão e dependências de outros templates.
* Informar o caminho real quando conhecido; usar placeholders explícitos quando o caminho depender do ambiente. Não presumir diretórios ou configurações que não foram confirmados.
* Não incluir histórico de alterações, o que foi criado/corrigido/atualizado, contagem de itens/triggers/gráficos, resumo de funcionalidades, resultados de testes ou relato da implementação.
* Manter migrações, procedimentos de atualização, limitações e validação em guias de `Ajuda/` ou documentação interna de `docs/`, conforme o público. Descrições de itens, triggers e macros devem explicar sua função operacional quando necessário.

---

## 🔑 3. Regra de Ouro: Unicidade Global de Chaves (`key`)

No Zabbix, **um mesmo host não pode herdar itens com a mesma chave vindos de templates distintos**.

### 3.1 Namespacing Obrigatório
* Toda e qualquer chave de item criada em templates customizados DEVE utilizar um prefixo exclusivo da aplicação ou serviço:
  * *Correto:* `nut.get[{$UPS_NAME},battery.charge]`, `nut.power_watts[...]`, `nginx.stub_status[...]`
  * *Incorreto:* `battery.charge`, `power_watts`, `status`

### 3.2 Proibição de Chaves de Sistema Operacional
* **NUNCA** inclua itens com chaves genéricas de SO em templates de periféricos ou aplicações, tais como:
  * `system.uptime` *(já monitorado por Template OS Linux / Windows)*
  * `system.hostname`
  * `system.cpu.*`
  * `vfs.fs.*`
  * `net.if.*`
* Se o template de nobreak tentar coletar o uptime usando a chave `system.uptime`, o Zabbix recusará a vinculação do template ao host com o erro:
  > `Cannot inherit item with key "system.uptime" of template "..." to host "...", because an item with the same key is already inherited from template "Template OS Linux".`

---

## 🗃️ 4. Isolamento Estrito de Inventário (`inventory_link`)

O Zabbix possui o recurso de preenchimento automático do inventário do Host (`Host Inventory`). Cada campo do inventário (`Name`, `OS`, `Serial Number`, `Type`, `Contact`, `Location`, etc.) só pode ser preenchido por **um único item por host**.

### 4.1 Regra de Ouro para Periféricos e Serviços
* **PROIBIÇÃO TOTAL de `inventory_link` em templates de periféricos, nobreaks e aplicações:**
  * Templates de nobreak (NUT/SNMP), banco de dados ou web servers **NUNCA** devem declarar a tag `inventory_link`.
* **Motivo:** O host físico/virtual é o servidor Linux/Windows, e o inventário primário pertence ao Sistema Operacional. Se o template do nobreak mapear `inventory_link: NAME`, colidirá com a chave `system.hostname` do template Linux, gerando o erro:
  > `Cannot inherit item with key "nut.get[...]" of template "..." to host "...", because its inventory field "Name" is already populated by the item with key "system.hostname".`
* As informações do equipamento (modelo, fabricante, firmware, número de série) devem ser armazenadas como itens regulares (`CHAR` ou `TEXT`) e exibidas normalmente em **Latest data** e dashboards, sem forçar vínculo com o inventário central do host.

---

## 🆔 5. Padrão de UUIDs (Identificadores RFC 4122)

A partir do Zabbix 6.0 LTS e em todo o Zabbix 7.0 LTS, cada elemento do template requer um identificador UUIDv4 estrito:
* **Formato Exigido:** Sequência hexadecimal de 32 caracteres minúsculos sem hífens (`^[0-9a-f]{32}$`).
  * *Correto:* `uuid: 10c88dfc48564d5292e5cba005de30b9`
  * *Incorreto:* `uuid: 10c88dfc-4856-4d52-92e5-cba005de30b9` *(com hífens)*
  * *Incorreto:* `uuid: nut_battery_status_item` *(texto livre)*
* **Unicidade Estrita:** Cada item, gatilho, gráfico e valuemap deve possuir um UUID único gerado aleatoriamente (ex: via `uuidgen` ou Python `uuid.uuid4().hex`). A colisão de UUIDs causa a sobrescrita inadvertida de itens durante a importação.

---

## 🏗️ 6. Estrutura Hierárquica do YAML (Zabbix 7.0 LTS Export Spec)

O parser YAML do Zabbix 7.0 LTS adota uma estrutura estrita quanto ao posicionamento de elementos. A estrutura deve seguir impreterivelmente o formato abaixo:

```yaml
zabbix_export:
  version: '7.0'
  template_groups:
    - uuid: 7df96b18c230490a9a0a9e2307226338
      name: Templates
  templates:
    - uuid: <UUID32_TEMPLATE>
      template: <NOME_TECNICO_TEMPLATE>
      name: <NOME_VISIVEL_TEMPLATE>
      groups:
        - name: Templates
      items:
        - uuid: <UUID32_ITEM>
          name: <NOME_ITEM>
          key: <CHAVE_COM_PREFIXO>
          # Propriedades do item...
          triggers:
            # Triggers simples vinculadas diretamente ao item
            - uuid: <UUID32_TRIGGER>
              name: <NOME_TRIGGER>
              expression: last(/<NOME_TECNICO>/<KEY>)<LIMIAR
              priority: AVERAGE
      valuemaps:
        # Mapeamentos de valor específicos do template
        - uuid: <UUID32_VALUEMAP>
          name: <NOME_VALUEMAP>
          mappings:
            - value: '1'
              newvalue: Normal
      macros:
        # Macros com valores padrão na raiz do template
        - macro: '{$MACRO_NAME}'
          value: <VALOR_PADRAO>
          description: <DESCRICAO>
      description: <DESCRICAO_DO_TEMPLATE>
  triggers:
    # Triggers compostas (multivariáveis) ficam no nó raiz do zabbix_export
    - uuid: <UUID32_TRIGGER_COMPOSTA>
      name: <NOME_TRIGGER>
      expression: last(...)>0 and last(...)>=0
      priority: HIGH
  graphs:
    # Gráficos ficam no nó raiz do zabbix_export
    - uuid: <UUID32_GRAFICO>
      name: <NOME_GRAFICO>
      graph_items:
        - item:
            host: <NOME_TECNICO_TEMPLATE>
            key: <CHAVE_COM_PREFIXO>
```

---

## ⚙️ 7. Padronização de Macros (`macros`)

1. **Sempre Fornecer Valores Padrão**: Todo template parametrizável DEVE declarar a seção `macros:` com valores padrão funcionais. Quando o template é vinculado ao host, as macros são automaticamente herdadas e podem ser customizadas pontualmente.
2. **Proteção de Variáveis em Scripts Shell**: Em scripts Bash que geram templates, caracteres como `$` em `{$UPS_NAME}` devem ser escapados como `\{\$UPS_NAME\}` para evitar que o Bash expanda para string vazia `{}`.
3. **Regra de Privacidade e Anonimização**:
   * Valores padrão de macros NUNCA devem conter nomes de clientes reais, IPs internos ou credenciais específicas.
   * Utilize sempre nomes genéricos padrão: `Cliente_Nobreak`, `Cliente_Servidor`.

---

## 🚨 8. Gatilhos (`triggers`) e Severidades

1. **Contextualização do Nome**: O nome do gatilho deve indicar claramente a origem e o sintoma do problema (ex: `Nobreak on Battery`, `Output Load Critical >85%`).
2. **Uso de Dados Operacionais (`opdata`)**: Sempre que útil, configure o campo `opdata` com macros dinâmicas para fornecer dados em tempo real na tela de problemas:
   * *Exemplo:* `opdata: 'Carga: {ITEM.LASTVALUE1}% | Autonomia: {ITEM.LASTVALUE2}s'`
3. **Mapeamento de Severidades Padronizado**:
   * `NOT_CLASSIFIED` / `INFO`: Eventos informativos (teste de bateria iniciado, modo eco).
   * `WARNING`: Avisos de prevenção (carga em bateria iniciada, temperatura elevada).
   * `AVERAGE`: Falhas com impacto moderado (bateria baixa, necessidade de troca de bateria).
   * `HIGH`: Risco iminente de parada (autonomia restante < 20 minutos).
   * `DISASTER`: Parada do serviço ou desligamento iminente (autonomia restante < 10 minutos).

---

## 📈 9. Gráficos e Cores Padronizadas (`graphs`)

1. **Cores Padrão de Engenharia**:
   * Verde (`00C800` ou `4CAF50`): Estados normais, carga de bateria saudável, região preenchida de capacidade.
   * Vermelho (`CC0000` ou `C80000`): Alarmes, autonomia crítica, linha de corrente máxima.
   * Azul (`0000CC` ou `1E88E5`): Tensões elétricas (entrada/saída) e frequências.
2. **Uso de Dois Eixos Y (`yaxisside`)**: Quando um gráfico combinar grandezas de escalas diferentes (ex: Carga da bateria em `%` e Autonomia em `segundos`), utilize `yaxisside: RIGHT` para a segunda grandeza.

---

## ✅ 10. Checklist de Validação Obrigatória Antes da Publicação

Antes de comitar qualquer novo template no repositório, realize os passos abaixo:

- [ ] **1. Validação de Sintaxe YAML**:
  Testar carregamento completo sem erros de parsing:
  ```python
  import yaml
  yaml.safe_load(open('zbx_template.yaml', encoding='utf-8'))
  ```
- [ ] **2. Validação de UUIDs**:
  Certificar-se de que todos os UUIDs possuem 32 caracteres hexadecimais minúsculos sem hífens.
- [ ] **3. Auditoria de Chaves e Conflitos com SO**:
  Garantir que todas as chaves possuem prefixo exclusivo e que nenhuma chave se sobreponha aos templates de SO (`Template OS Linux`, `Template OS Windows`).
- [ ] **4. Auditoria de Inventário**:
  Confirmar que nenhum item declara a diretiva `inventory_link`.
- [ ] **5. Teste de Importação Real no Zabbix 7.0**:
  Importar o template via interface Web (`Data collection ➔ Templates ➔ Import`).
- [ ] **6. Teste de Vinculação ao Host**:
  Associar o template a um host de teste que já contenha o template do Sistema Operacional e salvar com sucesso.


---

## 📡 11. Templates SNMP de nobreak — coleta e validação (01/10/2026)

- Usar OIDs numéricos conferidos na MIB do fabricante/padrão. Distinguir escalares (`.0`) de tabelas (índice de linha). Compatibilidade de MIB não significa que todos os objetos sejam implementados pelo firmware.
- Informar na descrição do template a configuração da interface do host: versão SNMP e uso da macro de comunidade. Para SNMPv2c, criar `{$SNMP_COMMUNITY}` no host e referenciá-la em **SNMP community**, sem incluir uma comunidade padrão real no YAML. A versão pertence à interface e não é definida por uma macro arbitrária `snmpversion`.
- Para coleta `walk[]` com itens dependentes, separar resposta de sistema e UPS-MIB quando isso facilitar distinguir disponibilidade da placa e telemetria do nobreak. Manter diagnóstico dos objetos ausentes e erros explicativos; nunca converter objeto não implementado em zero/estado normal.
- Conferir unidades na MIB: RFC 1628 fornece `upsSecondsOnBattery` em segundos e `upsEstimatedMinutesRemaining` em minutos; TimeTicks usa centésimos de segundo. Correntes/frequências e tensão DC podem exigir multiplicador `0.1`. Temperatura e corrente DC admitem valores assinados.
- Identificar tensão × corrente RMS como potência aparente em **VA**; potência ativa em **W** deve vir de medição própria. Não calcular potência ativa sem fator de potência medido/conhecido. Não agregar fases a partir de apenas uma linha.
- Estados devem ser traduzidos para linguagem operacional (por exemplo, **Bateria normal**, **Bateria baixa**, **Bateria esgotada**). `batteryDepleted` precisa de tratamento próprio; AVR não deve ser confundido automaticamente com falta de rede.
- Gatilhos de autonomia devem exigir operação em bateria e dados recentes. Faixas de carga/autonomia devem evitar sobreposição involuntária; usar histerese quando apropriado. Valores sentinela como `999` só podem ser filtrados após confirmação do fabricante/firmware, com estado desconhecido explícito.
- Checks nativos de tipo `SIMPLE`, como `icmpping`, `icmppingloss` e `icmppingsec`, constituem exceção técnica à seção 3.1: o Zabbix exige as chaves nativas e não aceita um prefixo customizado nelas. Usar parâmetros explícitos para reduzir colisões, auditar a chave completa contra outros templates e documentar `fping`, destino/interface e permissões ICMP. Todos os itens customizados/dependentes continuam obrigatoriamente com prefixo próprio.
- Preservar UUIDs de objetos existentes nas atualizações, salvo troca deliberada de identidade. Documentar mudanças de chave/unidade, efeitos no histórico e remoção de triggers legados. Não orientar **Unlink and clear** como atualização comum.
- Validar YAML, OIDs, referências, dependências e cenários da lógica. Registrar separadamente teste estático/sintético, importação real e coleta real. Executar somente consultas de leitura durante homologação; testes de bateria/desligamento exigem escopo autorizado específico.


### Perfil baseado em resposta real e migração de coleta

- Distinguir OID ausente de item sem histórico: um campo vazio no frontend não demonstra ausência do objeto. Confrontar resposta SNMP, configuração do item e coleta agendada antes de atribuir limitações ao firmware. Contagem de alarmes zero sem tabela não prova ausência permanente dessa tabela.
- Quando o escopo autorizado usar somente medições confirmadas, consultas SNMP diretas são uma alternativa aos walks. Preservar OIDs presentes mesmo que o item dependente anterior esteja vazio; remover apenas funcionalidades sem dados/escopo confirmado. Documentar consultas adicionais, escalas e limitações do perfil de equipamento.
- Cálculos baseados em consultas independentes não garantem simultaneidade. Verificar frescor das origens e tornar o cálculo indisponível quando elas estiverem antigas; não retornar zero nem regravar uma potência antiga como nova.
- Na migração de itens dependentes para coleta direta/calculada, importar em duas etapas: primeiro atualizar/criar com Delete missing de itens desmarcado e confirmar ausência de dependências mantidas; depois excluir os antigos mestres e demais objetos removidos. O importador 7.0 exclui itens ausentes antes de atualizar os existentes; apagar mestres cedo pode excluir dependentes em cascata. Preservar UUIDs/chaves e explicitar perda do histórico apenas dos itens removidos.
- Quando o usuário solicitar herdar ICMP de um template existente, essa composição é uma exceção autorizada ao requisito de template autocontido: declarar o nome técnico exato em templates, documentar a dependência e a opção Create new de Template linkage. Não copiar os itens locais de ping nem presumir que o nome customizado exista em instalações novas. Macros/severidades de ICMP pertencem ao template vinculado; não misturar seus totais com itens/triggers próprios.


## 🌐 12. Templates HTTP de aplicações de nobreak — coleta e validação (02/10/2026)

- Identificar o software e a versão compatível, distinguindo-os da interface SNMP e do firmware do nobreak. Versões incompatíveis exigem outro perfil/template. Quando a página fornece identificação de versão, validá-la antes de publicar medições.
- Com `HTTP_AGENT`, a origem da consulta é o servidor Zabbix ou o proxy responsável pelo host. Documentar a URL base vista por esse coletor, porta e conectividade; `localhost` pertence ao coletor. Preferir URL literal quando parametrizada em macro de usuário, sem depender de expansão de macros aninhadas. Ao usar `{HOST.CONN}` diretamente no campo URL, é necessária uma interface que aponte ao computador do software, e não necessariamente ao IP da placa SNMP. URL explícita pode dispensar interface Agent/SNMP.
- Usar somente endpoints de leitura observados. Não copiar URLs de outro fabricante nem visitar rotas de configuração/comandos para obter telemetria. Não exigir Zabbix Agent/UserParameter quando a coleta for inteiramente HTTP agent. Se o coletor não alcançar o software remoto, a conectividade/proxy é requisito de funcionamento.
- Validar título, seções e rótulos do HTML. Rótulos repetidos, como Estado, precisam ser isolados pela seção correspondente. Interpretar charset e entidades, vírgula decimal e unidade real; rejeitar campos ausentes/inválidos com diagnóstico explícito, sem converter falha em zero ou estado normal. HTML de mostradores preenchidos por JavaScript não comprova a presença de dados na resposta inicial; conferir os scripts/endpoints antes de criar itens.
- Preservar estados textuais até confirmar seu significado físico. Usar alertas genéricos de estado diferente do esperado quando houver somente amostras de estados normais; regex configurável não transforma estado desconhecido em operação em bateria/bypass. Tensão DC não é percentual da bateria, e carga do nobreak em % não é potência em W/VA.
- Separar consulta HTTP, interpretação da página e atualidade física do equipamento. Diagnósticos de parsing e `nodata()` têm funções diferentes. Alertas de telemetria e sua recuperação devem exigir dados recentes e válidos; reconsultar uma página sem timestamp da medição não prova que o software atualizou a amostra serial/USB.
- Manter configurações nominais, estados e medições em itens distintos, com prefixo específico do mecanismo quando houver outro template do mesmo fabricante. Não transformar extremos históricos em limites nominais ou disparar alertas elétricos usando configurações cuja faixa ativa não foi confirmada.
- Validar parsing com respostas reais e cenários inválidos, incluindo versão incompatível, página errada, campos/unidades ausentes e zeros legítimos. Se disponível, executar somente o código de pré-processamento próprio no Duktape já instalado em ambiente de teste. Separar isso de importação/vinculação/coleta reais e da validação nativa das expressões no Zabbix.

- Conferir nomes de campos e enums contra o validador oficial da versão de exportação, além de reler o YAML e testar o pré-processamento. Em gráficos 7.0, usar `yaxismin`/`yaxismax` para os valores; `ymin_type_1`/`ymax_type_1` definem o modo. `ymin_1` não é um campo do export. Uma dependência de trigger precisa repetir a identidade completa do destino: `name`, `expression` e, quando houver recuperação customizada, `recovery_expression`. Omitir a recuperação pode produzir "trigger does not exist" mesmo com o alerta declarado. A conferência estática não substitui a importação no Zabbix.
