-- ================================================================
-- FacGESC — Sistema de Gestão de Faculdade Particular
-- Script Completo — Entrega Final
-- Banco de Dados: MySQL 8.0+
-- Padrão: snake_case | prefixos pk_, fk_, tb_
-- Normalização: 3FN
-- Chaves compostas aplicadas onde o negócio garante unicidade
-- ================================================================

CREATE DATABASE IF NOT EXISTS facgesc
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE facgesc;

-- ================================================================
-- BASE COMPARTILHADA
-- Ordem: sem FK primeiro
-- ================================================================

-- ------------------------------------------------------------
-- Cadastro central de qualquer pessoa vinculada à faculdade
-- (aluno, professor, funcionário, responsável financeiro)
-- ------------------------------------------------------------

CREATE TABLE tb_cadastro_pessoa (
  pk_cpf            CHAR(11)      NOT NULL PRIMARY KEY,
  primeiro_nome     VARCHAR(100)  NOT NULL,
  sobrenome         VARCHAR(150)  NOT NULL,
  nome_social       VARCHAR(150),
  data_nascimento   DATE          NOT NULL,
  sexo              ENUM('masculino','feminino','nao_informado'),
  email_pessoal     VARCHAR(255)  NOT NULL UNIQUE,
  nacionalidade     VARCHAR(100)  DEFAULT 'Brasileira',
  naturalidade      VARCHAR(100),
  data_cadastro     DATETIME      NOT NULL,
  data_atualizacao  DATETIME
);

-- ------------------------------------------------------------
-- Telefones de qualquer pessoa
-- PK composta: uma pessoa não pode ter o mesmo número duas vezes
-- ------------------------------------------------------------

CREATE TABLE tb_contato_telefone (
  fk_cpf           CHAR(11)    NOT NULL,
  ddi              CHAR(3)     NOT NULL DEFAULT '055',
  ddd              CHAR(2)     NOT NULL,
  numero_telefone  VARCHAR(15) NOT NULL,
  tipo_contato     ENUM('celular','residencial','comercial','emergencia') NOT NULL,
  ativo            BOOLEAN     NOT NULL DEFAULT TRUE,
  PRIMARY KEY (fk_cpf, ddd, numero_telefone),
  FOREIGN KEY (fk_cpf) REFERENCES tb_cadastro_pessoa(pk_cpf)
);

-- ------------------------------------------------------------
-- Endereços de qualquer pessoa (pode ter mais de um)
-- Surrogate mantido: endereço não tem chave natural simples
-- ------------------------------------------------------------

CREATE TABLE tb_endereco_pessoa (
  pk_endereco    INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_cpf         CHAR(11)     NOT NULL,
  cep            VARCHAR(9)   NOT NULL,
  logradouro     VARCHAR(200) NOT NULL,
  numero_imovel  VARCHAR(15),
  complemento    VARCHAR(100),
  bairro         VARCHAR(100) NOT NULL,
  municipio      VARCHAR(100) NOT NULL,
  uf             CHAR(2)      NOT NULL,
  principal      BOOLEAN      NOT NULL DEFAULT FALSE,
  FOREIGN KEY (fk_cpf) REFERENCES tb_cadastro_pessoa(pk_cpf)
);

-- ================================================================
-- MÓDULO RH
-- Criado antes do Acadêmico porque tb_curso_graduacao
-- referencia tb_docente (coordenador do curso)
-- ================================================================

-- ------------------------------------------------------------
-- Cargos disponíveis na faculdade com faixa salarial
-- ------------------------------------------------------------

CREATE TABLE tb_cargo_funcional (
  pk_cargo           INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_cargo         VARCHAR(80)   NOT NULL UNIQUE,
  descricao_cargo    VARCHAR(255),
  nivel_hierarquico  INT,
  salario_piso       DECIMAL(10,2) NOT NULL,
  salario_teto       DECIMAL(10,2),
  situacao_cargo     ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  CHECK (salario_teto IS NULL OR salario_teto >= salario_piso)
);

-- ------------------------------------------------------------
-- Setores/departamentos da faculdade com hierarquia
-- Auto-referência: fk_setor_superior aponta para o setor pai
-- ------------------------------------------------------------

CREATE TABLE tb_setor_institucional (
  pk_setor          INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_setor        VARCHAR(100) NOT NULL UNIQUE,
  sigla_setor       CHAR(10),
  descricao         VARCHAR(255),
  fk_setor_superior INT,
  situacao_setor    ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  FOREIGN KEY (fk_setor_superior) REFERENCES tb_setor_institucional(pk_setor)
);

-- ------------------------------------------------------------
-- Qualquer pessoa que trabalha na faculdade
-- UNIQUE separados para fk_cpf e email_corporativo
-- ------------------------------------------------------------

CREATE TABLE tb_colaborador (
  pk_rf                INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_cpf               CHAR(11)     NOT NULL,
  fk_cargo             INT          NOT NULL,
  email_corporativo    VARCHAR(255) NOT NULL,
  situacao_colaborador ENUM('ativo','afastado','desligado','ferias') NOT NULL DEFAULT 'ativo',
  data_admissao        DATE         NOT NULL,
  data_desligamento    DATE,
  motivo_desligamento  VARCHAR(255),
  data_cadastro        DATETIME     NOT NULL,
  data_atualizacao     DATETIME,
  UNIQUE (fk_cpf),
  UNIQUE (email_corporativo),
  FOREIGN KEY (fk_cpf)   REFERENCES tb_cadastro_pessoa(pk_cpf),
  FOREIGN KEY (fk_cargo) REFERENCES tb_cargo_funcional(pk_cargo)
);

-- ------------------------------------------------------------
-- Especialização de colaborador que é professor
-- Relação 1:1 com tb_colaborador (fk_rf é a própria PK)
-- ------------------------------------------------------------

