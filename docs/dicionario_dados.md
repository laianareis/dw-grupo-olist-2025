# Dicionário de Dados - Olist DW

Documentação técnica das tabelas e colunas do Data Warehouse (Schema: `dw`).

## 1. Fatos

### `dw.fact_sales`

Descrição: Tabela transacional contendo o detalhe dos itens vendidos nos pedidos.

Granularidade: Uma linha por item de pedido (Order Item).

|**Coluna**|**Tipo**|**Chave**|**Descrição**|
|---|---|---|---|
|`sk_sales`|INTEGER|**PK**|Chave substituta (Surrogate Key) sequencial da tabela fato.|
|`order_id`|VARCHAR|NK|ID original do pedido (Natural Key).|
|`order_item_id`|INTEGER||Número sequencial do item dentro do mesmo pedido (1, 2, 3...).|
|`sk_customer`|INTEGER|FK|Referência para `dw.dim_customer`.|
|`sk_product`|INTEGER|FK|Referência para `dw.dim_product`.|
|`sk_seller`|INTEGER|FK|Referência para `dw.dim_seller`.|
|`date_key`|INTEGER|FK|Referência para `dw.dim_date` (Data da compra - `purchase_ts`).|
|`price`|NUMERIC||Valor unitário do item (sem frete).|
|`freight_value`|NUMERIC||Valor do frete rateado para este item.|
|`total_amount`|NUMERIC||Soma de `price` + `freight_value`.|
|`payment_installments`|INTEGER||Número de parcelas do pagamento associado.|
|`payment_type`|VARCHAR||Método de pagamento principal (credit_card, boleto, etc.).|
|`loaded_at`|TIMESTAMP||Data e hora da carga do registro no DW.|

---

## 2. Dimensões

### `dw.dim_customer` (SCD Tipo 2)

**Descrição:** Cadastro de clientes. Utiliza _Slowly Changing Dimension Type 2_ para rastrear mudanças de localização (cidade/estado) ao longo do tempo.

|**Coluna**|**Tipo**|**Chave**|**Descrição**|
|---|---|---|---|
|`sk_customer`|INTEGER|**PK**|Chave substituta única para cada versão do registro do cliente.|
|`customer_unique_id`|VARCHAR|NK|ID único do cliente (CPF mascarado/identificador real).|
|`city`|VARCHAR||Cidade do cliente no momento da compra.|
|`state`|VARCHAR||Estado (UF) do cliente no momento da compra.|
|`valid_from`|TIMESTAMP||Início da validade deste registro (histórico).|
|`valid_to`|TIMESTAMP||Fim da validade deste registro. (Atual = `9999-12-31`).|
|`is_current`|BOOLEAN||Flag que indica o registro ativo (`TRUE` = endereço atual).|
|`record_hash`|VARCHAR||Hash MD5 das colunas monitoradas para detecção de mudanças.|

### `dw.dim_product` (SCD Tipo 1)

**Descrição:** Catálogo de produtos vendidos. Sobrescrita simples em caso de atualização (não guarda histórico de mudanças de categoria).

|**Coluna**|**Tipo**|**Chave**|**Descrição**|
|---|---|---|---|
|`sk_product`|INTEGER|**PK**|Chave substituta do produto.|
|`product_id`|VARCHAR|NK|ID original do produto (hash do Olist).|
|`category_name`|VARCHAR||Categoria do produto (traduzida para Inglês, se disponível).|
|`weight_g`|NUMERIC||Peso do produto em gramas.|

### `dw.dim_seller` (SCD Tipo 0)

**Descrição:** Dados dos vendedores (sellers) parceiros. Considerado estático para este projeto.

|**Coluna**|**Tipo**|**Chave**|**Descrição**|
|---|---|---|---|
|`sk_seller`|INTEGER|**PK**|Chave substituta do vendedor.|
|`seller_id`|VARCHAR|NK|ID original do vendedor.|
|`city`|VARCHAR||Cidade de origem do vendedor.|
|`state`|VARCHAR||Estado (UF) de origem do vendedor.|

### `dw.dim_date`

**Descrição:** Dimensão de calendário canônico para navegação temporal.

|**Coluna**|**Tipo**|**Chave**|**Descrição**|
|---|---|---|---|
|`date_key`|INTEGER|**PK**|Data no formato inteiro `YYYYMMDD`.|
|`full_date`|DATE||Data completa (`YYYY-MM-DD`).|
|`year`|INTEGER||Ano (Ex: 2018).|
|`quarter`|INTEGER||Trimestre (1 a 4).|
|`month`|INTEGER||Mês numérico (1 a 12).|
|`month_name`|VARCHAR||Nome do mês (January, February...).|
|`day_of_week`|VARCHAR||Dia da semana (Monday, Tuesday...).|

---

## 3. Legenda

- **PK:** Primary Key (Chave Primária).
    
- **FK:** Foreign Key (Chave Estrangeira).
    
- **NK:** Natural Key (Chave de Negócio/Original).
    
- **SCD:** Slowly Changing Dimension (Dimensão de Mudança Lenta).