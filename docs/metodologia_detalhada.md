> Documento original de metodologia, mantido para referência. A organização atual das pastas está descrita no [README](../README.md): entradas em `dados/`, scripts em `scripts/`, saídas em `resultados/`.

# Desafio 03 — Forma e Volume da Árvore

Cubagem rigorosa (Smalian, Huber e Newton), fator de forma e quociente de forma de Girard, aplicados às 36 árvores cubadas do talhão 8.

## Conteúdo do repositório

| Arquivo | Descrição |
|---|---|
| `desafio03_cubagem_forma.R` | Script R comentado, com as funções de cubagem (Smalian, Huber, Newton), a função de interpolação de diâmetro e os cálculos de fator e quociente de forma. |
| `cubagem.xlsx` | Base de dados de entrada, com a cubagem rigorosa das 36 árvores. |
| `resultado_cubagem_forma.csv` / `.xlsx` | Arquivo de saída consolidado, uma linha por árvore. |
| `Relatorio_curto.docx` | Relatório com a comparação entre métodos, a análise de forma e a discussão sobre o efeito da forma na estimativa de volume. |

## Estratégias adotadas

### 1. Diâmetro do meio da seção (métodos de Huber e Newton)

Os dados foram coletados no padrão Smalian: apenas os diâmetros nas extremidades de cada seção do fuste foram medidos em campo. Como o diâmetro no ponto médio da seção, exigido pelos métodos de Huber e de Newton, não está disponível na base, ele foi **estimado por interpolação linear do diâmetro em função da altura**, entre os dois pontos medidos que delimitam a seção.

Como o ponto médio de uma seção em altura é, por definição, `h_mid = (h0 + h1) / 2`, essa interpolação se reduz algebricamente à média aritmética simples dos diâmetros extremos:

```
d_mid = (d0 + d1) / 2
```

Essa estratégia foi escolhida por não introduzir nenhuma hipótese de forma geométrica adicional (cônica, paraboloide, neiloide) além da linearidade já implícita entre dois pontos consecutivos efetivamente medidos em campo, e por permitir o reaproveitamento da mesma lógica de interpolação em outras partes do desafio, atendendo à especificação técnica do script.

Implementação:

```r
diametro_meio_secao <- function(h0, h1, d0, d1) {
  h_mid <- (h0 + h1) / 2
  d0 + (d1 - d0) * (h_mid - h0) / (h1 - h0)
}
```

### 2. Trecho entre o solo (0 m) e a primeira medição (0,10 m)

Esse trecho foi desconsiderado no cálculo do volume total de cada árvore (o volume é a soma das seções de 0,10 m até o topo, `hi = HT`). Nenhuma árvore possui diâmetro medido em `hi = 0`, e estimar esse valor exigiria extrapolação sem respaldo nos dados. Além disso, o comprimento do trecho é irrisório frente à altura total das árvores, representando um viés desprezível no volume total (inferior a 0,5%, em ordem de grandeza).

### 3. Diâmetro na altura de Girard (5,2 m)

Nenhuma árvore possui medição exatamente em 5,2 m. O diâmetro nessa altura foi obtido por **interpolação linear** entre os dois pontos medidos imediatamente abaixo e acima de 5,2 m, usando a mesma função de interpolação empregada na estimativa do diâmetro do meio da seção:

```r
diametro_interpolado <- function(hi, di, altura_alvo) {
  idx_exato <- which(abs(hi - altura_alvo) < 1e-9)
  if (length(idx_exato) > 0) return(di[idx_exato[1]])
  idx_sup <- which(hi > altura_alvo)[1]
  idx_inf <- idx_sup - 1
  h0 <- hi[idx_inf]; h1 <- hi[idx_sup]
  d0 <- di[idx_inf]; d1 <- di[idx_sup]
  d0 + (d1 - d0) * (altura_alvo - h0) / (h1 - h0)
}
```

Verificou-se, antes do cálculo, que a altura de 5,2 m está contida no intervalo medido em todas as 36 árvores (a menor altura total do talhão é 13,6 m), de modo que não houve necessidade de extrapolação em nenhum caso.

## Como executar

```r
# dentro da pasta do repositório
source("desafio03_cubagem_forma.R")
```

O script lê `cubagem.xlsx`, processa as 36 árvores automaticamente (sem números de árvore fixos no código) e gera `resultado_cubagem_forma.csv` e `resultado_cubagem_forma.xlsx` na mesma pasta.

## Colunas do arquivo de saída

| Coluna | Descrição |
|---|---|
| `arvore` | Identificação da árvore (Arv) |
| `dap_cm` | Diâmetro à altura do peito (cm) |
| `altura_m` | Altura total da árvore (m) |
| `volume_smalian_m3` | Volume total pelo método de Smalian (m³) |
| `volume_huber_m3` | Volume total pelo método de Huber (m³) |
| `volume_newton_m3` | Volume total pelo método de Newton (m³) |
| `fator_forma` | Volume real (Smalian) / volume do cilindro de referência (g_DAP × HT) |
| `quociente_forma` | Diâmetro a 5,2 m / DAP |
