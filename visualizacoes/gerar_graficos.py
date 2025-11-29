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
DB_FILENAME = 'olist_dw.duckdb' 
OUTPUT_DIR = "visualizacoes"

# Configuração Estética Global
sns.set_theme(style="whitegrid")
plt.rcParams['figure.figsize'] = (12, 6)
plt.rcParams['savefig.bbox'] = 'tight'

def setup_environment():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"[INFO] Diretório criado: {os.path.abspath(OUTPUT_DIR)}")

    if os.path.exists(DB_FILENAME):
        return DB_FILENAME
    
    base_path = os.path.dirname(os.path.dirname(__file__))
    db_path = os.path.join(base_path, DB_FILENAME)
    
    if os.path.exists(db_path):
        return db_path
        
    print(f"[ERRO] Banco de dados '{DB_FILENAME}' não encontrado.")
    sys.exit(1)

def get_data(con, query):
    return con.execute(query).df()

# --- GRÁFICOS ESTÁTICOS (SEABORN - PNG) ---

def plot_delivery_impact(con):
    print("   [1/8] Gerando Boxplot: Delivery Gap...")
    # CORREÇÃO: Usando staging.stg_orders para acessar datas reais de entrega
    query = """
    SELECT 
        CASE 
            WHEN CAST(o.order_delivered_customer_date AS TIMESTAMP) > CAST(o.order_estimated_delivery_date AS TIMESTAMP) THEN 'Atrasado'
            WHEN CAST(o.order_delivered_customer_date AS TIMESTAMP) < (CAST(o.order_estimated_delivery_date AS TIMESTAMP) - INTERVAL 2 DAY) THEN 'Antecipado (>2 dias)'
            ELSE 'No Prazo'
        END AS status_entrega,
        r.review_score
    FROM staging.stg_orders o
    JOIN staging.stg_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
    LIMIT 10000;
    """
    df = get_data(con, query)
    
    if df.empty:
        print("   [AVISO] Dados insuficientes para Delivery Gap.")
        return

    plt.figure()
    # Ordem forçada para visualização lógica
    order_list = ['Antecipado (>2 dias)', 'No Prazo', 'Atrasado']
    # Filtra apenas o que existe no DF para evitar erro do Seaborn
    existing_order = [x for x in order_list if x in df['status_entrega'].unique()]
    
    sns.boxplot(x='status_entrega', y='review_score', data=df, hue='status_entrega', 
                palette='coolwarm', legend=False, order=existing_order)
    plt.title('Impacto do Prazo de Entrega na Nota (Review Score)')
    plt.ylabel('Nota (1-5)')
    plt.savefig(f"{OUTPUT_DIR}/01_delivery_impact.png")
    plt.close()

def plot_freight_ratio(con):
    print("   [2/8] Gerando Barplot: Freight Ratio...")
    query = """
    SELECT 
        dc.state,
        AVG(fs.freight_value / NULLIF(fs.price, 0)) * 100 as ratio_frete
    FROM dw.fact_sales fs
    JOIN dw.dim_customer dc ON fs.sk_customer = dc.sk_customer
    GROUP BY 1
    HAVING COUNT(*) > 50
    ORDER BY ratio_frete DESC;
    """
    df = get_data(con, query)

    plt.figure(figsize=(12, 8))
    sns.barplot(x='ratio_frete', y='state', data=df, hue='state', 
                palette='viridis', legend=False)
    plt.axvline(x=20, color='r', linestyle='--', label='Zona de Risco (>20%)')
    plt.title('Peso do Frete no Custo Total por Estado')
    plt.xlabel('% do Frete sobre Valor do Produto')
    plt.legend()
    plt.savefig(f"{OUTPUT_DIR}/02_freight_ratio.png")
    plt.close()

