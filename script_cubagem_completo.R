## =============================================================================
## DESAFIO 03 - FORMA E VOLUME DA ARVORE
## Cubagem (Smalian, Huber, Newton) + Fator e Quociente de Forma
## Talhao 8 - 36 arvores cubadas
## =============================================================================
##
## ESTRATEGIAS ADOTADAS (documentadas conforme exigido no enunciado):
##
## 1) Diametro do meio da secao (necessario para Huber e Newton):
##    Os dados foram coletados no padrao Smalian (diametro apenas nas extremidades
##    de cada secao). Como nao ha medicao do diametro no meio da secao, ele e
##    ESTIMADO POR INTERPOLACAO LINEAR do diametro em funcao da altura, entre os
##    dois pontos medidos que delimitam a secao (extremidade inferior e superior).
##    Como o ponto medio da secao em altura e, por definicao, h_mid = (h0+h1)/2,
##    a interpolacao linear do diametro nesse ponto se reduz exatamente a media
##    aritmetica dos diametros extremos: d_mid = (d0+d1)/2.
##    Isso e feito por uma funcao dedicada, diametro_meio_secao(), reaproveitando
##    o mesmo principio da funcao geral de interpolacao (diametro_interpolado()).
##
## 2) Trecho entre o solo (hi = 0) e a primeira medicao (hi = 0,10 m):
##    Esse trecho foi DESPREZADO no calculo do volume. Justificativa: nenhuma
##    arvore possui medicao em hi = 0 (nao ha diametro de base/toco na planilha);
##    qualquer estimativa desse diametro exigiria extrapolacao sem apoio empirico
##    (o que violaria a regra de nao inventar dados). Alem disso, o comprimento
##    do trecho e de apenas 0,10 m, o que representa uma fracao desprezivel do
##    volume total do fuste (tipicamente << 0,5%). Assim, o volume de cada arvore
##    e a soma das secoes entre o primeiro ponto medido (hi = 0,10 m) e o topo
##    (hi = HT, onde di = 0).
##
## 3) Diametro na altura de Girard (5,2 m):
##    Nenhuma arvore possui medicao exatamente em 5,2 m. O diametro nessa altura
##    e obtido por INTERPOLACAO LINEAR entre os dois pontos medidos imediatamente
##    abaixo e acima de 5,2 m, usando a mesma funcao diametro_interpolado() usada
##    para estimar o diametro do meio da secao.
##
## =============================================================================

# ---- Pacotes ----------------------------------------------------------------
if (!requireNamespace("readxl", quietly = TRUE)) install.packages("readxl")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("writexl", quietly = TRUE)) install.packages("writexl")

library(readxl)
library(dplyr)
library(writexl)

# ---- 1. Leitura dos dados -----------------------------------------------------
caminho_arquivo <- "cubagem.xlsx"   # ajustar caminho se necessario

dados <- read_excel(caminho_arquivo)
names(dados) <- c("Talhao", "Arv", "hi", "di", "DAP", "HT")  # padroniza nomes (remove acento)

# Exploracao basica --------------------------------------------------------
cat("Numero de linhas (secoes):", nrow(dados), "\n")
cat("Numero de arvores:", length(unique(dados$Arv)), "\n")
cat("Talhoes presentes:", paste(unique(dados$Talhao), collapse = ", "), "\n")
cat("Faixa de DAP (cm):", min(dados$DAP), "-", max(dados$DAP), "\n")
cat("Faixa de altura total (m):", min(dados$HT), "-", max(dados$HT), "\n")
cat("Valores ausentes por coluna:\n")
print(colSums(is.na(dados)))

secoes_por_arvore <- dados %>% count(Arv)
cat("Numero de secoes por arvore - resumo:\n")
print(summary(secoes_por_arvore$n))

# Garantir ordenacao por altura dentro de cada arvore
dados <- dados %>% arrange(Arv, hi)

# ---- 2. Funcao auxiliar: area seccional (m2) a partir do diametro (cm) -------
area_seccional <- function(d_cm) {
  (pi / 4) * (d_cm / 100)^2
}

# ---- 3. Funcao de interpolacao de diametro em uma altura absoluta -----------
# Reaproveitada tanto para estimar o diametro do meio da secao (Huber/Newton)
# quanto para o diametro na altura de Girard (5,2 m).
diametro_interpolado <- function(hi, di, altura_alvo) {
  # Se a altura-alvo coincide (dentro de tolerancia numerica) com um ponto medido,
  # retorna o diametro medido diretamente.
  idx_exato <- which(abs(hi - altura_alvo) < 1e-9)
  if (length(idx_exato) > 0) {
    return(di[idx_exato[1]])
  }

  # Fora do intervalo medido -> nao ha suporte para extrapolar (retorna NA)
  if (altura_alvo < min(hi) || altura_alvo > max(hi)) {
    warning(sprintf("Altura-alvo %.2f fora do intervalo medido [%.2f, %.2f]. Retornando NA.",
                     altura_alvo, min(hi), max(hi)))
    return(NA_real_)
  }

  # Localiza os dois pontos medidos que envolvem a altura-alvo
  idx_sup <- which(hi > altura_alvo)[1]
  idx_inf <- idx_sup - 1

  h0 <- hi[idx_inf]; h1 <- hi[idx_sup]
  d0 <- di[idx_inf]; d1 <- di[idx_sup]

  # Interpolacao linear
  d0 + (d1 - d0) * (altura_alvo - h0) / (h1 - h0)
}

