-- 1 REVIEW DE MESTRES (PESSOAS QUE PLLATINARAM)
SELECT 
    p.Nome AS jogo,
    u.nickname AS platinador,
    r.nota,
    r.cometario,
    r.data_postagem
FROM Review r
JOIN (SELECT id_user, id_jogo, COUNT(id_conquista) AS desbloqueadas FROM Desbloqueia GROUP BY id_user, id_jogo)
uc ON r.id_user = uc.id_user AND r.id_produto = uc.id_jogo --conquistas do usuario
JOIN (SELECT id_jogo, COUNT(id_conquista) AS total FROM Conquista GROUP BY id_jogo HAVING COUNT(id_conquista) > 0)
tc ON uc.id_jogo = tc.id_jogo --conquistas totais do jogo
JOIN Produto p ON r.id_produto = p.id_produto
JOIN Usuario u ON r.id_user = u.id_user
WHERE uc.desbloqueadas = tc.total -- O usuario da review deve ter platinado
ORDER BY p.Nome, r.data_postagem DESC;

-- 2. AZARADOS QUE COMPRARAM ANTES DE PROMOCAO
SELECT 
    u.nickname,
    u.email,
    p.Nome AS jogo,
    ped.data_compra,
    ip.preco_original AS valor_pago,
    prom.data_inicio AS inicio_promocao,
    prom.percentual_desconto
FROM itens_pedidos ip
JOIN Pedidos ped ON ip.id_pedido = ped.id_pedido
JOIN Usuario u ON ped.id_user = u.id_user
JOIN Produto p ON ip.id_produto = p.id_produto
JOIN promocao prom ON p.id_produto = prom.id_produto
WHERE ped.status = true 
  -- Comprado até 7 dias antes do início da promoção
  AND ped.data_compra >= (prom.data_inicio - INTERVAL '7 days') 
  AND ped.data_compra < prom.data_inicio
  -- Garante que o usuário pagou o preço cheio na época
  AND ip.preco_momento = ip.preco_original 
ORDER BY ped.data_compra DESC;

-- 3. FECHAMENTO FINANCEIRO
SELECT 
    d.razao_social AS desenvolvedora,
    COUNT(DISTINCT p.id_produto) AS qtd_produtos_publicados,
    SUM(ip.preco_momento * ip.quantidade) AS receita_total_bruta,
    SUM(ip.quantidade) AS copias_vendidas,
    ROUND(AVG(r.nota), 2) AS qualidade_media_portfolio
FROM Desenvolvedora d
JOIN Produto p ON d.id_desenvolvedora = p.id_desenvolvedora
JOIN itens_pedidos ip ON p.id_produto = ip.id_produto
JOIN Pedidos ped ON ip.id_pedido = ped.id_pedido 
LEFT JOIN Review r ON p.id_produto = r.id_produto
WHERE ped.status = true -- Apenas pedidos finalizados/pagos
GROUP BY d.id_desenvolvedora, d.razao_social
ORDER BY receita_total_bruta DESC;

-- 4. PLATINAS
SELECT 
    u.nickname,
    p.Nome AS jogo_platinado,
    tc.total_conquistas AS total_de_conquistas_do_jogo,
    a.tempo_jogado AS tempo_gasto_para_platinar
FROM (
    SELECT id_user, id_jogo, COUNT(id_conquista) AS conquistas_desbloqueadas
    FROM Desbloqueia
    GROUP BY id_user, id_jogo
) uc
JOIN (
    SELECT id_jogo, COUNT(id_conquista) AS total_conquistas
    FROM Conquista
    GROUP BY id_jogo
    HAVING COUNT(id_conquista) > 1 --jogos com 1 conquista nao sao considerados platina
) tc ON uc.id_jogo = tc.id_jogo
JOIN Usuario u ON uc.id_user = u.id_user
JOIN Produto p ON uc.id_jogo = p.id_produto
JOIN Biblioteca b ON u.id_user = b.id_user
JOIN Armazena a ON b.id_biblioteca = a.id_biblioteca AND p.id_produto = a.id_produto
WHERE uc.conquistas_desbloqueadas = tc.total_conquistas -- O usuário tem 100%
ORDER BY tc.total_conquistas DESC, u.nickname;

