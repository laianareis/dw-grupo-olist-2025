import duckdb
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

# Configuração de Diretório
output_dir = "output_img"
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# Configuração Estética
sns.set_theme(style="whitegrid")
plt.rcParams['figure.figsize'] = (12, 6)
plt.rcParams['savefig.bbox'] = 'tight' # Garante que nada fique cortado

# Conexão ao DW (Ajuste o caminho se necessário)
con = duckdb.connect('olist_dw.duckdb') # ou o nome do seu arquivo .db

print(f"Gerando gráficos em: {os.path.abspath(output_dir)}")

# ---------------------------------------------------------
# 1. IMPACTO DO ATRASO NA SATISFAÇÃO (Boxplot)
# ---------------------------------------------------------
print("1/4 - Processando Delivery Gap...")
query_delay = """
SELECT 
    CASE 
        WHEN (order_delivered_customer_date::DATE - order_estimated_delivery_date::DATE) > 0 THEN 'Atrasado'
        WHEN (order_delivered_customer_date::DATE - order_estimated_delivery_date::DATE) < -2 THEN 'Antecipado (>2 dias)'
        ELSE 'No Prazo'
    END AS status_entrega,
    review_score
FROM fact_sales fs
JOIN oltp_orders o ON fs.order_id = o.order_id
JOIN stg_reviews r ON fs.order_id = r.order_id
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL;
"""
df_delay = con.execute(query_delay).df()

plt.figure()
sns.boxplot(x='status_entrega', y='review_score', data=df_delay, palette='coolwarm', order=['Antecipado (>2 dias)', 'No Prazo', 'Atrasado'])
plt.title('Impacto do Cumprimento do Prazo no Review Score')
plt.ylabel('Nota (1-5)')
plt.xlabel('Status da Entrega')
plt.savefig(f"{output_dir}/01_delivery_impact.png")
plt.close()

# ---------------------------------------------------------
# 2. BARREIRA GEOGRÁFICA: RATIO FRETE/PRODUTO (Barplot)
# ---------------------------------------------------------
print("2/4 - Processando Frete...")
query_freight = """
SELECT 
    dc.customer_state,
    AVG(fs.freight_value / NULLIF(fs.price, 0)) * 100 as ratio_frete
FROM fact_sales fs
JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer
GROUP BY 1
HAVING COUNT(*) > 50
ORDER BY ratio_frete DESC;
"""
df_freight = con.execute(query_freight).df()

plt.figure(figsize=(12, 8))
sns.barplot(x='ratio_frete', y='customer_state', data=df_freight, palette='viridis')
plt.axvline(x=20, color='r', linestyle='--', label='Zona de Risco (>20%)')
plt.title('Peso do Frete no Custo Total por Estado')
plt.xlabel('% do Frete sobre o Valor do Produto')
plt.ylabel('Estado')
plt.legend()
plt.savefig(f"{output_dir}/02_freight_ratio.png")
plt.close()

# ---------------------------------------------------------
# 3. PERFIL DE RETENÇÃO (Donut Chart)
# ---------------------------------------------------------
print("3/4 - Processando Retenção...")
query_retention = """
WITH freq AS (
    SELECT dc.customer_unique_id, COUNT(DISTINCT fs.order_id) as qtd
    FROM fact_sales fs JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer
    GROUP BY 1
)
SELECT 
    CASE WHEN qtd = 1 THEN 'Compra Única' ELSE 'Recorrente' END as tipo,
    COUNT(*) as total
FROM freq GROUP BY 1;
"""
df_retention = con.execute(query_retention).df()

plt.figure()
plt.pie(df_retention['total'], labels=df_retention['tipo'], autopct='%1.1f%%', startangle=90, colors=['#ff9999','#66b3ff'])
plt.title('Share de Clientes: Únicos vs Recorrentes')
my_circle = plt.Circle((0,0), 0.7, color='white')
p = plt.gcf()
p.gca().add_artist(my_circle)
plt.savefig(f"{output_dir}/03_retention_rate.png")
plt.close()

# ---------------------------------------------------------
# 4. ALAVANCAGEM DE CRÉDITO (Lineplot)
# ---------------------------------------------------------
print("4/4 - Processando Crédito...")
query_credit = """
SELECT 
    payment_installments,
    AVG(payment_value) as ticket_medio
FROM fact_sales
WHERE payment_installments BETWEEN 1 AND 12
GROUP BY 1
ORDER BY 1;
"""
df_credit = con.execute(query_credit).df()

plt.figure()
sns.lineplot(x='payment_installments', y='ticket_medio', data=df_credit, marker='o', linewidth=2.5)
plt.fill_between(df_credit['payment_installments'], 0, df_credit['ticket_medio'], alpha=0.1)
plt.title('Ticket Médio por Número de Parcelas')
plt.xlabel('Parcelas')
plt.ylabel('Valor Médio do Pedido (R$)')
plt.xticks(range(1, 13))
plt.savefig(f"{output_dir}/04_credit_leverage.png")
plt.close()

# ==============================================================================
# 1. GRÁFICO DE LINHA (Evolução no Tempo)
# Análise: Receita Total (GMV) por Mês
# ==============================================================================
print("Gerando 1. Evolução Temporal...")
query_line = """
    SELECT 
        strftime(date_key, '%Y-%m') as mes_ano,
        SUM(payment_value) as receita
    FROM fact_sales
    GROUP BY 1
    ORDER BY 1
"""
df_line = con.execute(query_line).df()

fig1 = px.line(df_line, x='mes_ano', y='receita', 
               title='Evolução da Receita Mensal (GMV)',
               markers=True)