# ---- 4. Funcao para estimar o diametro do meio de cada secao ----------------
# Estrategia: interpolacao linear no ponto medio de altura da secao. Como o
# ponto medio de altura e exatamente (h0+h1)/2, isso equivale a media aritmetica
# dos diametros extremos da secao. Implementado de forma explicita e documentada,
# reaproveitando a logica da interpolacao linear.
diametro_meio_secao <- function(h0, h1, d0, d1) {
  h_mid <- (h0 + h1) / 2
  # interpolacao linear generica (equivale a (d0+d1)/2 pois h_mid e o ponto medio)
  d0 + (d1 - d0) * (h_mid - h0) / (h1 - h0)
}

# ---- 5. Funcoes de cubagem (uma por metodo) ----------------------------------
# Cada funcao recebe os vetores hi (alturas) e di (diametros, cm) de UMA arvore,
# ja ordenados do primeiro ponto medido (0,10 m) ate o topo (di = 0), e retorna
# o volume total do fuste (m3), somando secao a secao.

vol_smalian <- function(hi, di) {
  n <- length(hi)
  vol_total <- 0
  for (i in 1:(n - 1)) {
    L  <- hi[i + 1] - hi[i]
    A0 <- area_seccional(di[i])
    A1 <- area_seccional(di[i + 1])
    vol_total <- vol_total + ((A0 + A1) / 2) * L
  }
  vol_total
}

vol_huber <- function(hi, di) {
  n <- length(hi)
  vol_total <- 0
  for (i in 1:(n - 1)) {
    L  <- hi[i + 1] - hi[i]
    dm <- diametro_meio_secao(hi[i], hi[i + 1], di[i], di[i + 1])
    Am <- area_seccional(dm)
    vol_total <- vol_total + Am * L
  }
  vol_total
}

vol_newton <- function(hi, di) {
  n <- length(hi)
  vol_total <- 0
  for (i in 1:(n - 1)) {
    L  <- hi[i + 1] - hi[i]
    dm <- diametro_meio_secao(hi[i], hi[i + 1], di[i], di[i + 1])
    A0 <- area_seccional(di[i])
    A1 <- area_seccional(di[i + 1])
    Am <- area_seccional(dm)
    vol_total <- vol_total + ((A0 + 4 * Am + A1) / 6) * L
  }
  vol_total
}

# ---- 6. Altura de Girard ------------------------------------------------------
ALTURA_GIRARD <- 5.2  # metros

# ---- 7. Rotina principal: percorre cada arvore -------------------------------
arvores <- unique(dados$Arv)

resultados <- lapply(arvores, function(a) {
  arv_dados <- dados %>% filter(Arv == a) %>% arrange(hi)
  hi <- arv_dados$hi
  di <- arv_dados$di
  dap <- unique(arv_dados$DAP)
  ht  <- unique(arv_dados$HT)

  # Volumes pelos tres metodos
  v_smalian <- vol_smalian(hi, di)
  v_huber   <- vol_huber(hi, di)
  v_newton  <- vol_newton(hi, di)

  # Fator de forma: volume real (Smalian) / volume do cilindro de referencia (g_DAP x HT)
  g_dap     <- area_seccional(dap)
  v_cilindro <- g_dap * ht
  fator_forma <- v_smalian / v_cilindro

  # Quociente de forma de Girard: diametro interpolado a 5,2 m / DAP
  d_girard <- diametro_interpolado(hi, di, ALTURA_GIRARD)
  quociente_forma <- d_girard / dap

  data.frame(
    arvore = a,
    dap_cm = dap,
    altura_m = ht,
    volume_smalian_m3 = v_smalian,
    volume_huber_m3 = v_huber,
    volume_newton_m3 = v_newton,
    fator_forma = fator_forma,
    quociente_forma = quociente_forma
  )
})

resultados <- bind_rows(resultados) %>% arrange(arvore)

# ---- 8. Conferencia rapida -----------------------------------------------------
cat("\nResumo dos resultados:\n")
print(summary(resultados[, c("volume_smalian_m3", "volume_huber_m3", "volume_newton_m3",
                              "fator_forma", "quociente_forma")]))