CREATE TABLE tb_docente (
  fk_rf                 INT          NOT NULL PRIMARY KEY,
  titulacao             VARCHAR(80)  NOT NULL,
  registro_profissional VARCHAR(50),
  vinculo               ENUM('horista','tempo_parcial','tempo_integral','substituto') NOT NULL DEFAULT 'horista',
  area_formacao         VARCHAR(150) NOT NULL,
  lattes_url            VARCHAR(300),
  ativo                 BOOLEAN      NOT NULL DEFAULT TRUE,
  FOREIGN KEY (fk_rf) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Registro de ponto diário
-- PK composta: um colaborador tem um registro por dia
-- ------------------------------------------------------------

CREATE TABLE tb_registro_ponto (
  fk_rf           INT            NOT NULL,
  data_trabalho   DATE           NOT NULL,
  entrada         TIME,
  saida           TIME,
  horas_extras    DECIMAL(5,2)   DEFAULT 0.00,
  minutos_atraso  INT            DEFAULT 0,
  observacao      VARCHAR(200),
  data_cadastro   DATETIME       NOT NULL,
  PRIMARY KEY (fk_rf, data_trabalho),
  FOREIGN KEY (fk_rf) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Folha de pagamento mensal
-- PK composta: um colaborador tem uma folha por competência
-- Correção 3FN: salario_liquido calculado na view vw_folha_com_liquido
-- ------------------------------------------------------------

CREATE TABLE tb_folha_pagamento (
  fk_rf             INT           NOT NULL,
  competencia       DATE          NOT NULL,
  salario_bruto     DECIMAL(10,2) NOT NULL,
  total_descontos   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total_beneficios  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  situacao_pagamento ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro     DATETIME      NOT NULL,
  data_atualizacao  DATETIME,
  PRIMARY KEY (fk_rf, competencia),
  FOREIGN KEY (fk_rf) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Alocação de colaboradores em setores (N:N com histórico)
-- PK composta: mesmo colaborador pode ser realocado no futuro
-- ------------------------------------------------------------

CREATE TABLE tb_alocacao_setor (
  fk_rf              INT     NOT NULL,
  fk_setor           INT     NOT NULL,
  data_inicio        DATE    NOT NULL,
  data_fim           DATE,
  alocacao_principal BOOLEAN NOT NULL DEFAULT TRUE,
  data_cadastro      DATETIME NOT NULL,
  PRIMARY KEY (fk_rf, fk_setor, data_inicio),
  FOREIGN KEY (fk_rf)    REFERENCES tb_colaborador(pk_rf),
  FOREIGN KEY (fk_setor) REFERENCES tb_setor_institucional(pk_setor)
);

-- ------------------------------------------------------------
-- Período de férias de colaboradores
-- Surrogate mantido: um colaborador pode tirar férias várias
-- vezes no mesmo ano (férias fracionadas)
-- ------------------------------------------------------------

CREATE TABLE tb_periodo_ferias (
  pk_ferias       INT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_rf           INT     NOT NULL,
  ano_referencia  INT     NOT NULL,
  data_inicio     DATE    NOT NULL,
  data_fim        DATE    NOT NULL,
  aprovado        BOOLEAN NOT NULL DEFAULT FALSE,
  data_cadastro   DATETIME NOT NULL,
  FOREIGN KEY (fk_rf) REFERENCES tb_colaborador(pk_rf),
  CHECK (data_fim > data_inicio)
);

-- ================================================================
-- MÓDULO ACADÊMICO
-- ================================================================

-- ------------------------------------------------------------
-- Cursos de graduação oferecidos pela faculdade
-- Referencia tb_docente (coordenador)
-- ------------------------------------------------------------

CREATE TABLE tb_curso_graduacao (
  pk_curso            INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_curso          VARCHAR(150) NOT NULL,
  codigo_mec          VARCHAR(20),
  area_conhecimento   VARCHAR(100) NOT NULL,
  grau_academico      VARCHAR(50)  NOT NULL,
  turno               ENUM('matutino','vespertino','noturno','ead') NOT NULL,
  duracao_semestres   INT          NOT NULL,
  carga_horaria_total INT          NOT NULL,
  fk_rf_coordenador   INT,
  situacao_curso      ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro       DATETIME     NOT NULL,
  data_atualizacao    DATETIME,
  UNIQUE (nome_curso),
  UNIQUE (codigo_mec),
  CHECK (duracao_semestres > 0),
  CHECK (carga_horaria_total > 0),
  FOREIGN KEY (fk_rf_coordenador) REFERENCES tb_docente(fk_rf)
);

-- ------------------------------------------------------------
-- Catálogo global de disciplinas (independe de curso ou semestre)
-- ------------------------------------------------------------

CREATE TABLE tb_disciplina_catalogo (
  pk_disciplina         INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  codigo_disciplina     VARCHAR(20)  NOT NULL UNIQUE,
  nome_disciplina       VARCHAR(150) NOT NULL,
  ementa                TEXT,
  carga_horaria_semanal INT          NOT NULL,
  carga_horaria_total   INT          NOT NULL,
  num_creditos          INT          NOT NULL,
  situacao_disciplina   ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro         DATETIME     NOT NULL,
  CHECK (carga_horaria_semanal > 0),
  CHECK (num_creditos > 0)
);

-- ------------------------------------------------------------
-- Grade curricular: quais disciplinas pertencem a qual curso
-- PK composta: uma disciplina aparece uma vez por curso
-- Resolve N:N entre cursos e disciplinas
-- ------------------------------------------------------------

CREATE TABLE tb_grade_curricular (
  fk_curso             INT     NOT NULL,
  fk_disciplina        INT     NOT NULL,
  semestre_recomendado INT     NOT NULL,
  obrigatoria          BOOLEAN NOT NULL DEFAULT TRUE,
  fk_pre_requisito     INT,
  PRIMARY KEY (fk_curso, fk_disciplina),
  FOREIGN KEY (fk_curso)         REFERENCES tb_curso_graduacao(pk_curso),
  FOREIGN KEY (fk_disciplina)    REFERENCES tb_disciplina_catalogo(pk_disciplina),
  FOREIGN KEY (fk_pre_requisito) REFERENCES tb_disciplina_catalogo(pk_disciplina),
  CHECK (semestre_recomendado > 0)
);

-- ------------------------------------------------------------
-- Períodos letivos (semestres)
-- PK composta: um semestre só existe uma vez por ano
-- ------------------------------------------------------------

CREATE TABLE tb_periodo_letivo (
  pk_ano_letivo         INT     NOT NULL,
  pk_semestre           INT     NOT NULL,
  data_inicio           DATE    NOT NULL,
  data_fim              DATE    NOT NULL,
  data_inicio_matricula DATE    NOT NULL,
  data_fim_matricula    DATE    NOT NULL,
  ativo                 BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (pk_ano_letivo, pk_semestre), -- Nomes corrigidos aqui
  CHECK (pk_semestre IN (1, 2)),
  CHECK (data_fim > data_inicio),
  CHECK (data_fim_matricula >= data_inicio_matricula)
);
-- ------------------------------------------------------------
-- Estudantes da faculdade (dados acadêmicos)
-- Dados pessoais ficam em tb_cadastro_pessoa via fk_cpf
-- Correção 3FN: coeficiente_rendimento removido para view
-- ------------------------------------------------------------

CREATE TABLE tb_estudante (
  pk_ra                   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_cpf                  CHAR(11)     NOT NULL,
  fk_curso                INT          NOT NULL,
  email_institucional     VARCHAR(255) NOT NULL,
  situacao                ENUM('matriculado','trancado','formado','evadido','jubilado','transferido') NOT NULL DEFAULT 'matriculado',
  semestre_atual          INT          NOT NULL DEFAULT 1,
  data_ingresso           DATE         NOT NULL,
  data_previsao_conclusao DATE,
  data_saida              DATE,
  motivo_saida            VARCHAR(255),
  flag_risco_evasao       BOOLEAN      NOT NULL DEFAULT FALSE,
  data_cadastro           DATETIME     NOT NULL,
  data_atualizacao        DATETIME,
  UNIQUE (fk_cpf),
  UNIQUE (email_institucional),
  CHECK (semestre_atual > 0),
  FOREIGN KEY (fk_cpf)   REFERENCES tb_cadastro_pessoa(pk_cpf),
  FOREIGN KEY (fk_curso) REFERENCES tb_curso_graduacao(pk_curso)
);

-- ------------------------------------------------------------
-- Histórico de mudanças de situação do estudante
-- Um aluno pode mudar de situação várias vezes
-- ------------------------------------------------------------

CREATE TABLE tb_historico_situacao_estudante (
  pk_historico      INT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_ra             INT      NOT NULL,
  situacao_anterior ENUM('matriculado','trancado','formado','evadido','jubilado','transferido'),
  situacao_nova     ENUM('matriculado','trancado','formado','evadido','jubilado','transferido') NOT NULL,
  data_alteracao    DATETIME NOT NULL,
  motivo            VARCHAR(255),
  fk_rf_responsavel INT,
  FOREIGN KEY (fk_ra)             REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_rf_responsavel) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Responsáveis financeiros dos estudantes
-- Relação 1:1 com tb_cadastro_pessoa via fk_cpf como PK
-- ------------------------------------------------------------

CREATE TABLE tb_responsavel_financeiro (
  fk_cpf               CHAR(11)      NOT NULL PRIMARY KEY,
  profissao            VARCHAR(100),
  renda_declarada      DECIMAL(10,2),
  situacao_responsavel ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  FOREIGN KEY (fk_cpf) REFERENCES tb_cadastro_pessoa(pk_cpf)
);

-- ------------------------------------------------------------
-- Vínculo entre estudante e responsável financeiro (N:N)
-- PK composta: um estudante não tem o mesmo responsável duas vezes
-- ------------------------------------------------------------

CREATE TABLE tb_estudante_responsavel (
  fk_ra                 INT      NOT NULL,
  fk_responsavel        CHAR(11) NOT NULL,
  grau_parentesco       VARCHAR(50),
  responsavel_principal BOOLEAN  NOT NULL DEFAULT FALSE,
  PRIMARY KEY (fk_ra, fk_responsavel),
  FOREIGN KEY (fk_ra)          REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_responsavel) REFERENCES tb_responsavel_financeiro(fk_cpf)
);

-- ------------------------------------------------------------
-- Oferta de disciplina: turma real em um semestre
-- Correção 3FN: vagas_ocupadas removido para view
-- ------------------------------------------------------------

CREATE TABLE tb_oferta_disciplina (
  pk_oferta        INT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_disciplina    INT     NOT NULL,
  fk_ano_letivo    INT     NOT NULL,
  fk_semestre      INT     NOT NULL,
  fk_rf_docente    INT     NOT NULL,
  codigo_turma     VARCHAR(10) NOT NULL,
  sala             VARCHAR(20),
  capacidade_vagas INT     NOT NULL DEFAULT 40,
  turno            ENUM('matutino','vespertino','noturno','ead') NOT NULL,
  ativo            BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (fk_disciplina, fk_ano_letivo, fk_semestre, codigo_turma),
  CHECK (capacidade_vagas > 0),
  FOREIGN KEY (fk_disciplina) REFERENCES tb_disciplina_catalogo(pk_disciplina),
  FOREIGN KEY (fk_ano_letivo, fk_semestre) REFERENCES tb_periodo_letivo(pk_ano_letivo, pk_semestre),
  FOREIGN KEY (fk_rf_docente) REFERENCES tb_docente(fk_rf)
);

-- ------------------------------------------------------------
-- Matrícula do estudante em uma oferta de disciplina
-- Correção 3FN: total_faltas e percentual removidos para view
-- ------------------------------------------------------------

CREATE TABLE tb_matricula_estudante (
  fk_ra                INT           NOT NULL,
  fk_oferta            INT           NOT NULL,
  data_matricula       DATE          NOT NULL,
  situacao_matricula   ENUM('cursando','aprovado','reprovado_nota','reprovado_falta','trancado','dispensado') NOT NULL DEFAULT 'cursando',
  nota_final           DECIMAL(5,2),
  data_cadastro        DATETIME      NOT NULL,
  data_atualizacao     DATETIME,
  PRIMARY KEY (fk_ra, fk_oferta),
  CHECK (nota_final IS NULL OR nota_final BETWEEN 0.00 AND 10.00),
  FOREIGN KEY (fk_ra)    REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_oferta) REFERENCES tb_oferta_disciplina(pk_oferta)
);

-- ------------------------------------------------------------
-- Avaliações planejadas por oferta (provas, trabalhos, etc.)
-- Referenciada por tb_nota_avaliacao
-- ------------------------------------------------------------

CREATE TABLE tb_avaliacao_programada (
  pk_avaliacao    INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_oferta       INT          NOT NULL,
  tipo_avaliacao  ENUM('prova','trabalho','seminario','projeto','atividade') NOT NULL,
  descricao       VARCHAR(150),
  data_aplicacao  DATE         NOT NULL,
  peso_percentual DECIMAL(5,2) NOT NULL,
  nota_maxima     DECIMAL(5,2) NOT NULL DEFAULT 10.00,
  data_cadastro   DATETIME     NOT NULL,
  CHECK (peso_percentual > 0 AND peso_percentual <= 100),
  CHECK (nota_maxima > 0),
  FOREIGN KEY (fk_oferta) REFERENCES tb_oferta_disciplina(pk_oferta)
);

-- ------------------------------------------------------------
-- Nota de cada estudante em cada avaliação
-- PK composta: um aluno tem uma nota por avaliação
-- ------------------------------------------------------------

CREATE TABLE tb_nota_avaliacao (
  fk_ra              INT          NOT NULL,
  fk_avaliacao       INT          NOT NULL,
  nota_obtida        DECIMAL(5,2) NOT NULL,
  nota_substitutiva  DECIMAL(5,2),
  data_lancamento    DATETIME     NOT NULL,
  data_atualizacao   DATETIME,
  PRIMARY KEY (fk_ra, fk_avaliacao),
  CHECK (nota_obtida >= 0),
  CHECK (nota_substitutiva IS NULL OR nota_substitutiva >= 0),
  FOREIGN KEY (fk_ra)        REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_avaliacao) REFERENCES tb_avaliacao_programada(pk_avaliacao)
);

-- ------------------------------------------------------------
-- Registro de cada aula ministrada (diário de classe digital)
-- Referenciada por tb_frequencia_aula
-- ------------------------------------------------------------

CREATE TABLE tb_aula_registrada (
  pk_aula             INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_oferta           INT          NOT NULL,
  data_aula           DATE         NOT NULL,
  conteudo_ministrado VARCHAR(300),
  carga_horaria       DECIMAL(4,2) NOT NULL DEFAULT 1.50,
  data_cadastro       DATETIME     NOT NULL,
  CHECK (carga_horaria > 0),
  FOREIGN KEY (fk_oferta) REFERENCES tb_oferta_disciplina(pk_oferta)
);

-- ------------------------------------------------------------
-- Frequência: presença ou falta de cada aluno em cada aula
-- PK composta: um aluno tem um registro de presença por aula
-- ------------------------------------------------------------

CREATE TABLE tb_frequencia_aula (
  fk_ra               INT          NOT NULL,
  fk_aula             INT          NOT NULL,
  situacao_presenca   ENUM('presente','ausente','justificado') NOT NULL DEFAULT 'ausente',
  justificativa       VARCHAR(255),
  carga_horaria_falta DECIMAL(4,2) NOT NULL DEFAULT 0.00,
  data_registro       DATETIME     NOT NULL,
  PRIMARY KEY (fk_ra, fk_aula),
  CHECK (carga_horaria_falta >= 0),
  FOREIGN KEY (fk_ra)   REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_aula) REFERENCES tb_aula_registrada(pk_aula)
);

-- ------------------------------------------------------------
-- Ocorrências disciplinares dos estudantes
-- Um aluno pode ter várias ocorrências
-- ------------------------------------------------------------

