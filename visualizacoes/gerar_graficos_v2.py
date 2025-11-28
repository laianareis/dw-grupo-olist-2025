import duckdb
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os
import sys

# --- CONFIGURAÇÃO ---
DB_FILENAME = 'olist_dw.duckdb' # Nome do arquivo gerado pelo run_all.ps1
OUTPUT_DIR = "visualizacoes"

# Configuração Estética Global
sns.set_theme(style="whitegrid")
plt.rcParams['figure.figsize'] = (12, 6)
plt.rcParams['savefig.bbox'] = 'tight'

def setup_environment():
    """Cria diretórios e localiza o banco de dados."""
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"[INFO] Diretório criado: {os.path.abspath(OUTPUT_DIR)}")

    # Tenta localizar o DB na raiz ou na pasta atual
    base_path = os.path.dirname(os.path.dirname(__file__))
    db_path = os.path.join(base_path, DB_FILENAME)
    
    if not os.path.exists(db_path):
        db_path = DB_FILENAME # Tenta na pasta atual
        if not os.path.exists(db_path):
            print(f"[ERRO] Banco de dados '{DB_FILENAME}' não encontrado.")
            sys.exit(1)
            
    return db_path

def get_data(con, query):
    """Executa query e retorna DataFrame."""
    return con.execute(query).df()

# --- GRÁFICOS ESTÁTICOS (SEABORN/MATPLOTLIB) ---

def plot_delivery_impact(con):
    """
    1. Boxplot: Impacto do Atraso na Satisfação (Review Score).
    Analisa se a punição por atraso é maior que a recompensa por antecipação.
    """
    print("   [1/8] Gerando Boxplot: Delivery Gap...")
    query = """
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
    df = get_data(con, query)
    
    plt.figure()
    sns.boxplot(x='status_entrega', y='review_score', data=df, palette='coolwarm', 
                order=['Antecipado (>2 dias)', 'No Prazo', 'Atrasado'])
    plt.title('Impacto do Cumprimento do Prazo no Review Score')
    plt.ylabel('Nota (1-5)')
    plt.xlabel('Status da Entrega')
    plt.savefig(f"{OUTPUT_DIR}/01_delivery_impact.png")
    plt.close()

def plot_freight_ratio(con):
    """
    2. Barplot: Peso do Frete no Custo Total.
    Identifica barreiras geográficas onde o frete inviabiliza a compra.
    """
    print("   [2/8] Gerando Barplot: Freight Ratio...")
    query = """
    SELECT 
        dc.customer_state,
        AVG(fs.freight_value / NULLIF(fs.price, 0)) * 100 as ratio_frete
    FROM fact_sales fs
    JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer
    GROUP BY 1
    HAVING COUNT(*) > 50
    ORDER BY ratio_frete DESC;
    """
    df = get_data(con, query)

    plt.figure(figsize=(12, 8))
    sns.barplot(x='ratio_frete', y='customer_state', data=df, palette='viridis')
    plt.axvline(x=20, color='r', linestyle='--', label='Zona de Risco (>20%)')
    plt.title('Peso do Frete no Custo Total por Estado')
    plt.xlabel('% do Frete sobre o Valor do Produto')
    plt.ylabel('Estado')
    plt.legend()
    plt.savefig(f"{OUTPUT_DIR}/02_freight_ratio.png")
    plt.close()

def plot_retention_profile(con):
    """
    3. Donut Chart: Retenção Real (Customer Unique ID).
    Define se o modelo de negócio é transacional (One-off) ou relacional.
    """
    print("   [3/8] Gerando Pie Chart: Retenção...")
    query = """
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
    df = get_data(con, query)

    plt.figure()
    plt.pie(df['total'], labels=df['tipo'], autopct='%1.1f%%', startangle=90, colors=['#ff9999','#66b3ff'])
    plt.title('Share de Clientes: Únicos vs Recorrentes')
    my_circle = plt.Circle((0,0), 0.7, color='white')
    plt.gcf().gca().add_artist(my_circle)
    plt.savefig(f"{OUTPUT_DIR}/03_retention_rate.png")
    plt.close()

def plot_credit_leverage(con):
    """
    4. Lineplot: Ticket Médio vs Parcelamento.
    Analisa a elasticidade do consumidor ao crédito.
    """
    print("   [4/8] Gerando Lineplot: Crédito...")
    query = """
    SELECT 
        payment_installments,
        AVG(payment_value) as ticket_medio
    FROM fact_sales
    WHERE payment_installments BETWEEN 1 AND 12
    GROUP BY 1
    ORDER BY 1;
    """
    df = get_data(con, query)

    plt.figure()
    sns.lineplot(x='payment_installments', y='ticket_medio', data=df, marker='o', linewidth=2.5)
    plt.fill_between(df['payment_installments'], 0, df['ticket_medio'], alpha=0.1)
    plt.title('Ticket Médio por Número de Parcelas')
    plt.xlabel('Parcelas')
    plt.ylabel('Valor Médio do Pedido (R$)')
    plt.xticks(range(1, 13))
    plt.savefig(f"{OUTPUT_DIR}/04_credit_leverage.png")
    plt.close()

# --- GRÁFICOS INTERATIVOS/OBRIGATÓRIOS (PLOTLY) ---

