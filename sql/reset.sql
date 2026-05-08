-- Primeiro, avisamos o banco para não reclamar das ligações entre as tabelas
SET FOREIGN_KEY_CHECKS = 0;

-- Agora, mandamos apagar todas as Views (as janelas de visualização)
DROP VIEW IF EXISTS vw_parcela_com_total;
DROP VIEW IF EXISTS vw_folha_com_liquido;
DROP VIEW IF EXISTS vw_frequencia_por_matricula;
DROP VIEW IF EXISTS vw_vagas_por_oferta;
DROP VIEW IF EXISTS vw_cr_por_estudante;
DROP VIEW IF EXISTS vw_inadimplencia_resumo;

-- E agora, mandamos apagar todas as tabelas (as caixas de dados)
-- O "IF EXISTS" serve para não dar erro se a tabela já não existir
DROP TABLE IF EXISTS fato_frequencia;
DROP TABLE IF EXISTS fato_desempenho;
DROP TABLE IF EXISTS fato_pagamento;
DROP TABLE IF EXISTS dim_professor;
DROP TABLE IF EXISTS dim_disciplina;
DROP TABLE IF EXISTS dim_aluno;
DROP TABLE IF EXISTS dim_curso;
DROP TABLE IF EXISTS dim_tempo;
DROP TABLE IF EXISTS tb_pagamento_despesa;
DROP TABLE IF EXISTS tb_despesa_operacional;
DROP TABLE IF EXISTS tb_fornecedor_servico;
DROP TABLE IF EXISTS tb_controle_inadimplencia;
DROP TABLE IF EXISTS tb_recebimento;
DROP TABLE IF EXISTS tb_parcela_mensalidade;
DROP TABLE IF EXISTS tb_contrato_academico;
DROP TABLE IF EXISTS tb_bolsa_desconto;
DROP TABLE IF EXISTS tb_tabela_mensalidade;
DROP TABLE IF EXISTS tb_folha_pagamento;
DROP TABLE IF EXISTS tb_periodo_ferias;
DROP TABLE IF EXISTS tb_registro_ponto;
DROP TABLE IF EXISTS tb_alocacao_setor;
DROP TABLE IF EXISTS tb_docente;
DROP TABLE IF EXISTS tb_colaborador;
DROP TABLE IF EXISTS tb_setor_institucional;
DROP TABLE IF EXISTS tb_cargo_funcional;
DROP TABLE IF EXISTS tb_ocorrencia_disciplinar;
DROP TABLE IF EXISTS tb_frequencia_aula;
DROP TABLE IF EXISTS tb_aula_registrada;
DROP TABLE IF EXISTS tb_nota_avaliacao;
DROP TABLE IF EXISTS tb_avaliacao_programada;
DROP TABLE IF EXISTS tb_matricula_estudante;
DROP TABLE IF EXISTS tb_oferta_disciplina;
DROP TABLE IF EXISTS tb_estudante_responsavel;
DROP TABLE IF EXISTS tb_responsavel_financeiro;
DROP TABLE IF EXISTS tb_historico_situacao_estudante;
DROP TABLE IF EXISTS tb_estudante;
DROP TABLE IF EXISTS tb_periodo_letivo;
DROP TABLE IF EXISTS tb_grade_curricular;
DROP TABLE IF EXISTS tb_disciplina_catalogo;
DROP TABLE IF EXISTS tb_curso_graduacao;
DROP TABLE IF EXISTS tb_endereco_pessoa;
DROP TABLE IF EXISTS tb_contato_telefone;
DROP TABLE IF EXISTS tb_cadastro_pessoa;

-- Por fim, ligamos a proteção de novo
SET FOREIGN_KEY_CHECKS = 1;