CREATE TABLE tb_ocorrencia_disciplinar (
  pk_ocorrencia   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_ra           INT          NOT NULL,
  fk_oferta       INT,
  tipo_ocorrencia ENUM('advertencia','suspensao','elogio','registro_pedagogico') NOT NULL,
  descricao       VARCHAR(300) NOT NULL,
  data_ocorrencia DATETIME     NOT NULL,
  resolvida       BOOLEAN      NOT NULL DEFAULT FALSE,
  data_resolucao  DATETIME,
  fk_rf_registrou INT,
  data_cadastro   DATETIME     NOT NULL,
  FOREIGN KEY (fk_ra)           REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_oferta)       REFERENCES tb_oferta_disciplina(pk_oferta),
  FOREIGN KEY (fk_rf_registrou) REFERENCES tb_colaborador(pk_rf)
);

-- ================================================================
-- MÓDULO FINANCEIRO
-- ================================================================

-- ------------------------------------------------------------
-- Tabela de preços: valor da mensalidade por curso e semestre
-- PK composta: um curso tem um valor por semestre letivo
-- ------------------------------------------------------------

CREATE TABLE tb_tabela_mensalidade (
  fk_curso             INT           NOT NULL,
  fk_ano_letivo        INT           NOT NULL,
  fk_semestre          INT           NOT NULL,
  valor_integral       DECIMAL(10,2) NOT NULL,
  valor_com_desconto   DECIMAL(10,2),
  descricao_reajuste   VARCHAR(150),
  data_vigencia_inicio DATE          NOT NULL,
  data_vigencia_fim    DATE,
  data_cadastro        DATETIME      NOT NULL,
  PRIMARY KEY (fk_curso, fk_ano_letivo, fk_semestre),
  CHECK (valor_integral > 0),
  CHECK (valor_com_desconto IS NULL OR valor_com_desconto <= valor_integral),
  FOREIGN KEY (fk_curso) REFERENCES tb_curso_graduacao(pk_curso),
  FOREIGN KEY (fk_ano_letivo, fk_semestre) REFERENCES tb_periodo_letivo(pk_ano_letivo, pk_semestre)
);

-- ------------------------------------------------------------
-- Bolsas e descontos concedidos a estudantes
-- Um aluno pode ter bolsas em períodos diferentes
-- ------------------------------------------------------------

CREATE TABLE tb_bolsa_desconto (
  pk_bolsa             INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_ra                INT           NOT NULL,
  tipo_bolsa           ENUM('prouni','institucional','convenio','desconto_funcionario','monitoria') NOT NULL,
  percentual_desconto  DECIMAL(5,2)  NOT NULL,
  fk_ano_letivo_inicio INT           NOT NULL,
  fk_semestre_inicio   INT           NOT NULL,
  fk_ano_letivo_fim    INT,
  fk_semestre_fim      INT,
  justificativa        VARCHAR(255),
  aprovado_por_fk_rf   INT,
  ativo                BOOLEAN       NOT NULL DEFAULT TRUE,
  data_cadastro        DATETIME      NOT NULL,
  data_atualizacao     DATETIME,
  CHECK (percentual_desconto > 0 AND percentual_desconto <= 100),
  FOREIGN KEY (fk_ra) REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_ano_letivo_inicio, fk_semestre_inicio) REFERENCES tb_periodo_letivo(pk_ano_letivo, pk_semestre),
  FOREIGN KEY (aprovado_por_fk_rf) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Contrato acadêmico-financeiro entre aluno e faculdade
-- Documento jurídico que ampara a cobrança das parcelas
-- ------------------------------------------------------------

CREATE TABLE tb_contrato_academico (
  pk_contrato          INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_ra                INT           NOT NULL,
  fk_bolsa             INT,
  numero_contrato      VARCHAR(30)   NOT NULL UNIQUE,
  valor_contratado     DECIMAL(10,2) NOT NULL,
  data_assinatura      DATE          NOT NULL,
  data_vigencia_inicio DATE          NOT NULL,
  data_vigencia_fim    DATE,
  situacao_contrato    ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro        DATETIME      NOT NULL,
  data_atualizacao     DATETIME,
  CHECK (valor_contratado > 0),
  FOREIGN KEY (fk_ra)    REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_bolsa) REFERENCES tb_bolsa_desconto(pk_bolsa)
);

-- ------------------------------------------------------------
-- Parcelas mensais geradas por contrato
-- Correção 3FN: valor_total movido para view
-- ------------------------------------------------------------

CREATE TABLE tb_parcela_mensalidade (
  fk_contrato      INT           NOT NULL,
  numero_parcela   INT           NOT NULL,
  competencia_mes  INT           NOT NULL,
  competencia_ano  INT           NOT NULL,
  valor_nominal    DECIMAL(10,2) NOT NULL,
  valor_multa      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  valor_juros      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  data_vencimento  DATE          NOT NULL,
  situacao_parcela ENUM('em_aberto','paga','vencida','renegociada','cancelada','isenta') NOT NULL DEFAULT 'em_aberto',
  data_pagamento   DATE,
  data_cadastro    DATETIME      NOT NULL,
  data_atualizacao DATETIME,
  PRIMARY KEY (fk_contrato, numero_parcela),
  CHECK (numero_parcela > 0),
  CHECK (competencia_mes BETWEEN 1 AND 12),
  CHECK (valor_nominal > 0),
  CHECK (valor_multa >= 0),
  CHECK (valor_juros >= 0),
  FOREIGN KEY (fk_contrato) REFERENCES tb_contrato_academico(pk_contrato)
);

-- ------------------------------------------------------------
-- Recebimento: registro concreto de um pagamento de parcela
-- Uma parcela pode ter múltiplos recebimentos
-- ------------------------------------------------------------