-- 5. JOGOS POUCOS VENDIDOS E BEM AVALIADOS
SELECT 
    ep.Nome,
    ep.preco_base,
    ep.total_vendas,
    ROUND(ep.media_notas, 2) AS nota_media
FROM (
    -- Tabela Derivada Principal: Traz as estatísticas de vendas e notas de cada jogo
	SELECT 
		p.id_produto,
		p.Nome,
		p.preco_base,
		COUNT(ip.id_produto) AS total_vendas,
		COALESCE(AVG(r.nota), 0) AS media_notas
	FROM Produto p
	JOIN Jogo j ON p.id_produto = j.id_produto 
	LEFT JOIN itens_pedidos ip ON p.id_produto = ip.id_produto
	LEFT JOIN Review r ON p.id_produto = r.id_produto
	GROUP BY p.id_produto, p.Nome, p.preco_base
) ep
WHERE ep.media_notas >= 4.5 
  AND ep.total_vendas < (
      -- Como não temos o WITH, precisamos de uma nova subquery do zero
      -- para descobrir qual é a média de vendas globais da plataforma
      SELECT AVG(sub.vendas_por_jogo)
      FROM (
          SELECT COUNT(ip2.id_produto) AS vendas_por_jogo
          FROM Produto p2
          JOIN Jogo j2 ON p2.id_produto = j2.id_produto
          LEFT JOIN itens_pedidos ip2 ON p2.id_produto = ip2.id_produto
          GROUP BY p2.id_produto
      ) sub
  )
ORDER BY ep.media_notas DESC, ep.total_vendas ASC;

-- 6. TOP 10 MAIORES COMPRADORES DE JOGOS (BALEIAS)
SELECT 
    u.nickname,
    u.email,
    COUNT(DISTINCT ped.id_pedido) AS total_pedidos_feitos,
    SUM(ip.quantidade) AS total_itens_comprados,
    SUM(ip.preco_momento * ip.quantidade) AS total_gasto_historico
FROM Usuario u
JOIN Pedidos ped ON u.id_user = ped.id_user
JOIN itens_pedidos ip ON ped.id_pedido = ip.id_pedido
WHERE ped.status = true -- Apenas pedidos aprovados/pagos
GROUP BY u.id_user, u.nickname, u.email
ORDER BY total_gasto_historico DESC
LIMIT 10

-- 7. Custo do Jogo Base + Todas as DLCs
WITH CustoDLCs AS (
    -- Soma o preço base de todas as DLCs agrupadas pelo jogo pai
    SELECT d.id_jogo_pai, SUM(p.preco_base) AS total_preco_dlcs
    FROM Dlc d
    JOIN Produto p ON d.id_produto = p.id_produto
    GROUP BY d.id_jogo_pai
)
SELECT 
    p_base.Nome AS jogo_base,
    p_base.preco_base AS preco_jogo,
    COALESCE(cd.total_preco_dlcs, 0) AS preco_todas_dlcs,
    (p_base.preco_base + COALESCE(cd.total_preco_dlcs, 0)) AS preco_pacotao_completo
FROM Jogo j
JOIN Produto p_base ON j.id_produto = p_base.id_produto
LEFT JOIN CustoDLCs cd ON j.id_produto = cd.id_jogo_pai
ORDER BY preco_pacotao_completo DESC;

-- 8. procura jogadores que compram apenas com desconto
WITH TotalCompras AS (
    --Conta todos os jogos comprados por usuário (com filtro de histórico >= 5)
    SELECT 
        u.id_user, 
        u.nickname, 
        COUNT(ip.id_produto) AS total_jogos_comprados
    FROM Usuario u
    JOIN Pedidos ped ON u.id_user = ped.id_user
    JOIN itens_pedidos ip ON ped.id_pedido = ip.id_pedido
    WHERE ped.status = true
    GROUP BY u.id_user, u.nickname
    HAVING COUNT(ip.id_produto) >= 5
),
ComprasComDesconto AS (
    -- Conta apenas as compras que tiveram desconto
    SELECT 
        ped.id_user, 
        COUNT(ip.id_produto) AS comprados_com_desconto
    FROM Pedidos ped
    JOIN itens_pedidos ip ON ped.id_pedido = ip.id_pedido
    WHERE ped.status = true 
      AND ip.preco_momento < ip.preco_original
    GROUP BY ped.id_user
)
-- Consulta Principal: Junta as subconsultas acima
SELECT 
    tc.nickname,
    tc.total_jogos_comprados,
    COALESCE(cd.comprados_com_desconto, 0) AS comprados_com_desconto,
    ROUND((COALESCE(cd.comprados_com_desconto, 0) * 100.0) / tc.total_jogos_comprados, 2) AS taxa_desconto_pct