def plot_retention_profile(con):
    print("   [3/8] Gerando Pie Chart: Retenção...")
    query = """
    WITH freq AS (
        SELECT dc.customer_unique_id, COUNT(DISTINCT fs.order_id) as qtd
        FROM dw.fact_sales fs JOIN dw.dim_customer dc ON fs.sk_customer = dc.sk_customer
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
    plt.savefig(f"{OUTPUT_DIR}/03_retention_rate.png")
    plt.close()

def plot_credit_leverage(con):
    print("   [4/8] Gerando Lineplot: Crédito...")
    query = """
    SELECT 
        payment_installments,
        AVG(total_amount) as ticket_medio
    FROM dw.fact_sales
    WHERE payment_installments BETWEEN 1 AND 12
    GROUP BY 1
    ORDER BY 1;
    """
    df = get_data(con, query)

    plt.figure()
    sns.lineplot(x='payment_installments', y='ticket_medio', data=df, marker='o', linewidth=2.5)
    plt.title('Ticket Médio por Número de Parcelas')
    plt.xlabel('Parcelas')
    plt.ylabel('Valor Médio (R$)')
    plt.savefig(f"{OUTPUT_DIR}/04_credit_leverage.png")
    plt.close()

# --- GRÁFICOS INTERATIVOS (PLOTLY - HTML) ---

def plot_sales_evolution(con):
    print("   [5/8] Gerando Plotly HTML: Evolução Temporal...")
    query = """
    SELECT 
        d.year || '-' || printf('%02d', d.month) as mes_ano,
        SUM(fs.total_amount) as receita
    FROM dw.fact_sales fs
    JOIN dw.dim_date d ON fs.date_key = d.date_key
    GROUP BY 1
    ORDER BY 1
    """
    df = get_data(con, query)

    fig = px.line(df, x='mes_ano', y='receita', title='Evolução da Receita Mensal')
    fig.write_html(f"{OUTPUT_DIR}/obrigatorio_1_evolucao_vendas.html")
    return df

def plot_top_categories(con):
    print("   [6/8] Gerando Plotly HTML: Top Categorias...")
    query = """
    SELECT 
        dp.category_name as categoria,
        SUM(fs.total_amount) as receita
    FROM dw.fact_sales fs
    JOIN dw.dim_product dp ON fs.sk_product = dp.sk_product
    WHERE dp.category_name IS NOT NULL
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 10
    """
    df = get_data(con, query)

    fig = px.bar(df, x='receita', y='categoria', orientation='h', title='Top 10 Categorias')
    fig.update_layout(yaxis={'categoryorder':'total ascending'})
    fig.write_html(f"{OUTPUT_DIR}/obrigatorio_2_top_categorias.html")
    return df

def plot_heatmap_geo(con):
    print("   [7/8] Gerando Plotly HTML: Heatmap Geográfico...")
    query = """
    SELECT 
        dc.state as estado,
        d.day_of_week as dia_semana,
        COUNT(fs.order_id) as qtd_vendas
    FROM dw.fact_sales fs
    JOIN dw.dim_customer dc ON fs.sk_customer = dc.sk_customer
    JOIN dw.dim_date d ON fs.date_key = d.date_key
    WHERE dc.state IN ('SP', 'RJ', 'MG', 'RS', 'PR', 'SC', 'BA')
    GROUP BY 1, 2
    """
    df = get_data(con, query)
    
    matrix = df.pivot(index='estado', columns='dia_semana', values='qtd_vendas')
    fig = px.imshow(matrix, title="Concentração de Vendas: Estado vs Dia")
    fig.write_html(f"{OUTPUT_DIR}/obrigatorio_3_heatmap.html")

def plot_dashboard(con, df_line, df_bar):
    print("   [8/8] Gerando Dashboard HTML Completo...")
    
    df_scatter = get_data(con, """
        SELECT price, freight_value 
        FROM dw.fact_sales 
        WHERE price < 2000 AND freight_value < 200
        ORDER BY random() LIMIT 1000
    """)

    df_state = get_data(con, """
        SELECT dc.state, COUNT(*) as qtd 
        FROM dw.fact_sales fs JOIN dw.dim_customer dc ON fs.sk_customer = dc.sk_customer 
        GROUP BY 1 ORDER BY 2 DESC LIMIT 5
    """)

    fig = make_subplots(
        rows=2, cols=2,
        subplot_titles=("Evolução Receita", "Top Categorias", "Scatter: Frete vs Preço", "Vol. por Estado")
    )

    fig.add_trace(go.Scatter(x=df_line['mes_ano'], y=df_line['receita'], name="Receita"), row=1, col=1)
    fig.add_trace(go.Bar(x=df_bar['categoria'], y=df_bar['receita'], name="Categorias"), row=1, col=2)
    fig.add_trace(go.Scatter(x=df_scatter['price'], y=df_scatter['freight_value'], mode='markers', name="Frete"), row=2, col=1)
    fig.add_trace(go.Bar(x=df_state['state'], y=df_state['qtd'], name="Vol. Estado"), row=2, col=2)

    fig.update_layout(height=800, width=1200, title_text="Dashboard Executivo Olist", showlegend=False)
    fig.write_html(f"{OUTPUT_DIR}/dashboard_completo.html")

def main():
    db_path = setup_environment()
    print(f"--- Iniciando Geração de Gráficos ---")
    con = duckdb.connect(db_path, read_only=True)

    try:
        plot_delivery_impact(con)
        plot_freight_ratio(con)
        plot_retention_profile(con)
        plot_credit_leverage(con)

        df_line = plot_sales_evolution(con)
        df_bar = plot_top_categories(con)
        plot_heatmap_geo(con)
        plot_dashboard(con, df_line, df_bar)

    except Exception as e:
        print(f"\n[ERRO CRÍTICO] {e}")
        import traceback
        traceback.print_exc()
    finally:
        con.close()
        print(f"\n--- Concluído. Arquivos em: {os.path.abspath(OUTPUT_DIR)} ---")

if __name__ == "__main__":
    main()