CREATE TABLE tb_recebimento (
  pk_recebimento       INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_contrato          INT           NOT NULL,
  fk_numero_parcela    INT           NOT NULL,
  valor_recebido       DECIMAL(10,2) NOT NULL,
  data_recebimento     DATETIME      NOT NULL,
  modalidade_pagamento ENUM('pix','boleto','cartao_debito','cartao_credito','transferencia','cheque') NOT NULL,
  numero_comprovante   VARCHAR(80),
  observacao           VARCHAR(255),
  fk_rf_operador       INT,
  data_cadastro        DATETIME      NOT NULL,
  CHECK (valor_recebido > 0),
  -- LINHA CORRIGIDA ABAIXO (removido o pk_ de numero_parcela):
  FOREIGN KEY (fk_contrato, fk_numero_parcela) REFERENCES tb_parcela_mensalidade(fk_contrato, numero_parcela),
  FOREIGN KEY (fk_rf_operador) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Controle de inadimplência por aluno
-- Correção 3FN: contadores de dívida movidos para view
-- ------------------------------------------------------------

CREATE TABLE tb_controle_inadimplencia (
  fk_ra                       INT           NOT NULL PRIMARY KEY,
  data_primeira_inadimplencia DATE,
  flag_bloqueio_academico     BOOLEAN       NOT NULL DEFAULT FALSE,
  data_atualizacao            DATETIME      NOT NULL,
  FOREIGN KEY (fk_ra) REFERENCES tb_estudante(pk_ra)
);

-- ------------------------------------------------------------
-- Fornecedores de serviços para a faculdade
-- ------------------------------------------------------------

CREATE TABLE tb_fornecedor_servico (
  pk_cnpj             VARCHAR(14)  NOT NULL PRIMARY KEY,
  razao_social        VARCHAR(200) NOT NULL,
  nome_fantasia       VARCHAR(150),
  tipo_fornecedor     ENUM('pessoa_fisica','pessoa_juridica') NOT NULL,
  email_comercial     VARCHAR(255),
  telefone_comercial  VARCHAR(20),
  cidade              VARCHAR(100),
  uf                  CHAR(2),
  situacao_fornecedor ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro       DATETIME     NOT NULL
);

-- ------------------------------------------------------------
-- Despesas operacionais da faculdade
-- Integração RH-Financeiro via folha de pagamento
-- ------------------------------------------------------------

CREATE TABLE tb_despesa_operacional (
  pk_despesa           INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_setor             INT           NOT NULL,
  fk_cnpj              VARCHAR(14),
  fk_rf_folha          INT,
  fk_competencia_folha DATE,
  tipo_despesa         ENUM('manutencao','material','servico','tecnologia','infraestrutura','outros') NOT NULL,
  descricao            VARCHAR(255)  NOT NULL,
  valor_previsto       DECIMAL(12,2) NOT NULL,
  valor_realizado      DECIMAL(12,2),
  data_vencimento      DATE          NOT NULL,
  data_competencia     DATE          NOT NULL,
  numero_nota_fiscal   VARCHAR(50),
  paga                 BOOLEAN       NOT NULL DEFAULT FALSE,
  data_cadastro        DATETIME      NOT NULL,
  data_atualizacao     DATETIME,
  CHECK (valor_previsto > 0),
  FOREIGN KEY (fk_setor) REFERENCES tb_setor_institucional(pk_setor),
  FOREIGN KEY (fk_cnpj)  REFERENCES tb_fornecedor_servico(pk_cnpj),
  FOREIGN KEY (fk_rf_folha, fk_competencia_folha) REFERENCES tb_folha_pagamento(fk_rf, competencia)
);

-- ------------------------------------------------------------
-- Pagamento de despesas operacionais
-- ------------------------------------------------------------

CREATE TABLE tb_pagamento_despesa (
  pk_pgto              INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_despesa           INT           NOT NULL,
  valor_pago           DECIMAL(12,2) NOT NULL,
  data_pagamento       DATE          NOT NULL,
  modalidade_pagamento ENUM('pix','boleto','cartao_debito','cartao_credito','transferencia','cheque') NOT NULL,
  numero_comprovante   VARCHAR(80),
  observacao           VARCHAR(255),
  data_cadastro        DATETIME      NOT NULL,
  CHECK (valor_pago > 0),
  FOREIGN KEY (fk_despesa) REFERENCES tb_despesa_operacional(pk_despesa)
);

-- ================================================================
-- VIEWS (Garantindo a 3ª Forma Normal - 3FN)
-- Substituem os campos calculados removidos das tabelas
-- ================================================================

CREATE VIEW vw_parcela_com_total AS
SELECT
  fk_contrato,
  numero_parcela,
  competencia_mes,
  competencia_ano,
  valor_nominal,
  valor_multa,
  valor_juros,
  (valor_nominal + valor_multa + valor_juros) AS valor_total,
  data_vencimento,
  situacao_parcela,
  data_pagamento
FROM tb_parcela_mensalidade;

CREATE VIEW vw_folha_com_liquido AS
SELECT
  fk_rf,
  competencia,
  salario_bruto,
  total_descontos,
  total_beneficios,
  (salario_bruto - total_descontos + total_beneficios) AS salario_liquido
FROM tb_folha_pagamento;

CREATE VIEW vw_frequencia_por_matricula AS
SELECT
  m.fk_ra,
  m.fk_oferta,
  COUNT(f.fk_aula) AS total_aulas,
  SUM(CASE WHEN f.situacao_presenca = 'ausente' THEN 1 ELSE 0 END) AS total_faltas,
  ROUND(
    SUM(CASE WHEN f.situacao_presenca != 'ausente' THEN 1 ELSE 0 END) * 100.0
    / NULLIF(COUNT(f.fk_aula), 0), 2
  ) AS percentual_frequencia
FROM tb_matricula_estudante m
LEFT JOIN tb_frequencia_aula f ON f.fk_ra = m.fk_ra
LEFT JOIN tb_aula_registrada a ON a.pk_aula = f.fk_aula AND a.fk_oferta = m.fk_oferta
GROUP BY m.fk_ra, m.fk_oferta;

CREATE VIEW vw_vagas_por_oferta AS
SELECT
  o.pk_oferta,
  o.capacidade_vagas,
  COUNT(m.fk_ra) AS vagas_ocupadas,
  (o.capacidade_vagas - COUNT(m.fk_ra)) AS vagas_disponiveis
FROM tb_oferta_disciplina o
LEFT JOIN tb_matricula_estudante m ON m.fk_oferta = o.pk_oferta AND m.situacao_matricula = 'cursando'
GROUP BY o.pk_oferta, o.capacidade_vagas;

CREATE VIEW vw_cr_por_estudante AS
SELECT
  m.fk_ra,
  ROUND(
    SUM(COALESCE(n.nota_substitutiva, n.nota_obtida) * d.num_creditos)
    / NULLIF(SUM(d.num_creditos), 0), 2
  ) AS coeficiente_rendimento
FROM tb_matricula_estudante m
JOIN tb_nota_avaliacao       n  ON n.fk_ra = m.fk_ra
JOIN tb_avaliacao_programada av ON av.pk_avaliacao = n.fk_avaliacao
JOIN tb_oferta_disciplina    o  ON o.pk_oferta = m.fk_oferta AND o.pk_oferta = av.fk_oferta
JOIN tb_disciplina_catalogo  d  ON d.pk_disciplina = o.fk_disciplina
WHERE m.situacao_matricula IN ('aprovado','reprovado_nota','reprovado_falta')
GROUP BY m.fk_ra;

CREATE VIEW vw_inadimplencia_resumo AS
SELECT
  ci.fk_ra,
  COUNT(p.numero_parcela) AS total_parcelas_vencidas,
  SUM(p.valor_nominal + p.valor_multa + p.valor_juros) AS valor_total_em_aberto,
  ci.data_primeira_inadimplencia,
  ci.flag_bloqueio_academico
FROM tb_controle_inadimplencia ci
JOIN tb_contrato_academico ca ON ca.fk_ra = ci.fk_ra
JOIN tb_parcela_mensalidade p ON p.fk_contrato = ca.pk_contrato
WHERE p.situacao_parcela = 'vencida'
GROUP BY ci.fk_ra, ci.data_primeira_inadimplencia, ci.flag_bloqueio_academico;

-- ================================================================
-- ÍNDICES (Acelerando buscas)
-- ================================================================

CREATE INDEX idx_colaborador_cargo    ON tb_colaborador(fk_cargo);
CREATE INDEX idx_estudante_curso      ON tb_estudante(fk_curso);
CREATE INDEX idx_estudante_situacao   ON tb_estudante(situacao);
CREATE INDEX idx_oferta_disciplina    ON tb_oferta_disciplina(fk_disciplina);
CREATE INDEX idx_oferta_docente       ON tb_oferta_disciplina(fk_rf_docente);
CREATE INDEX idx_matricula_oferta     ON tb_matricula_estudante(fk_oferta);
CREATE INDEX idx_nota_avaliacao       ON tb_nota_avaliacao(fk_avaliacao);
CREATE INDEX idx_frequencia_aula      ON tb_frequencia_aula(fk_aula);
CREATE INDEX idx_parcela_contrato     ON tb_parcela_mensalidade(fk_contrato);
CREATE INDEX idx_parcela_situacao     ON tb_parcela_mensalidade(situacao_parcela);
CREATE INDEX idx_recebimento_parcela  ON tb_recebimento(fk_contrato, fk_numero_parcela);
CREATE INDEX idx_bolsa_ra             ON tb_bolsa_desconto(fk_ra);
CREATE INDEX idx_despesa_setor        ON tb_despesa_operacional(fk_setor);

-- ================================================================
-- FASE 2 — CARGA DE DADOS (DML com Idempotência INSERT IGNORE)
-- ================================================================

SELECT 'CONTAGEM ANTES' AS momento,
  (SELECT COUNT(*) FROM tb_estudante)           AS estudantes,
  (SELECT COUNT(*) FROM tb_parcela_mensalidade) AS parcelas,
  (SELECT COUNT(*) FROM tb_nota_avaliacao)      AS notas;

INSERT IGNORE INTO tb_cadastro_pessoa VALUES
('11111111101','Ana','Souza',NULL,'2001-03-10','feminino','ana.souza@gmail.com','Brasileira','São Paulo','2025-01-15 08:00:00',NULL),
('11111111102','Bruno','Lima',NULL,'2000-07-22','masculino','bruno.lima@gmail.com','Brasileira','Campinas','2025-01-15 08:01:00',NULL),
('11111111103','Carla','Rocha',NULL,'2002-11-05','feminino','carla.rocha@gmail.com','Brasileira','Santos','2025-01-15 08:02:00',NULL),
('11111111104','Diego','Costa',NULL,'1999-04-18','masculino','diego.costa@gmail.com','Brasileira','Sorocaba','2025-01-15 08:03:00',NULL),
('11111111105','Elena','Nunes',NULL,'2003-09-30','feminino','elena.nunes@gmail.com','Brasileira','Guarulhos','2025-01-15 08:04:00',NULL),
('11111111201','Felipe','Martins',NULL,'1982-02-14','masculino','felipe.martins@gmail.com','Brasileira','São Paulo','2022-06-01 09:00:00',NULL),
('11111111202','Gabriela','Alves',NULL,'1979-08-25','feminino','gabriela.alves@gmail.com','Brasileira','São Paulo','2022-06-01 09:01:00',NULL),
('11111111203','Henrique','Dias',NULL,'1988-12-03','masculino','henrique.dias@gmail.com','Brasileira','São Paulo','2022-06-01 09:02:00',NULL),
('11111111204','Isabela','Ferreira',NULL,'1975-05-20','feminino','isabela.ferreira@gmail.com','Brasileira','São Paulo','2022-01-15 07:00:00',NULL),
('11111111205','João','Barbosa',NULL,'1980-10-11','masculino','joao.barbosa@gmail.com','Brasileira','São Paulo','2022-01-15 07:01:00',NULL);

INSERT IGNORE INTO tb_cargo_funcional (pk_cargo, nome_cargo, descricao_cargo, nivel_hierarquico, salario_piso, salario_teto, situacao_cargo) VALUES
(1,'Professor Doutor','Docente com titulação de doutorado',2,9000.00,16000.00,'ativo'),
(2,'Professor Mestre','Docente com titulação de mestrado',2,6000.00,11000.00,'ativo'),
(3,'Coordenador de Curso','Gestão acadêmica do curso',3,10000.00,18000.00,'ativo'),
(4,'Secretário Acadêmico','Atendimento e controle documental',1,2500.00,4000.00,'ativo'),
(5,'Analista Financeiro','Gestão de contas e relatórios',2,5000.00,9000.00,'ativo');

INSERT IGNORE INTO tb_setor_institucional (pk_setor, nome_setor, sigla_setor, descricao, fk_setor_superior, situacao_setor) VALUES
(1,'Reitoria','REIT','Órgão máximo da instituição',NULL,'ativo'),
(2,'Pró-Reitoria Acadêmica','PRA','Coordenação acadêmica geral',1,'ativo'),
(3,'Pró-Reitoria Financeira','PRF','Gestão financeira e orçamentária',1,'ativo'),
(4,'Departamento de TI','DATI','Infraestrutura de tecnologia',2,'ativo'),
(5,'Secretaria de Graduação','SEAC','Atendimento ao aluno',2,'ativo');

INSERT IGNORE INTO tb_colaborador (pk_rf, fk_cpf, fk_cargo, email_corporativo, situacao_colaborador, data_admissao, data_desligamento, motivo_desligamento, data_cadastro, data_atualizacao) VALUES
(1,'11111111201',1,'felipe.martins@facgesc.edu.br','ativo','2020-03-01',NULL,NULL,'2020-03-01 08:00:00',NULL),
(2,'11111111202',2,'gabriela.alves@facgesc.edu.br','ativo','2021-08-01',NULL,NULL,'2021-08-01 08:00:00',NULL),
(3,'11111111203',3,'henrique.dias@facgesc.edu.br','ativo','2019-02-15',NULL,NULL,'2019-02-15 08:00:00',NULL),
(4,'11111111204',4,'isabela.ferreira@facgesc.edu.br','ativo','2022-01-10',NULL,NULL,'2022-01-10 08:00:00',NULL),
(5,'11111111205',5,'joao.barbosa@facgesc.edu.br','ativo','2021-05-01',NULL,NULL,'2021-05-01 08:00:00',NULL);

INSERT IGNORE INTO tb_docente VALUES
(1,'Doutor',NULL,'tempo_integral','Ciência da Computação','http://lattes.cnpq.br/0001',TRUE),
(2,'Mestre',NULL,'horista','Sistemas de Informação','http://lattes.cnpq.br/0002',TRUE),
(3,'Doutor',NULL,'tempo_integral','Administração','http://lattes.cnpq.br/0003',TRUE);

INSERT IGNORE INTO tb_alocacao_setor VALUES
(1,2,'2020-03-01',NULL,TRUE,'2020-03-01 08:00:00'),
(2,2,'2021-08-01',NULL,TRUE,'2021-08-01 08:00:00'),
(3,2,'2019-02-15',NULL,TRUE,'2019-02-15 08:00:00'),
(4,5,'2022-01-10',NULL,TRUE,'2022-01-10 08:00:00'),
(5,3,'2021-05-01',NULL,TRUE,'2021-05-01 08:00:00');

INSERT IGNORE INTO tb_folha_pagamento VALUES
(1,'2026-04-01',12000.00,1800.00,500.00,'ativo','2026-04-30 18:00:00',NULL),
(2,'2026-04-01',3500.00,525.00,200.00,'ativo','2026-04-30 18:00:00',NULL),
(3,'2026-04-01',14000.00,2100.00,500.00,'ativo','2026-04-30 18:00:00',NULL),
(4,'2026-04-01',2800.00,420.00,200.00,'ativo','2026-04-30 18:00:00',NULL),
(5,'2026-04-01',6500.00,975.00,350.00,'ativo','2026-04-30 18:00:00',NULL);

INSERT IGNORE INTO tb_curso_graduacao (pk_curso, nome_curso, codigo_mec, area_conhecimento, grau_academico, turno, duracao_semestres, carga_horaria_total, fk_rf_coordenador, situacao_curso, data_cadastro, data_atualizacao) VALUES
(1,'Ciência da Computação','11001','Ciências Exatas e da Terra','Bacharelado','noturno',8,3200,1,'ativo','2020-01-01 00:00:00',NULL),
(2,'Administração','11002','Ciências Sociais Aplicadas','Bacharelado','matutino',8,3000,3,'ativo','2020-01-01 00:00:00',NULL),
(3,'Sistemas de Informação','11003','Ciências Exatas e da Terra','Bacharelado','noturno',8,3000,1,'ativo','2020-01-01 00:00:00',NULL);

INSERT IGNORE INTO tb_disciplina_catalogo (pk_disciplina, codigo_disciplina, nome_disciplina, ementa, carga_horaria_semanal, carga_horaria_total, num_creditos, situacao_disciplina, data_cadastro) VALUES
(1,'CC-001','Banco de Dados I','Modelo relacional, SQL DDL e DML, normalização até 3FN',4,68,4,'ativo','2020-01-01 00:00:00'),
(2,'CC-002','Banco de Dados II','Transações ACID, índices, procedures e triggers',4,68,4,'ativo','2020-01-01 00:00:00'),
(3,'CC-003','Algoritmos e Estruturas','Estruturas de dados lineares e não-lineares',4,68,4,'ativo','2020-01-01 00:00:00'),
(4,'ADM-001','Gestão Financeira','Análise de balanços, fluxo de caixa e orçamento',4,68,4,'ativo','2020-01-01 00:00:00'),
(5,'ADM-002','Marketing Empresarial','Estratégias de mercado e comportamento do consumidor',4,68,4,'ativo','2020-01-01 00:00:00');

INSERT IGNORE INTO tb_grade_curricular VALUES
(1,1,3,TRUE,NULL),
(1,2,4,TRUE,1),
(1,3,1,TRUE,NULL),
(2,4,2,TRUE,NULL),
(2,5,3,TRUE,NULL),
(3,1,3,TRUE,NULL),
(3,3,1,TRUE,NULL);

INSERT IGNORE INTO tb_periodo_letivo VALUES
(2026,1,'2026-02-01','2026-06-30','2026-01-20','2026-01-31',TRUE),
(2025,2,'2025-08-01','2025-12-15','2025-07-20','2025-07-31',FALSE),
(2025,1,'2025-02-01','2025-06-30','2025-01-20','2025-01-31',FALSE);

INSERT IGNORE INTO tb_estudante (pk_ra, fk_cpf, fk_curso, email_institucional, situacao, semestre_atual, data_ingresso, data_previsao_conclusao, data_saida, motivo_saida, flag_risco_evasao, data_cadastro, data_atualizacao) VALUES
(1,'11111111101',1,'ana.souza@facgesc.edu.br','matriculado',3,'2025-02-01','2029-06-30',NULL,NULL,FALSE,'2025-01-20 09:00:00',NULL),
(2,'11111111102',1,'bruno.lima@facgesc.edu.br','matriculado',3,'2025-02-01','2029-06-30',NULL,NULL,FALSE,'2025-01-20 09:01:00',NULL),
(3,'11111111103',2,'carla.rocha@facgesc.edu.br','matriculado',2,'2025-08-01','2029-06-30',NULL,NULL,FALSE,'2025-07-20 09:00:00',NULL),
(4,'11111111104',3,'diego.costa@facgesc.edu.br','trancado',2,'2025-02-01','2029-06-30',NULL,NULL,TRUE,'2025-01-20 09:03:00',NULL),
(5,'11111111105',2,'elena.nunes@facgesc.edu.br','matriculado',1,'2026-02-01','2030-06-30',NULL,NULL,FALSE,'2026-01-20 09:00:00',NULL);

INSERT IGNORE INTO tb_controle_inadimplencia VALUES
(1,NULL,FALSE,'2026-04-01 00:00:00'),
(2,NULL,FALSE,'2026-04-01 00:00:00'),
(3,NULL,FALSE,'2026-04-01 00:00:00'),
(4,'2026-02-15',TRUE,'2026-04-01 00:00:00'),
(5,NULL,FALSE,'2026-04-01 00:00:00');

INSERT IGNORE INTO tb_oferta_disciplina (pk_oferta, fk_disciplina, fk_ano_letivo, fk_semestre, fk_rf_docente, codigo_turma, sala, capacidade_vagas, turno, ativo) VALUES
(1,1,2026,1,1,'CC001-N','Lab01',40,'noturno',TRUE),
(2,2,2026,1,2,'CC002-N','Lab01',40,'noturno',TRUE),
(3,3,2026,1,1,'CC003-N','Sala05',35,'noturno',TRUE),
(4,4,2026,1,3,'ADM001-M','Sala10',45,'matutino',TRUE),
(5,5,2026,1,3,'ADM002-M','Sala11',45,'matutino',TRUE);

INSERT IGNORE INTO tb_matricula_estudante (fk_ra, fk_oferta, data_matricula, situacao_matricula, nota_final, data_cadastro, data_atualizacao) VALUES
(1,1,'2026-01-25','cursando',NULL,'2026-01-25 10:00:00',NULL),
(1,3,'2026-01-25','cursando',NULL,'2026-01-25 10:01:00',NULL),
(2,1,'2026-01-25','cursando',NULL,'2026-01-25 10:02:00',NULL),
(2,2,'2026-01-25','cursando',NULL,'2026-01-25 10:03:00',NULL),
(3,4,'2026-01-25','cursando',NULL,'2026-01-25 10:04:00',NULL),
(3,5,'2026-01-25','cursando',NULL,'2026-01-25 10:05:00',NULL),
(5,4,'2026-01-25','cursando',NULL,'2026-01-25 10:06:00',NULL),
(5,5,'2026-01-25','cursando',NULL,'2026-01-25 10:07:00',NULL);

INSERT IGNORE INTO tb_avaliacao_programada (pk_avaliacao, fk_oferta, tipo_avaliacao, descricao, data_aplicacao, peso_percentual, nota_maxima, data_cadastro) VALUES
(1,1,'prova','Prova Bimestral 1','2026-03-20',40.00,10.00,'2026-02-01 00:00:00'),
(2,1,'trabalho','Trabalho em Grupo - Modelagem','2026-04-15',30.00,10.00,'2026-02-01 00:00:00'),
(3,1,'prova','Prova Bimestral 2','2026-05-30',30.00,10.00,'2026-02-01 00:00:00'),
(4,4,'prova','Prova 1 - Gestão Financeira','2026-03-18',50.00,10.00,'2026-02-01 00:00:00'),
(5,4,'trabalho','Análise de Caso Empresarial','2026-06-10',50.00,10.00,'2026-02-01 00:00:00');

INSERT IGNORE INTO tb_nota_avaliacao VALUES
(1,1,8.50,NULL,'2026-03-22 18:00:00',NULL),
(1,2,9.00,NULL,'2026-04-17 18:00:00',NULL),
(2,1,6.00,NULL,'2026-03-22 18:00:00',NULL),
(2,2,7.50,NULL,'2026-04-17 18:00:00',NULL),
(3,4,7.00,NULL,'2026-03-20 18:00:00',NULL),
(5,4,8.00,NULL,'2026-03-20 18:00:00',NULL);

INSERT IGNORE INTO tb_aula_registrada (pk_aula, fk_oferta, data_aula, conteudo_ministrado, carga_horaria, data_cadastro) VALUES
(1,1,'2026-02-05','Introdução ao modelo relacional e história dos BDs',1.50,'2026-02-05 22:00:00'),
(2,1,'2026-02-12','Comandos DDL: CREATE TABLE, ALTER TABLE e DROP',1.50,'2026-02-12 22:00:00'),
(3,1,'2026-02-19','Comandos DML: INSERT, UPDATE, DELETE e SELECT',1.50,'2026-02-19 22:00:00'),
(4,1,'2026-02-26','JOINs: INNER, LEFT, RIGHT e FULL',1.50,'2026-02-26 22:00:00'),
(5,4,'2026-02-06','Conceitos de análise financeira e demonstrações contábeis',1.50,'2026-02-06 12:00:00'),
(6,4,'2026-02-13','Análise vertical e horizontal do balanço patrimonial',1.50,'2026-02-13 12:00:00');

INSERT IGNORE INTO tb_frequencia_aula VALUES
(1,1,'presente',NULL,0.00,'2026-02-05 22:30:00'),
(1,2,'presente',NULL,0.00,'2026-02-12 22:30:00'),
(1,3,'presente',NULL,0.00,'2026-02-19 22:30:00'),
(1,4,'ausente',NULL,1.50,'2026-02-26 22:30:00'),
(2,1,'presente',NULL,0.00,'2026-02-05 22:30:00'),
(2,2,'ausente',NULL,1.50,'2026-02-12 22:30:00'),
(2,3,'presente',NULL,0.00,'2026-02-19 22:30:00'),
(2,4,'presente',NULL,0.00,'2026-02-26 22:30:00'),
(3,5,'presente',NULL,0.00,'2026-02-06 12:30:00'),
(3,6,'presente',NULL,0.00,'2026-02-13 12:30:00'),
(5,5,'presente',NULL,0.00,'2026-02-06 12:30:00'),
(5,6,'ausente','Viagem de trabalho',1.50,'2026-02-13 12:30:00');

INSERT IGNORE INTO tb_tabela_mensalidade VALUES
(1,2026,1,1800.00,NULL,NULL,'2026-01-01',NULL,'2026-01-01 00:00:00'),
(2,2026,1,1600.00,NULL,NULL,'2026-01-01',NULL,'2026-01-01 00:00:00'),
(3,2026,1,1750.00,NULL,NULL,'2026-01-01',NULL,'2026-01-01 00:00:00');

INSERT IGNORE INTO tb_contrato_academico (pk_contrato, fk_ra, fk_bolsa, numero_contrato, valor_contratado, data_assinatura, data_vigencia_inicio, data_vigencia_fim, situacao_contrato, data_cadastro, data_atualizacao) VALUES
(1,1,NULL,'2026-CC-001',1800.00,'2026-01-25','2026-02-01','2026-06-30','ativo','2026-01-25 00:00:00',NULL),
(2,2,NULL,'2026-CC-002',1800.00,'2026-01-25','2026-02-01','2026-06-30','ativo','2026-01-25 00:00:00',NULL),
(3,3,NULL,'2026-ADM-001',1600.00,'2026-01-25','2026-02-01','2026-06-30','ativo','2026-01-25 00:00:00',NULL),
(4,4,NULL,'2026-SI-001',1750.00,'2026-01-25','2026-02-01','2026-06-30','ativo','2026-01-25 00:00:00',NULL),
(5,5,NULL,'2026-ADM-002',1600.00,'2026-01-25','2026-02-01','2026-06-30','ativo','2026-01-25 00:00:00',NULL);

INSERT IGNORE INTO tb_parcela_mensalidade VALUES
(1,1,2,2026,1800.00,0.00,0.00,'2026-02-10','paga','2026-02-08','2026-01-25 00:00:00',NULL),
(1,2,3,2026,1800.00,0.00,0.00,'2026-03-10','paga','2026-03-09','2026-01-25 00:00:00',NULL),
(1,3,4,2026,1800.00,0.00,0.00,'2026-04-10','paga','2026-04-10','2026-01-25 00:00:00',NULL),
(1,4,5,2026,1800.00,0.00,0.00,'2026-05-10','em_aberto',NULL,'2026-01-25 00:00:00',NULL),
(2,1,2,2026,1800.00,0.00,0.00,'2026-02-10','paga','2026-02-07','2026-01-25 00:00:00',NULL),
(2,2,3,2026,1800.00,0.00,0.00,'2026-03-10','paga','2026-03-10','2026-01-25 00:00:00',NULL),
(2,3,4,2026,1800.00,36.00,18.00,'2026-04-10','vencida',NULL,'2026-01-25 00:00:00',NULL),
(2,4,5,2026,1800.00,0.00,0.00,'2026-05-10','em_aberto',NULL,'2026-01-25 00:00:00',NULL),
(3,1,2,2026,1600.00,0.00,0.00,'2026-02-10','paga','2026-02-05','2026-01-25 00:00:00',NULL),
(3,2,3,2026,1600.00,0.00,0.00,'2026-03-10','paga','2026-03-08','2026-01-25 00:00:00',NULL),
(4,1,2,2026,1750.00,35.00,17.50,'2026-02-10','vencida',NULL,'2026-01-25 00:00:00',NULL),
(4,2,3,2026,1750.00,35.00,17.50,'2026-03-10','vencida',NULL,'2026-01-25 00:00:00',NULL),
(5,1,2,2026,1600.00,0.00,0.00,'2026-02-10','paga','2026-02-09','2026-01-25 00:00:00',NULL),
(5,2,3,2026,1600.00,0.00,0.00,'2026-03-10','paga','2026-03-07','2026-01-25 00:00:00',NULL);

INSERT IGNORE INTO tb_recebimento (pk_recebimento, fk_contrato, fk_numero_parcela, valor_recebido, data_recebimento, modalidade_pagamento, numero_comprovante, observacao, fk_rf_operador, data_cadastro) VALUES
(1,1,1,1800.00,'2026-02-08 14:00:00','pix','PIX-001',NULL,4,'2026-02-08 14:00:00'),
(2,1,2,1800.00,'2026-03-09 10:30:00','boleto','BOL-001',NULL,4,'2026-03-09 10:30:00'),
(3,1,3,1800.00,'2026-04-10 09:00:00','pix','PIX-002',NULL,4,'2026-04-10 09:00:00'),
(4,2,1,1800.00,'2026-02-07 16:00:00','pix','PIX-003',NULL,4,'2026-02-07 16:00:00'),
(5,2,2,1800.00,'2026-03-10 11:00:00','pix','PIX-004',NULL,4,'2026-03-10 11:00:00'),
(6,3,1,1600.00,'2026-02-05 08:30:00','transferencia','TRF-001',NULL,4,'2026-02-05 08:30:00'),
(7,3,2,1600.00,'2026-03-08 09:00:00','pix','PIX-005',NULL,4,'2026-03-08 09:00:00'),
(8,5,1,1600.00,'2026-02-09 10:00:00','boleto','BOL-002',NULL,4,'2026-02-09 10:00:00'),
(9,5,2,1600.00,'2026-03-07 15:00:00','pix','PIX-006',NULL,4,'2026-03-07 15:00:00');

INSERT IGNORE INTO tb_fornecedor_servico VALUES
('12345678000195','TelecomBR Ltda','TelecomBR','pessoa_juridica','contato@telecombr.com','11-3000-0001','São Paulo','SP','ativo','2023-01-10 00:00:00'),
('98765432000188','SoftLic Soluções','SoftLic','pessoa_juridica','vendas@softlic.com','11-4000-0002','São Paulo','SP','ativo','2023-01-10 00:00:00');

INSERT IGNORE INTO tb_despesa_operacional (pk_despesa, fk_setor, fk_cnpj, fk_rf_folha, fk_competencia_folha, tipo_despesa, descricao, valor_previsto, valor_realizado, data_vencimento, data_competencia, numero_nota_fiscal, paga, data_cadastro, data_atualizacao) VALUES
(1,4,'98765432000188',NULL,NULL,'tecnologia','Licenças Microsoft Office 365 anual',5000.00,5000.00,'2026-04-15','2026-04-01','NF-2026-001',TRUE,'2026-04-01 00:00:00',NULL),
(2,2,'12345678000195',NULL,NULL,'servico','Internet e telefonia mensal',1200.00,1200.00,'2026-04-10','2026-04-01','NF-2026-002',TRUE,'2026-04-01 00:00:00',NULL),
(3,2,NULL,1,'2026-04-01','servico','Folha de pagamento abril - Prof. Felipe Martins',12000.00,12000.00,'2026-04-30','2026-04-01',NULL,TRUE,'2026-04-30 00:00:00',NULL);

INSERT IGNORE INTO tb_pagamento_despesa (pk_pgto, fk_despesa, valor_pago, data_pagamento, modalidade_pagamento, numero_comprovante, observacao, data_cadastro) VALUES
(1,1,5000.00,'2026-04-15','transferencia','TRF-DA-001',NULL,'2026-04-15 10:00:00'),
(2,2,1200.00,'2026-04-10','pix','PIX-DA-001',NULL,'2026-04-10 09:00:00'),
(3,3,12000.00,'2026-04-30','transferencia','TRF-DA-002','Pagamento folha abril','2026-04-30 18:00:00');

SELECT 'CONTAGEM DEPOIS' AS momento,
  (SELECT COUNT(*) FROM tb_estudante)           AS estudantes,
  (SELECT COUNT(*) FROM tb_parcela_mensalidade) AS parcelas,
  (SELECT COUNT(*) FROM tb_nota_avaliacao)      AS notas;

-- ================================================================
-- FASE 3 — OLTP: SELECTs simples
-- ================================================================

SELECT
  e.pk_ra,
  CONCAT(p.primeiro_nome, ' ', p.sobrenome) AS nome,
  c.nome_curso,
  e.situacao,
  e.semestre_atual
FROM tb_estudante e
JOIN tb_cadastro_pessoa p ON p.pk_cpf = e.fk_cpf
JOIN tb_curso_graduacao c ON c.pk_curso = e.fk_curso
ORDER BY e.pk_ra;

SELECT
  p.fk_contrato,
  p.pk_numero_parcela,
  p.valor_nominal,
  p.valor_multa,
  p.valor_juros,
  (p.valor_nominal + p.valor_multa + p.valor_juros) AS valor_total,
  p.situacao_parcela
FROM tb_parcela_mensalidade p
ORDER BY p.fk_contrato, p.pk_numero_parcela;

SELECT
  d.nome_disciplina,
  o.codigo_turma,
  CONCAT(p.primeiro_nome, ' ', p.sobrenome) AS professor,
  o.capacidade_vagas,
  COUNT(m.fk_ra) AS matriculados,
  (o.capacidade_vagas - COUNT(m.fk_ra)) AS vagas_livres
FROM tb_oferta_disciplina o
JOIN tb_disciplina_catalogo d ON d.pk_disciplina = o.fk_disciplina
JOIN tb_docente doc            ON doc.fk_rf = o.fk_rf_docente
JOIN tb_colaborador col        ON col.pk_rf = doc.fk_rf
JOIN tb_cadastro_pessoa p      ON p.pk_cpf = col.fk_cpf
LEFT JOIN tb_matricula_estudante m ON m.fk_oferta = o.pk_oferta
GROUP BY o.pk_oferta, d.nome_disciplina, o.codigo_turma, p.primeiro_nome, p.sobrenome, o.capacidade_vagas;

SELECT
  CONCAT(p.primeiro_nome, ' ', p.sobrenome) AS nome,
  ca.nome_cargo,
  f.salario_bruto,
  f.total_descontos,
  f.total_beneficios,
  (f.salario_bruto - f.total_descontos + f.total_beneficios) AS salario_liquido
FROM tb_folha_pagamento f
JOIN tb_colaborador col    ON col.pk_rf = f.fk_rf
JOIN tb_cadastro_pessoa p  ON p.pk_cpf = col.fk_cpf
JOIN tb_cargo_funcional ca ON ca.pk_cargo = col.fk_cargo
WHERE f.competencia = '2026-04-01';

-- ================================================================
-- FASE 3 — OLTP: Subselects
-- ================================================================

SELECT
  CONCAT(p.primeiro_nome, ' ', p.sobrenome) AS nome,
  e.pk_ra,
  e.situacao
FROM tb_estudante e
JOIN tb_cadastro_pessoa p ON p.pk_cpf = e.fk_cpf
WHERE e.pk_ra IN (
  SELECT fk_ra
  FROM tb_controle_inadimplencia
  WHERE flag_bloqueio_academico = TRUE
);

SELECT
  CONCAT(p.primeiro_nome, ' ', p.sobrenome) AS nome,
  SUM(r.valor_recebido) AS total_pago
FROM tb_estudante e
JOIN tb_cadastro_pessoa pe ON pe.pk_cpf = e.fk_cpf -- ESTA É A LINHA QUE VOCÊ DEVE APAGAR
JOIN tb_cadastro_pessoa p ON p.pk_cpf = e.fk_cpf
JOIN tb_contrato_academico ca ON ca.fk_ra = e.pk_ra
JOIN tb_recebimento r ON r.fk_contrato = ca.pk_contrato
GROUP BY p.primeiro_nome, p.sobrenome;

SELECT
  d.nome_disciplina,
  COUNT(m.fk_ra) AS total_alunos
FROM tb_oferta_disciplina o
JOIN tb_disciplina_catalogo d    ON d.pk_disciplina = o.fk_disciplina
JOIN tb_matricula_estudante m    ON m.fk_oferta = o.pk_oferta
WHERE o.fk_ano_letivo = 2026 AND o.fk_semestre = 1
GROUP BY d.pk_disciplina, d.nome_disciplina
HAVING COUNT(m.fk_ra) > 0;

SELECT
  CONCAT(p.primeiro_nome, ' ', p.sobrenome) AS nome,
  e.pk_ra,
  (SELECT COUNT(*)
   FROM tb_parcela_mensalidade pm
   JOIN tb_contrato_academico ca ON ca.pk_contrato = pm.fk_contrato
   WHERE ca.fk_ra = e.pk_ra AND pm.situacao_parcela = 'vencida') AS parcelas_vencidas
FROM tb_estudante e
JOIN tb_cadastro_pessoa p ON p.pk_cpf = e.fk_cpf
GROUP BY e.pk_ra, p.primeiro_nome, p.sobrenome -- ADICIONA ESTA LINHA AQUI!
HAVING parcelas_vencidas >= 1
ORDER BY parcelas_vencidas DESC;

-- ================================================================
-- FASE 3 — OLTP: Transações (ACID)
-- ================================================================

START TRANSACTION;
INSERT INTO tb_recebimento
  (fk_contrato, fk_numero_parcela, valor_recebido, data_recebimento, modalidade_pagamento, data_cadastro)
VALUES
  (1, 4, 1800.00, NOW(), 'pix', NOW());

UPDATE tb_parcela_mensalidade
SET situacao_parcela = 'paga', data_pagamento = CURDATE()
WHERE fk_contrato = 1 AND pk_numero_parcela = 4;
ROLLBACK;

SELECT fk_contrato, pk_numero_parcela, situacao_parcela, data_pagamento
FROM tb_parcela_mensalidade
WHERE fk_contrato = 1 AND pk_numero_parcela = 4;

START TRANSACTION;
INSERT INTO tb_recebimento
  (fk_contrato, fk_numero_parcela, valor_recebido, data_recebimento, modalidade_pagamento, data_cadastro)
VALUES
  (1, 4, 1800.00, NOW(), 'pix', NOW());

UPDATE tb_parcela_mensalidade
SET situacao_parcela = 'paga', data_pagamento = CURDATE()
WHERE fk_contrato = 1 AND pk_numero_parcela = 4;
COMMIT;

SELECT fk_contrato, pk_numero_parcela, situacao_parcela, data_pagamento
FROM tb_parcela_mensalidade
WHERE fk_contrato = 1 AND pk_numero_parcela = 4;

START TRANSACTION;
INSERT INTO tb_recebimento
  (fk_contrato, fk_numero_parcela, valor_recebido, data_recebimento, modalidade_pagamento, data_cadastro)
VALUES
  (2, 3, 1854.00, NOW(), 'boleto', NOW());

UPDATE tb_parcela_mensalidade
SET situacao_parcela = 'paga', data_pagamento = CURDATE()
WHERE fk_contrato = 2 AND pk_numero_parcela = 3;

UPDATE tb_controle_inadimplencia
SET data_atualizacao = NOW()
WHERE fk_ra = 2;
ROLLBACK;

SELECT fk_contrato, pk_numero_parcela, situacao_parcela
FROM tb_parcela_mensalidade
WHERE fk_contrato = 2 AND pk_numero_parcela = 3;

-- ================================================================
-- FASE 5 — PERFORMANCE: EXPLAIN
-- ================================================================

EXPLAIN SELECT
  CONCAT(p.primeiro_nome, ' ', p.sobrenome) AS nome,
  c.nome_curso,
  SUM(pm.valor_nominal + pm.valor_multa + pm.valor_juros) AS divida_total
FROM tb_estudante e
JOIN tb_cadastro_pessoa p      ON p.pk_cpf = e.fk_cpf
JOIN tb_curso_graduacao c      ON c.pk_curso = e.fk_curso
JOIN tb_contrato_academico ca  ON ca.fk_ra = e.pk_ra
JOIN tb_parcela_mensalidade pm ON pm.fk_contrato = ca.pk_contrato
WHERE pm.situacao_parcela IN ('vencida', 'em_aberto')
GROUP BY e.pk_ra, p.primeiro_nome, p.sobrenome, c.nome_curso;

EXPLAIN SELECT
  d.nome_disciplina,
  COUNT(m.fk_ra) AS alunos,
  AVG(m.nota_final) AS media_notas
FROM tb_oferta_disciplina o
JOIN tb_disciplina_catalogo d   ON d.pk_disciplina = o.fk_disciplina
JOIN tb_matricula_estudante m   ON m.fk_oferta = o.pk_oferta
WHERE o.fk_ano_letivo = 2026 AND o.fk_semestre = 1
GROUP BY d.pk_disciplina, d.nome_disciplina;

-- ================================================================
-- FASE 4 — OLAP: MODELO ESTRELA
-- ================================================================

CREATE TABLE dim_tempo (
  sk_tempo      INT         NOT NULL AUTO_INCREMENT PRIMARY KEY,
  data_completa DATE        NOT NULL UNIQUE,
  dia           INT         NOT NULL,
  mes           INT         NOT NULL,
  nome_mes      VARCHAR(20) NOT NULL,
  trimestre     INT         NOT NULL,
  semestre      INT         NOT NULL,
  ano           INT         NOT NULL,
  dia_semana    VARCHAR(15) NOT NULL
);

CREATE TABLE dim_aluno (
  sk_aluno      INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  ra_oltp       INT          NOT NULL UNIQUE, -- ADICIONADO O UNIQUE AQUI
  nome_completo VARCHAR(255) NOT NULL,
  sexo          VARCHAR(20),
  situacao      VARCHAR(50)  NOT NULL,
  semestre_ingresso INT      NOT NULL,
  ano_ingresso  INT          NOT NULL,
  flag_risco    BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE TABLE dim_curso (
  sk_curso          INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_oltp           INT          NOT NULL UNIQUE, -- ADICIONADO O UNIQUE AQUI
  nome_curso        VARCHAR(150) NOT NULL,
  area_conhecimento VARCHAR(100) NOT NULL,
  grau_academico    VARCHAR(50)  NOT NULL,
  turno             VARCHAR(30)  NOT NULL
);

CREATE TABLE dim_disciplina (
  sk_disciplina   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_oltp         INT          NOT NULL UNIQUE, -- ADICIONADO O UNIQUE AQUI
  codigo          VARCHAR(20)  NOT NULL,
  nome_disciplina VARCHAR(150) NOT NULL,
  num_creditos    INT          NOT NULL
);

CREATE TABLE dim_professor (
  sk_professor  INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  rf_oltp       INT          NOT NULL UNIQUE, -- ADICIONADO O UNIQUE AQUI
  nome_completo VARCHAR(255) NOT NULL,
  titulacao     VARCHAR(80)  NOT NULL,
  area_formacao VARCHAR(150) NOT NULL,
  vinculo       VARCHAR(30)  NOT NULL
);

CREATE TABLE fato_pagamento (
  sk_tempo       INT           NOT NULL,
  sk_aluno       INT           NOT NULL,
  sk_curso       INT           NOT NULL,
  fk_contrato    INT           NOT NULL,
  numero_parcela INT           NOT NULL,
  valor_nominal  DECIMAL(10,2) NOT NULL,
  valor_multa    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  valor_juros    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  valor_recebido DECIMAL(10,2),
  situacao       VARCHAR(20)   NOT NULL,
  PRIMARY KEY (sk_tempo, sk_aluno, fk_contrato, numero_parcela),
  FOREIGN KEY (sk_tempo) REFERENCES dim_tempo(sk_tempo),
  FOREIGN KEY (sk_aluno) REFERENCES dim_aluno(sk_aluno),
  FOREIGN KEY (sk_curso) REFERENCES dim_curso(sk_curso)
);

CREATE TABLE fato_desempenho (
  sk_tempo       INT          NOT NULL,
  sk_aluno       INT          NOT NULL,
  sk_disciplina  INT          NOT NULL,
  sk_professor   INT          NOT NULL,
  pk_avaliacao   INT          NOT NULL,
  tipo_avaliacao VARCHAR(30)  NOT NULL,
  peso           DECIMAL(5,2) NOT NULL,
  nota_obtida    DECIMAL(5,2) NOT NULL,
  nota_final_usada DECIMAL(5,2) NOT NULL,
  PRIMARY KEY (sk_aluno, sk_disciplina, pk_avaliacao),
  FOREIGN KEY (sk_tempo)      REFERENCES dim_tempo(sk_tempo),
  FOREIGN KEY (sk_aluno)      REFERENCES dim_aluno(sk_aluno),
  FOREIGN KEY (sk_disciplina) REFERENCES dim_disciplina(sk_disciplina),
  FOREIGN KEY (sk_professor)  REFERENCES dim_professor(sk_professor)
);

CREATE TABLE fato_frequencia (
  sk_tempo         INT          NOT NULL,
  sk_aluno         INT          NOT NULL,
  sk_disciplina    INT          NOT NULL,
  sk_professor     INT          NOT NULL,
  pk_aula          INT          NOT NULL,
  situacao_presenca VARCHAR(20) NOT NULL,
  carga_horaria    DECIMAL(4,2) NOT NULL,
  falta            BOOLEAN      NOT NULL,
  PRIMARY KEY (sk_aluno, pk_aula),
  FOREIGN KEY (sk_tempo)      REFERENCES dim_tempo(sk_tempo),
  FOREIGN KEY (sk_aluno)      REFERENCES dim_aluno(sk_aluno),
  FOREIGN KEY (sk_disciplina) REFERENCES dim_disciplina(sk_disciplina),
  FOREIGN KEY (sk_professor)  REFERENCES dim_professor(sk_professor)
);

-- ================================================================
-- ETL — Carga das dimensões e fatos
-- ================================================================

INSERT IGNORE INTO dim_tempo (data_completa, dia, mes, nome_mes, trimestre, semestre, ano, dia_semana)
SELECT DISTINCT data_vencimento,
  DAY(data_vencimento), MONTH(data_vencimento),
  CASE MONTH(data_vencimento)
    WHEN 1  THEN 'Janeiro'   WHEN 2  THEN 'Fevereiro' WHEN 3  THEN 'Marco'
    WHEN 4  THEN 'Abril'     WHEN 5  THEN 'Maio'      WHEN 6  THEN 'Junho'
    WHEN 7  THEN 'Julho'     WHEN 8  THEN 'Agosto'    WHEN 9  THEN 'Setembro'
    WHEN 10 THEN 'Outubro'   WHEN 11 THEN 'Novembro'  WHEN 12 THEN 'Dezembro'
  END,
  QUARTER(data_vencimento),
  CASE WHEN MONTH(data_vencimento) <= 6 THEN 1 ELSE 2 END,
  YEAR(data_vencimento),
  DAYNAME(data_vencimento)
FROM tb_parcela_mensalidade;

INSERT IGNORE INTO dim_tempo (data_completa, dia, mes, nome_mes, trimestre, semestre, ano, dia_semana)
SELECT DISTINCT data_aula,
  DAY(data_aula), MONTH(data_aula),
  CASE MONTH(data_aula)
    WHEN 1  THEN 'Janeiro'   WHEN 2  THEN 'Fevereiro' WHEN 3  THEN 'Marco'
    WHEN 4  THEN 'Abril'     WHEN 5  THEN 'Maio'      WHEN 6  THEN 'Junho'
    WHEN 7  THEN 'Julho'     WHEN 8  THEN 'Agosto'    WHEN 9  THEN 'Setembro'
    WHEN 10 THEN 'Outubro'   WHEN 11 THEN 'Novembro'  WHEN 12 THEN 'Dezembro'
  END,
  QUARTER(data_aula),
  CASE WHEN MONTH(data_aula) <= 6 THEN 1 ELSE 2 END,
  YEAR(data_aula),
  DAYNAME(data_aula)
FROM tb_aula_registrada;

INSERT IGNORE INTO dim_aluno (ra_oltp, nome_completo, sexo, situacao, semestre_ingresso, ano_ingresso, flag_risco)
SELECT
  e.pk_ra,
  CONCAT(p.primeiro_nome, ' ', p.sobrenome),
  p.sexo,
  e.situacao,
  pl.pk_semestre,    -- Corrigido para pk_
  pl.pk_ano_letivo,   -- Corrigido para pk_
  e.flag_risco_evasao
FROM tb_estudante e
JOIN tb_cadastro_pessoa p ON p.pk_cpf = e.fk_cpf
JOIN tb_periodo_letivo pl ON e.data_ingresso BETWEEN pl.data_inicio AND pl.data_fim
GROUP BY e.pk_ra;

INSERT IGNORE INTO dim_curso (id_oltp, nome_curso, area_conhecimento, grau_academico, turno)
SELECT pk_curso, nome_curso, area_conhecimento, grau_academico, turno
FROM tb_curso_graduacao;

INSERT IGNORE INTO dim_disciplina (id_oltp, codigo, nome_disciplina, num_creditos)
SELECT pk_disciplina, codigo_disciplina, nome_disciplina, num_creditos
FROM tb_disciplina_catalogo;

INSERT IGNORE INTO dim_professor (rf_oltp, nome_completo, titulacao, area_formacao, vinculo)
SELECT
  col.pk_rf,
  CONCAT(p.primeiro_nome, ' ', p.sobrenome),
  d.titulacao,
  d.area_formacao,
  d.vinculo
FROM tb_docente d
JOIN tb_colaborador col   ON col.pk_rf = d.fk_rf
JOIN tb_cadastro_pessoa p ON p.pk_cpf = col.fk_cpf;

INSERT IGNORE INTO fato_pagamento
SELECT
  dt.sk_tempo,
  da.sk_aluno,
  dc.sk_curso,
  pm.fk_contrato,
  pm.pk_numero_parcela,
  pm.valor_nominal,
  pm.valor_multa,
  pm.valor_juros,
  r.valor_recebido,
  pm.situacao_parcela
FROM tb_parcela_mensalidade pm
JOIN tb_contrato_academico ca ON ca.pk_contrato = pm.fk_contrato
JOIN tb_estudante e           ON e.pk_ra = ca.fk_ra
JOIN tb_curso_graduacao c     ON c.pk_curso = e.fk_curso
JOIN dim_tempo dt             ON dt.data_completa = pm.data_vencimento
JOIN dim_aluno da             ON da.ra_oltp = e.pk_ra
JOIN dim_curso dc             ON dc.id_oltp = c.pk_curso
LEFT JOIN tb_recebimento r    ON r.fk_contrato = pm.fk_contrato
  AND r.fk_numero_parcela = pm.pk_numero_parcela
ON DUPLICATE KEY UPDATE valor_recebido = VALUES(valor_recebido);

INSERT INTO fato_desempenho
SELECT
  dt.sk_tempo,
  da.sk_aluno,
  dd.sk_disciplina,
  dp.sk_professor,
  av.pk_avaliacao,
  av.tipo_avaliacao,
  av.peso_percentual,
  n.nota_obtida,
  COALESCE(n.nota_substitutiva, n.nota_obtida)
FROM tb_nota_avaliacao n
JOIN tb_avaliacao_programada av ON av.pk_avaliacao = n.fk_avaliacao
JOIN tb_oferta_disciplina o     ON o.pk_oferta = av.fk_oferta
JOIN tb_estudante e             ON e.pk_ra = n.fk_ra
JOIN tb_disciplina_catalogo d   ON d.pk_disciplina = o.fk_disciplina
JOIN dim_tempo dt               ON dt.data_completa = av.data_aplicacao
JOIN dim_aluno da               ON da.ra_oltp = e.pk_ra
JOIN dim_disciplina dd          ON dd.id_oltp = d.pk_disciplina
JOIN dim_professor dp           ON dp.rf_oltp = o.fk_rf_docente
ON DUPLICATE KEY UPDATE nota_final_usada = VALUES(nota_final_usada);

INSERT INTO fato_frequencia
SELECT
  dt.sk_tempo,
  da.sk_aluno,
  dd.sk_disciplina,
  dp.sk_professor,
  a.pk_aula,
  f.situacao_presenca,
  a.carga_horaria,
  CASE WHEN f.situacao_presenca = 'ausente' THEN TRUE ELSE FALSE END
FROM tb_frequencia_aula f
JOIN tb_aula_registrada a    ON a.pk_aula = f.fk_aula
JOIN tb_oferta_disciplina o  ON o.pk_oferta = a.fk_oferta
JOIN tb_estudante e          ON e.pk_ra = f.fk_ra
JOIN tb_disciplina_catalogo d ON d.pk_disciplina = o.fk_disciplina
JOIN dim_tempo dt            ON dt.data_completa = a.data_aula
JOIN dim_aluno da            ON da.ra_oltp = e.pk_ra
JOIN dim_disciplina dd       ON dd.id_oltp = d.pk_disciplina
JOIN dim_professor dp        ON dp.rf_oltp = o.fk_rf_docente
ON DUPLICATE KEY UPDATE situacao_presenca = VALUES(situacao_presenca);

-- ================================================================
-- VALIDAÇÃO ETL — soma OLTP deve ser igual à soma OLAP
-- ================================================================

SELECT
  (SELECT SUM(valor_nominal) FROM tb_parcela_mensalidade) AS oltp_valor_nominal,
  (SELECT SUM(valor_nominal) FROM fato_pagamento)         AS olap_valor_nominal,
  (SELECT SUM(valor_nominal) FROM tb_parcela_mensalidade)
    = (SELECT SUM(valor_nominal) FROM fato_pagamento)     AS etl_pagamento_ok;

SELECT
  (SELECT COUNT(*) FROM tb_nota_avaliacao) AS oltp_notas,
  (SELECT COUNT(*) FROM fato_desempenho)   AS olap_notas,
  (SELECT COUNT(*) FROM tb_nota_avaliacao)
    = (SELECT COUNT(*) FROM fato_desempenho) AS etl_desempenho_ok;

SELECT
  (SELECT COUNT(*) FROM tb_frequencia_aula) AS oltp_frequencias,
  (SELECT COUNT(*) FROM fato_frequencia)    AS olap_frequencias,
  (SELECT COUNT(*) FROM tb_frequencia_aula)
    = (SELECT COUNT(*) FROM fato_frequencia) AS etl_frequencia_ok;

-- ================================================================
-- CONSULTAS ANALÍTICAS OLAP
-- ================================================================

SELECT
  dt.nome_mes,
  dt.ano,
  dc.nome_curso,
  COUNT(*) AS qtd_parcelas,
  SUM(fp.valor_nominal) AS total_previsto,
  SUM(COALESCE(fp.valor_recebido, 0)) AS total_recebido,
  SUM(fp.valor_multa + fp.valor_juros) AS total_encargos
FROM fato_pagamento fp
JOIN dim_tempo dt  ON dt.sk_tempo = fp.sk_tempo
JOIN dim_curso dc  ON dc.sk_curso = fp.sk_curso
GROUP BY dt.ano, dt.mes, dt.nome_mes, dc.nome_curso
ORDER BY dt.ano, dt.mes;

SELECT
  dd.nome_disciplina,
  fd.tipo_avaliacao,
  COUNT(*) AS qtd_avaliacoes,
  ROUND(AVG(fd.nota_final_usada), 2) AS media_notas,
  MIN(fd.nota_final_usada) AS menor_nota,
  MAX(fd.nota_final_usada) AS maior_nota
FROM fato_desempenho fd
JOIN dim_disciplina dd ON dd.sk_disciplina = fd.sk_disciplina
GROUP BY dd.nome_disciplina, fd.tipo_avaliacao
ORDER BY dd.nome_disciplina, fd.tipo_avaliacao;

SELECT
  da.nome_completo,
  dd.nome_disciplina,
  COUNT(*) AS total_aulas,
  SUM(CASE WHEN ff.falta THEN 1 ELSE 0 END) AS total_faltas,
  ROUND(
    SUM(CASE WHEN NOT ff.falta THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
  ) AS percentual_presenca
FROM fato_frequencia ff
JOIN dim_aluno da       ON da.sk_aluno = ff.sk_aluno
JOIN dim_disciplina dd  ON dd.sk_disciplina = ff.sk_disciplina
GROUP BY da.sk_aluno, da.nome_completo, dd.sk_disciplina, dd.nome_disciplina
ORDER BY da.nome_completo, dd.nome_disciplina;

SELECT
  da.nome_completo,
  da.flag_risco AS risco_evasao,
  COUNT(DISTINCT fp.numero_parcela) AS parcelas_vencidas,
  ROUND(AVG(fd.nota_final_usada), 2) AS media_notas
FROM dim_aluno da
LEFT JOIN fato_pagamento fp  ON fp.sk_aluno = da.sk_aluno AND fp.situacao = 'vencida'
LEFT JOIN fato_desempenho fd ON fd.sk_aluno = da.sk_aluno
GROUP BY da.sk_aluno, da.nome_completo, da.flag_risco
ORDER BY parcelas_vencidas DESC;

-- ================================================================
-- FASE 6 — GOVERNANÇA: Validação final
-- ================================================================

SELECT 'ESTRUTURA DO BANCO' AS info;

SELECT TABLE_NAME AS tabela, TABLE_ROWS AS linhas_estimadas
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'facgesc'
ORDER BY TABLE_NAME;

SELECT 'CONTAGEM EXATA' AS info;

SELECT 'tb_cadastro_pessoa'       AS tabela, COUNT(*) AS total FROM tb_cadastro_pessoa   UNION ALL
SELECT 'tb_colaborador',                     COUNT(*)          FROM tb_colaborador        UNION ALL
SELECT 'tb_docente',                         COUNT(*)          FROM tb_docente            UNION ALL
SELECT 'tb_curso_graduacao',                 COUNT(*)          FROM tb_curso_graduacao    UNION ALL
SELECT 'tb_estudante',                       COUNT(*)          FROM tb_estudante          UNION ALL
SELECT 'tb_oferta_disciplina',               COUNT(*)          FROM tb_oferta_disciplina  UNION ALL
SELECT 'tb_matricula_estudante',             COUNT(*)          FROM tb_matricula_estudante UNION ALL
SELECT 'tb_nota_avaliacao',                  COUNT(*)          FROM tb_nota_avaliacao     UNION ALL
SELECT 'tb_frequencia_aula',                 COUNT(*)          FROM tb_frequencia_aula    UNION ALL
SELECT 'tb_parcela_mensalidade',             COUNT(*)          FROM tb_parcela_mensalidade UNION ALL
SELECT 'tb_recebimento',                     COUNT(*)          FROM tb_recebimento        UNION ALL
SELECT 'tb_controle_inadimplencia',          COUNT(*)          FROM tb_controle_inadimplencia UNION ALL
SELECT 'dim_aluno',                          COUNT(*)          FROM dim_aluno             UNION ALL
SELECT 'dim_curso',                          COUNT(*)          FROM dim_curso             UNION ALL
SELECT 'dim_disciplina',                     COUNT(*)          FROM dim_disciplina        UNION ALL
SELECT 'dim_professor',                      COUNT(*)          FROM dim_professor         UNION ALL
SELECT 'dim_tempo',                          COUNT(*)          FROM dim_tempo             UNION ALL
SELECT 'fato_pagamento',                     COUNT(*)          FROM fato_pagamento        UNION ALL
SELECT 'fato_desempenho',                    COUNT(*)          FROM fato_desempenho       UNION ALL
SELECT 'fato_frequencia',                    COUNT(*)          FROM fato_frequencia;

-- ================================================================
-- FIM DO SCRIPT
-- ================================================================