def plot_sales_evolution(con):
    """
    5. Plotly Line: Evolução Temporal (Obrigatório 1).
    """
    print("   [5/8] Gerando Plotly: Evolução Temporal...")
    query = """
    SELECT 
        strftime(date_key, '%Y-%m') as mes_ano,
        SUM(payment_value) as receita
    FROM fact_sales
    GROUP BY 1
    ORDER BY 1
    """
    df = get_data(con, query)

    fig = px.line(df, x='mes_ano', y='receita', 
                  title='Evolução da Receita Mensal (GMV)', markers=True)
    fig.update_layout(xaxis_title='Mês', yaxis_title='Receita (R$)')
    fig.write_image(f"{OUTPUT_DIR}/obrigatorio_1_evolucao_vendas.png")
    return df # Retorna para uso no dashboard

def plot_top_categories(con):
    """
    6. Plotly Bar: Comparação de Categorias (Obrigatório 2).
    """
    print("   [6/8] Gerando Plotly: Top Categorias...")
    query = """
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
    df = get_data(con, query)

    fig = px.bar(df, x='receita', y='categoria', orientation='h',
                 title='Top 10 Categorias por Faturamento', text_auto='.2s')
    fig.update_layout(yaxis={'categoryorder':'total ascending'})
    fig.write_image(f"{OUTPUT_DIR}/obrigatorio_2_top_categorias.png")
    return df

def plot_heatmap_geo(con):
    """
    7. Plotly Heatmap: Correlação Estado vs Dia da Semana (Obrigatório 3).
    """
    print("   [7/8] Gerando Plotly: Heatmap Geográfico...")
    query = """
    SELECT 
        dc.customer_state as estado,
        dd.day_name as dia_semana,
        COUNT(fs.order_id) as qtd_vendas
    FROM fact_sales fs
    JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer
    JOIN dim_date dd ON fs.date_key = dd.date_key
    WHERE dc.customer_state IN ('SP', 'RJ', 'MG', 'RS', 'PR', 'SC', 'BA')
    GROUP BY 1, 2
    """
    df = get_data(con, query)
    
    # Pivotar
    matrix = df.pivot(index='estado', columns='dia_semana', values='qtd_vendas')
    # Ordenar dias
    dias_ordem = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
    matrix = matrix[dias_ordem]

    fig = px.imshow(matrix, labels=dict(x="Dia", y="Estado", color="Vendas"),
                    title="Concentração de Vendas: Estado vs Dia da Semana")
    fig.write_image(f"{OUTPUT_DIR}/obrigatorio_3_heatmap.png")

def plot_dashboard(con, df_line, df_bar):
    """
    8. Plotly Dashboard: Composição (Obrigatório 4).
    Reutiliza dados anteriores e adiciona Scatter plot.
    """
    print("   [8/8] Gerando Dashboard Completo...")
    
    # Query extra para o Scatter
    df_scatter = get_data(con, """
        SELECT price, freight_value 
        FROM fact_sales USING SAMPLE 1000 
        WHERE price < 2000 AND freight_value < 200
    """)

    # Query extra para barras
    df_state = get_data(con, """
        SELECT dc.customer_state, COUNT(*) as qtd 
        FROM fact_sales fs JOIN dim_customer dc ON fs.sk_customer = dc.sk_customer 
        GROUP BY 1 ORDER BY 2 DESC LIMIT 5
    """)

    fig = make_subplots(
        rows=2, cols=2,
        subplot_titles=("Evolução Receita", "Top Categorias", "Scatter: Frete vs Preço", "Vol. por Estado"),
        specs=[[{"type": "xy"}, {"type": "xy"}], [{"type": "xy"}, {"type": "xy"}]]
    )

    # Adiciona Traces
    fig.add_trace(go.Scatter(x=df_line['mes_ano'], y=df_line['receita'], name="Receita"), row=1, col=1)
    fig.add_trace(go.Bar(x=df_bar['categoria'], y=df_bar['receita'], name="Categorias"), row=1, col=2)
    fig.add_trace(go.Scatter(x=df_scatter['price'], y=df_scatter['freight_value'], mode='markers', 
                             marker=dict(size=4, opacity=0.5), name="Frete x Preço"), row=2, col=1)
    fig.add_trace(go.Bar(x=df_state['customer_state'], y=df_state['qtd'], name="Vol. Estado"), row=2, col=2)

    fig.update_layout(height=800, width=1200, title_text="Dashboard Executivo Olist", showlegend=False)
    
    fig.write_html(f"{OUTPUT_DIR}/dashboard_completo.html")
    fig.write_image(f"{OUTPUT_DIR}/obrigatorio_4_dashboard.png")

# --- EXECUÇÃO PRINCIPAL ---

def main():
    db_path = setup_environment()
    print(f"--- Iniciando Geração de Gráficos ---")
    print(f"Conectado a: {db_path}")
    
    con = duckdb.connect(db_path, read_only=True)

    try:
        # Gráficos Analíticos (Seaborn)
        plot_delivery_impact(con)
        plot_freight_ratio(con)
        plot_retention_profile(con)
        plot_credit_leverage(con)

        # Gráficos Obrigatórios (Plotly)
        df_line = plot_sales_evolution(con)
        df_bar = plot_top_categories(con)
        plot_heatmap_geo(con)
        plot_dashboard(con, df_line, df_bar)

    except Exception as e:
        print(f"\n[ERRO CRÍTICO] Falha na geração: {e}")
    finally:
        con.close()
        print(f"\n--- Concluído. Imagens salvas em: {os.path.abspath(OUTPUT_DIR)} ---")

if __name__ == "__main__":
    main()