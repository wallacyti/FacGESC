# FacGESC — Sistema de Gestão de Faculdade Particular

> Projeto acadêmico desenvolvido para a disciplina de **Banco de Dados**  
> UNICID — Universidade Cidade de São Paulo | Análise e Desenvolvimento de Sistemas| 2026  
> Prof. Clóvis

---

## Sobre o projeto

O **FacGESC** é um ERP (Enterprise Resource Planning) educacional modelado para
uma faculdade particular de ensino superior. O objetivo é construir uma base de
dados integrada que permita à instituição gerenciar alunos, professores,
finanças e recursos humanos em um único sistema coerente.

O banco de dados foi projetado para alimentar, na Fase 2, algoritmos de
Inteligência Artificial capazes de prever risco de evasão, automatizar
processos acadêmicos e gerar indicadores estratégicos para a gestão.

<img width="6322" height="4461" alt="facgesc_diagrama_er" src="https://github.com/user-attachments/assets/58e63024-670d-4c25-964e-d9f0f90f18f8" />

https://dbdiagram.io/d/facgesc_diagrama_er-69d7fdbf0f7c9ef2c0be67c6

---
## Módulos do sistema

| Módulo | Responsabilidade | Tabelas |
|---|---|---|
| **Base Compartilhada** | Cadastro central de pessoas | 3 tabelas |
| **Acadêmico** | Cursos, disciplinas, matrículas, notas, frequência | 12 tabelas |
| **RH** | Colaboradores, docentes, folha de pagamento, ponto | 7 tabelas |
| **Financeiro** | Mensalidades, contratos, bolsas, inadimplência | 10 tabelas |

---

## Tecnologias utilizadas

- **MySQL 8.0** — banco de dados relacional
- **dbdiagram.io** — modelagem do DER (DBML)
- **Git / GitHub** — controle de versão

---

## Organização do Repositório
/docs: Documento de Requisitos e Dicionário de Dados completo.

/diagrams: Imagem do Diagrama Entidade-Relacionamento (DER) em alta resolução.

/scripts: Script SQL DDL para criação da estrutura do banco de dados.



---

## Links importantes

- **DER (dbdiagram.io):** https://dbdiagram.io/d/Copy-of-SisGESC-ERP-Escola-69d7fdbf0f7c9ef2c0be67c6
- **Documentação official:** /docs/FacGESC_Documentacao.pdf
- **Documento de Requisitos:** /docs/requisitos.pdf
- **Dicionário de Dados:** /docs/dicionario.pdf
- **Script SQL:** /sql/facgesc_ddl.sql

---

## Modelo de dados — visão geral

O modelo está na **3ª Forma Normal (3FN)**, sem redundâncias ou dependências
transitivas. Foram aplicadas **chaves compostas** onde o negócio garante
unicidade natural, evitando surrogates desnecessários.

**Integrações entre módulos:**

- `Acadêmico ↔ RH` — `tb_oferta_disciplina` vincula docente (RH) à turma
(Acadêmico). O coordenador de curso é um docente cadastrado no RH.
- `Acadêmico ↔ Financeiro` — `tb_controle_inadimplencia` ativa o campo
`flag_bloqueio_academico` quando o aluno acumula 2+ parcelas vencidas,
bloqueando matrícula e histórico escolar.
- `RH ↔ Financeiro` — `tb_despesa_operacional` referencia `tb_folha_pagamento`,
tornando toda despesa de pessoal rastreável no financeiro.

---

## Regras de negócio principais

| Código | Módulos | Resumo |
|---|---|---|
| RN-01 | Acadêmico | Frequência < 75% → reprovado por falta |
| RN-02 | Acadêmico | Nota final < 5,0 → reprovado por nota |
| RN-03 | Acadêmico | Soma dos pesos das avaliações deve ser exatamente 100% |
| RN-04 | Financeiro | Parcela vencida gera multa 2% + juros 1% ao mês |
| RN-05 | RH | Apenas docente em tempo integral/parcial pode coordenar curso |
| RN-06 | Financeiro + Acadêmico | 2+ parcelas vencidas → bloqueio acadêmico |
| RN-07 | Acadêmico + RH | Docente leciona apenas na sua área de formação |
| RN-08 | Acadêmico + Financeiro | Inadimplência + baixa frequência → flag de risco de evasão (BI/IA) |

---

## Como executar o script SQL

**Requisitos:** MySQL Workbench instalado com MySQL Server rodando.

1. Abra o **MySQL Workbench**
2. Conecte no servidor local (geralmente `localhost`, porta `3306`)
3. Vá em **File → Open SQL Script** e selecione o arquivo `sql/facgesc_ddl.sql`
4. Clique no **raio (⚡)** para executar o script completo
5. No painel **Schemas** à esquerda, clique em atualizar — o banco `facgesc` deve aparecer com todas as 32 tabelas

> Certifique-se de que o MySQL Server está iniciado antes de conectar.
> Em caso de erro de FK, execute o script completo de uma vez (não linha por linha).