fig1.update_layout(xaxis_title='Mês', yaxis_title='Receita (R$)')
fig1.write_image(f"{output_dir}/obrigatorio_1_evolucao_vendas.png")

# ==============================================================================
# 2. GRÁFICO DE BARRAS (Comparação)
# Análise: Top 10 Categorias de Produto por Receita
# ==============================================================================
print("Gerando 2. Comparação (Top 10 Categorias)...")
query_bar = """
    SELECT 
        dp.product_category_name as categoria,
        SUM(fs.payment_value) as receita
    FROM fact_sales fs
    JOIN dim_product dp ON fs.sk_product = dp.sk_product
    WHERE dp.product_category_name IS NOT NULL
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 10
"""
df_bar = con.execute(query_bar).df()

fig2 = px.bar(df_bar, x='receita', y='categoria', orientation='h',
              title='Top 10 Categorias por Faturamento',
              text_auto='.2s') # Formatação de K/M
fig2.update_layout(yaxis={'categoryorder':'total ascending'})
fig2.write_image(f"{output_dir}/obrigatorio_2_top_categorias.png")

# ==============================================================================
# 3. MAPA DE CALOR (Correlação/Padrão)
# Análise: Vendas por Estado (Linha) vs Dia da Semana (Coluna)
# Mostra: Qual dia da semana cada estado compra mais?
# ==============================================================================
print("Gerando 3. Mapa de Calor (Padrões de Compra)...")
query_heatmap = """
    SELECT 
        dc.customer_state as estado,
        dd.day_name as dia_semana,
        CASE dd.day_name 
            WHEN 'Sunday' THEN 1 WHEN 'Monday' THEN 2 WHEN 'Tuesday' THEN 3 
            WHEN 'Wednesday' THEN 4 WHEN 'Thursday' THEN 5 WHEN 'Friday' THEN 6 WHEN 'Saturday' THEN 7 
        END as dia_num,
        COUNT(fs.order_id) as qtd_vendas
    FROM fact_sales fs
    JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer
    JOIN dim_date dd ON fs.date_key = dd.date_key
    WHERE dc.customer_state IN ('SP', 'RJ', 'MG', 'RS', 'PR', 'SC', 'BA') -- Top estados para limpar visual
    GROUP BY 1, 2, 3
    ORDER BY 1, 3
"""
df_heatmap = con.execute(query_heatmap).df()

# Pivotar para formato de matriz
matrix_heatmap = df_heatmap.pivot(index='estado', columns='dia_semana', values='qtd_vendas')
# Reordenar colunas
dias_ordem = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
matrix_heatmap = matrix_heatmap[dias_ordem]

fig3 = px.imshow(matrix_heatmap, 
                 labels=dict(x="Dia da Semana", y="Estado", color="Vendas"),
                 title="Concentração de Vendas: Estado vs Dia da Semana",
                 aspect="auto")
fig3.write_image(f"{output_dir}/obrigatorio_3_heatmap.png")

# ==============================================================================
# 4. DASHBOARD / COMPOSIÇÃO
# Consolida 4 visões em um arquivo HTML e PNG
# ==============================================================================
print("Gerando 4. Dashboard Completo...")

# Criar estrutura de subplots (2 linhas x 2 colunas)
fig_dash = make_subplots(
    rows=2, cols=2,
    subplot_titles=("Evolução Receita", "Top Categorias", "Scatter: Frete vs Preço", "Vendas por Estado"),
    specs=[[{"type": "xy"}, {"type": "xy"}],
           [{"type": "xy"}, {"type": "xy"}]]
)

# A. Adicionar Linha (Trace 1)
fig_dash.add_trace(
    go.Scatter(x=df_line['mes_ano'], y=df_line['receita'], name="Receita"),
    row=1, col=1
)

# B. Adicionar Barra (Trace 2)
fig_dash.add_trace(
    go.Bar(x=df_bar['categoria'], y=df_bar['receita'], name="Categorias"),
    row=1, col=2
)

# C. Adicionar Scatter (Dispersão - Correlação Preço x Frete)
# Amostra aleatória para não pesar o gráfico
query_scatter = """
    SELECT price, freight_value 
    FROM fact_sales 
    USING SAMPLE 1000
    WHERE price < 2000 AND freight_value < 200
"""
df_scatter = con.execute(query_scatter).df()
fig_dash.add_trace(
    go.Scatter(x=df_scatter['price'], y=df_scatter['freight_value'], mode='markers', 
               marker=dict(size=4, opacity=0.5), name="Frete x Preço"),
    row=2, col=1
)

# D. Adicionar Barra Vertical (Vendas por Estado)
query_state = "SELECT dc.customer_state, COUNT(*) as qtd FROM fact_sales fs JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer GROUP BY 1 ORDER BY 2 DESC LIMIT 5"
df_state = con.execute(query_state).df()
fig_dash.add_trace(
    go.Bar(x=df_state['customer_state'], y=df_state['qtd'], name="Vol. por Estado"),
    row=2, col=2
)

# Layout Final do Dashboard
fig_dash.update_layout(height=800, width=1200, title_text="Dashboard Executivo Olist", showlegend=False)

# Exportar
fig_dash.write_html(f"{output_dir}/dashboard_completo.html")
fig_dash.write_image(f"{output_dir}/obrigatorio_4_dashboard.png")

print(f"Sucesso. Arquivos gerados em {os.path.abspath(output_dir)}")

print("Sucesso. Gráficos salvos em:", os.path.abspath(output_dir))