FROM TotalCompras tc
LEFT JOIN ComprasComDesconto cd ON tc.id_user = cd.id_user
WHERE tc.total_jogos_comprados = comprados_com_desconto
ORDER BY taxa_desconto_pct DESC;

-- 9. taxa de adesao de DLCS

SELECT 
    p_jogo.Nome AS jogo_base,
    p_dlc.Nome AS nome_dlc,
    COUNT(DISTINCT a_jogo.id_biblioteca) AS donos_do_jogo_base,
    COUNT(DISTINCT a_dlc.id_biblioteca) AS donos_da_dlc,
    ROUND((COUNT(DISTINCT a_dlc.id_biblioteca) * 100.0) / NULLIF(COUNT(DISTINCT a_jogo.id_biblioteca), 0), 2) AS attach_rate_pct
FROM Dlc d
JOIN Produto p_dlc ON d.id_produto = p_dlc.id_produto
JOIN Produto p_jogo ON d.id_jogo_pai = p_jogo.id_produto
-- Junta para encontrar quem tem o jogo base
JOIN Armazena a_jogo ON p_jogo.id_produto = a_jogo.id_produto
-- Junta para encontrar quem tem a DLC E TAMBÉM o jogo base
LEFT JOIN Armazena a_dlc ON p_dlc.id_produto = a_dlc.id_produto AND a_jogo.id_biblioteca = a_dlc.id_biblioteca
GROUP BY p_jogo.Nome, p_dlc.Nome
ORDER BY attach_rate_pct DESC;

-- 10. peso do lançamento (compras de até 7 dias depois do lançamento)

SELECT 
    p.Nome AS jogo,
    SUM(CASE WHEN ped.data_compra <= (p.data_lancamento + INTERVAL '7 days') THEN (ip.preco_momento * ip.quantidade) ELSE 0 END) AS receita_lancamento_7d,
    SUM(CASE WHEN ped.data_compra > (p.data_lancamento + INTERVAL '7 days') THEN (ip.preco_momento * ip.quantidade) ELSE 0 END) AS receita_pos_lancamento,
    SUM(ip.preco_momento * ip.quantidade) AS receita_total
FROM Produto p
JOIN Jogo j ON p.id_produto = j.id_produto
JOIN itens_pedidos ip ON p.id_produto = ip.id_produto
JOIN Pedidos ped ON ip.id_pedido = ped.id_pedido
WHERE ped.status = true
GROUP BY p.id_produto, p.Nome
ORDER BY receita_total DESC;

-- 11. Jogos Comprados, Mas Nunca Jogados
SELECT 
    u.nickname,
    p.Nome AS jogo_esquecido,
    a.data_aqs AS data_aquisicao,
    CURRENT_DATE - a.data_aqs AS dias_na_gaveta
FROM Usuario u
JOIN Biblioteca b ON u.id_user = b.id_user
JOIN Armazena a ON b.id_biblioteca = a.id_biblioteca
JOIN Produto p ON a.id_produto = p.id_produto
WHERE a.tempo_jogado = '00:00:00' 
  AND a.data_aqs <= (CURRENT_DATE - INTERVAL '6 months')
ORDER BY dias_na_gaveta DESC;

-- 12. usuarios e seus jogos
SELECT 
    u.nickname,
    u.email,
    p.Nome AS nome_do_jogo,
    a.tempo_jogado,
    a.status_progresso
FROM Usuario u
JOIN Biblioteca b ON u.id_user = b.id_user
JOIN Armazena a ON b.id_biblioteca = a.id_biblioteca
JOIN Produto p ON a.id_produto = p.id_produto
JOIN Jogo j ON p.id_produto = j.id_produto 
ORDER BY u.nickname, p.Nome;