# ---- 9. Exportacao do arquivo consolidado --------------------------------------
write.csv(resultados, "resultado_cubagem_forma.csv", row.names = FALSE)
write_xlsx(resultados, "resultado_cubagem_forma.xlsx")

cat("\nArquivo consolidado exportado: resultado_cubagem_forma.csv / .xlsx\n")

# ---- 10. Analises complementares (Parte A e B) ---------------------------------

# A) Comparacao entre metodos
resultados <- resultados %>%
  mutate(
    dif_smalian_huber_pct  = (volume_smalian_m3 - volume_huber_m3)  / volume_huber_m3  * 100,
    dif_smalian_newton_pct = (volume_smalian_m3 - volume_newton_m3) / volume_newton_m3 * 100,
    dif_newton_huber_pct   = (volume_newton_m3  - volume_huber_m3)  / volume_huber_m3  * 100
  )

cat("\nDiferencas percentuais entre metodos (resumo):\n")
print(summary(resultados[, c("dif_smalian_huber_pct", "dif_smalian_newton_pct", "dif_newton_huber_pct")]))

# B) Relacao fator/quociente de forma com DAP e altura
cat("\nCorrelacao fator_forma x DAP:", cor(resultados$fator_forma, resultados$dap_cm), "\n")
cat("Correlacao fator_forma x altura:", cor(resultados$fator_forma, resultados$altura_m), "\n")
cat("Correlacao quociente_forma x DAP:", cor(resultados$quociente_forma, resultados$dap_cm), "\n")
cat("Correlacao quociente_forma x altura:", cor(resultados$quociente_forma, resultados$altura_m), "\n")

# C) Simulacao: efeito de usar um fator de forma medio unico no povoamento
f_medio <- mean(resultados$fator_forma)
resultados <- resultados %>%
  mutate(
    vol_estimado_f_medio = f_medio * area_seccional(dap_cm) * altura_m,
    erro_pct = (vol_estimado_f_medio - volume_smalian_m3) / volume_smalian_m3 * 100
  )

cat("\nFator de forma medio do povoamento:", f_medio, "\n")
cat("Erro percentual por arvore ao aplicar fator medio - resumo:\n")
print(summary(resultados$erro_pct))

erro_total_pct <- (sum(resultados$vol_estimado_f_medio) - sum(resultados$volume_smalian_m3)) /
                    sum(resultados$volume_smalian_m3) * 100
cat("Erro no volume TOTAL do povoamento (soma das 36 arvores):", round(erro_total_pct, 3), "%\n")

# ---- Graficos (Parte A e B) -----------------------------------------------------
# Comparacao dos 3 metodos
png("comparacao_metodos.png", width = 900, height = 600)
plot(resultados$volume_smalian_m3, resultados$volume_huber_m3,
     xlab = "Volume Smalian (m3)", ylab = "Volume Huber / Newton (m3)",
     main = "Comparacao entre metodos de cubagem", pch = 16, col = "blue")
points(resultados$volume_smalian_m3, resultados$volume_newton_m3, pch = 17, col = "darkgreen")
abline(0, 1, lty = 2, col = "red")
legend("topleft", legend = c("Huber", "Newton", "linha 1:1"),
       col = c("blue", "darkgreen", "red"), pch = c(16, 17, NA), lty = c(NA, NA, 2))
dev.off()

# Fator de forma x DAP e altura
png("fator_forma_vs_dap_altura.png", width = 1000, height = 500)
par(mfrow = c(1, 2))
plot(resultados$dap_cm, resultados$fator_forma, xlab = "DAP (cm)", ylab = "Fator de forma",
     main = "Fator de forma x DAP", pch = 16)
abline(lm(fator_forma ~ dap_cm, data = resultados), col = "red")
plot(resultados$altura_m, resultados$fator_forma, xlab = "Altura total (m)", ylab = "Fator de forma",
     main = "Fator de forma x Altura", pch = 16)
abline(lm(fator_forma ~ altura_m, data = resultados), col = "red")
dev.off()

# Quociente de forma x DAP e altura
png("quociente_forma_vs_dap_altura.png", width = 1000, height = 500)
par(mfrow = c(1, 2))
plot(resultados$dap_cm, resultados$quociente_forma, xlab = "DAP (cm)", ylab = "Quociente de forma (Girard)",
     main = "Quociente de forma x DAP", pch = 16)
abline(lm(quociente_forma ~ dap_cm, data = resultados), col = "red")
plot(resultados$altura_m, resultados$quociente_forma, xlab = "Altura total (m)", ylab = "Quociente de forma (Girard)",
     main = "Quociente de forma x Altura", pch = 16)
abline(lm(quociente_forma ~ altura_m, data = resultados), col = "red")
dev.off()

cat("\nScript concluido com sucesso.\n")
