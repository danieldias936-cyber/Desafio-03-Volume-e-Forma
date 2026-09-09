# ============================================================================
# 05_diferencas_por_classe_dap.R
# Parte A (item 6) — Desafio 03: Cubagem por Smalian, Huber e Newton
#
# Agrupa as 36 árvores cubadas em classes de DAP e analisa como a diferença
# percentual entre os métodos de cubagem (Smalian, Huber e Newton) varia
# entre classes de diâmetro — extensão da comparação árvore a árvore feita
# no item 5 do relatório original.
#
# Reaproveita, sem alteração, as funções de cubagem definidas no script da
# Parte A (area_seccional, diametro_meio_secao, vol_smalian, vol_huber,
# vol_newton). Se este arquivo for colocado na mesma pasta scripts/ do
# restante do Desafio 03, ajuste o `source()` abaixo para o nome real do
# arquivo onde essas funções estão definidas, em vez de redeclará-las aqui.
# ============================================================================

options(stringsAsFactors = FALSE)

# ---- Funções de cubagem (idênticas às da Parte A) --------------------------
area_seccional <- function(d_cm) (pi / 4) * (d_cm / 100)^2

diametro_meio_secao <- function(h0, h1, d0, d1) {
  h_mid <- (h0 + h1) / 2
  d0 + (d1 - d0) * (h_mid - h0) / (h1 - h0)
}

vol_smalian <- function(hi, di) {
  n <- length(hi); vol_total <- 0
  for (i in 1:(n - 1)) {
    L <- hi[i + 1] - hi[i]
    A0 <- area_seccional(di[i]); A1 <- area_seccional(di[i + 1])
    vol_total <- vol_total + ((A0 + A1) / 2) * L
  }
  vol_total
}

vol_huber <- function(hi, di) {
  n <- length(hi); vol_total <- 0
  for (i in 1:(n - 1)) {
    L <- hi[i + 1] - hi[i]
    dm <- diametro_meio_secao(hi[i], hi[i + 1], di[i], di[i + 1])
    Am <- area_seccional(dm)
    vol_total <- vol_total + Am * L
  }
  vol_total
}

vol_newton <- function(hi, di) {
  n <- length(hi); vol_total <- 0
  for (i in 1:(n - 1)) {
    L <- hi[i + 1] - hi[i]
    dm <- diametro_meio_secao(hi[i], hi[i + 1], di[i], di[i + 1])
    A0 <- area_seccional(di[i]); A1 <- area_seccional(di[i + 1])
    Am <- area_seccional(dm)
    vol_total <- vol_total + ((A0 + 4 * Am + A1) / 6) * L
  }
  vol_total
}

# ---- Leitura da base de cubagem --------------------------------------------
# Ajuste o caminho abaixo para onde está a base no seu repositório
# (ex.: "data/cubagem.csv" ou "cubagem.xlsx" lido via readxl).
cubagem <- read.csv("cubagem.csv", encoding = "UTF-8", check.names = TRUE)
names(cubagem)[1] <- "Talhao"

# ---- Volume por árvore pelos três métodos ----------------------------------
arvores <- unique(cubagem$Arv)
resultados <- do.call(rbind, lapply(arvores, function(a) {
  df_a <- cubagem[cubagem$Arv == a, ]
  df_a <- df_a[order(df_a$hi), ]
  data.frame(
    arvore    = a,
    dap_cm    = df_a$DAP[1],
    altura_m  = df_a$HT[1],
    v_smalian = vol_smalian(df_a$hi, df_a$di),
    v_huber   = vol_huber(df_a$hi, df_a$di),
    v_newton  = vol_newton(df_a$hi, df_a$di)
  )
}))

# Diferenças relativas (%) entre cada par de métodos, por árvore
resultados$dif_smalian_huber_pct  <- (resultados$v_smalian - resultados$v_huber)  / resultados$v_huber  * 100
resultados$dif_smalian_newton_pct <- (resultados$v_smalian - resultados$v_newton) / resultados$v_newton * 100
resultados$dif_huber_newton_pct   <- (resultados$v_newton  - resultados$v_huber)  / resultados$v_huber  * 100

# ---- Classes de DAP (largura de 2 cm, cobrindo a amplitude observada) -----
LARGURA_CLASSE <- 2
dap_min <- floor(min(resultados$dap_cm) / LARGURA_CLASSE) * LARGURA_CLASSE
dap_max <- ceiling(max(resultados$dap_cm) / LARGURA_CLASSE) * LARGURA_CLASSE
quebras <- seq(dap_min, dap_max, by = LARGURA_CLASSE)
rotulos <- sprintf("%d-%d", quebras[-length(quebras)], quebras[-1])

resultados$classe_dap <- cut(resultados$dap_cm, breaks = quebras, labels = rotulos,
                              right = FALSE, include.lowest = TRUE)

# ---- Agregação por classe de DAP -------------------------------------------
n_por_classe <- table(resultados$classe_dap)
dap_medio    <- tapply(resultados$dap_cm, resultados$classe_dap, mean)
dif_sh_media <- tapply(resultados$dif_smalian_huber_pct, resultados$classe_dap, mean)
dif_sh_max   <- tapply(resultados$dif_smalian_huber_pct, resultados$classe_dap, max)
dif_sn_media <- tapply(resultados$dif_smalian_newton_pct, resultados$classe_dap, mean)
dif_hn_media <- tapply(resultados$dif_huber_newton_pct, resultados$classe_dap, mean)

tabela_classes <- data.frame(
  classe_dap_cm                = names(n_por_classe),
  n_arvores                    = as.integer(n_por_classe),
  dap_medio_cm                 = round(as.numeric(dap_medio), 2),
  dif_smalian_huber_media_pct  = round(as.numeric(dif_sh_media), 3),
  dif_smalian_huber_max_pct    = round(as.numeric(dif_sh_max), 3),
  dif_smalian_newton_media_pct = round(as.numeric(dif_sn_media), 3),
  dif_huber_newton_media_pct   = round(as.numeric(dif_hn_media), 3)
)

# Remove classes vazias (sem árvores) e ordena por DAP crescente
tabela_classes <- tabela_classes[!is.na(tabela_classes$n_arvores) & tabela_classes$n_arvores > 0, ]
tabela_classes <- tabela_classes[order(as.numeric(sub("-.*", "", tabela_classes$classe_dap_cm))), ]
rownames(tabela_classes) <- NULL

# ---- Saída em console e em arquivo -----------------------------------------
cat("== Diferenças (%) entre métodos de cubagem, por classe de DAP ==\n\n")
print(tabela_classes)

cat("\nClasse com MENOR diferença média (Smalian x Huber):",
    tabela_classes$classe_dap_cm[which.min(tabela_classes$dif_smalian_huber_media_pct)],
    "->", round(min(tabela_classes$dif_smalian_huber_media_pct), 3), "%\n")

cat("Classe com MAIOR diferença média (Smalian x Huber):",
    tabela_classes$classe_dap_cm[which.max(tabela_classes$dif_smalian_huber_media_pct)],
    "->", round(max(tabela_classes$dif_smalian_huber_media_pct), 3), "%\n")

cat("\nCorrelação (Pearson) entre DAP e diferença % Smalian-Huber (por árvore):",
    round(cor(resultados$dap_cm, resultados$dif_smalian_huber_pct), 3), "\n")

write.csv(resultados, "diferencas_por_arvore.csv", row.names = FALSE)
write.csv(tabela_classes, "diferencas_por_classe_dap.csv", row.names = FALSE)
