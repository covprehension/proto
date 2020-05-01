# Après OSE dans OpenMole, un seul résultat permet d'atteindre l'optimum 
# udentifier dans PSE
# evolution.generation init_conf duration_conf relesae_conf jours_confinement
# 1                 2100  20.19938      63.18548           80             15.75
# pic_max evolution.samples
# 1      49                 1
# On va chercher à repliquer cette configuration avec BS pour evaluer ça stabilité

#Auteur : E. Delay (CIRAD ES, GREEN)

library(ggplot2)
library(dplyr)
library(reshape2)
library(ggConvexHull)

rm(list = ls())

setwd("~/github/Covprehention/proto/confinement/")
data.df <- read.csv(file = "data/CoVprehension_Confinement_Q6_explo_BS-table.csv",
                    skip = 6, 
                    header = T)

data.df$nb.S <- data.df$nb.S/200*100
data.df$max.Ir <- data.df$max.Ir/200*100
data.df$nb.Ir <- data.df$nb.Ir/200*100
data.df$nb.R <- data.df$nb.R/200*100
data.df$s.time <- data.df$X.step. / 4


# data.df %>%
#   group_by(s.time) %>%
#   summarise(
#     nb.S = median(nb.S),
#     sd.S = sd(nb.S),
#     nb.Ir = median(nb.Ir),
#     sd.Ir = sd(nb.Ir),
#     nb.R = median(nb.R),
#     sd.R = sd(nb.R)
#     ) -> small.df

## preparer le gros data frame pour qu'il soit compatible avec ggplt
data.dfgg <- subset(data.df, select =c(s.time,nb.S, nb.Ir, nb.R)) %>%
                melt(id.vars = "s.time")


## Preparer l'enveloppe des point
small.df <- subset(data.df, select =c(s.time,nb.S, nb.Ir, nb.R)) %>%
              group_by(s.time) %>%
              summarise_each(funs(min, max)) ## Calucler le min et max de chaque tick

small1.df <- small.df[,1:4] %>%
                melt(id.vars = "s.time") ## Couper par min et convertir en 3 colonnes
small2.df <- small.df[,c(1,5:7)] %>%
                melt(id.vars = "s.time") ## Couper par max et convertir en 3 colonnes
small.df <- small1.df %>% left_join(small2.df, by = "s.time") ## jointure des deux sous data frame
rm(small1.df, small2.df)

## Plot
# gg1 <- ggplot()+
#   geom_point(data = data.dfgg, aes(x = s.time, y = value, color= variable), alpha = 0.05)+
#   geom_errorbar(data = small.df,aes(x = s.time, y = value.x,
#                                   ymin = value.x, ymax = value.y,
#                                   color= variable.x), alpha = 0.01)+
#   # scale_color_manual(values=c("#0099ff", "#ff0000", "#ffffff"))+
#   labs(x = "temps", y = "% de la population")
#   # theme_dark()
# gg1

gg1 <- ggplot()+
  geom_boxplot(data = data.dfgg, aes(x = as.factor(s.time), y = value, color= variable), alpha = 0.03)+
  scale_x_discrete(breaks=seq(0, 127, 20))+
  # scale_color_manual(values=c("#0099ff", "#ff0000", "#ffffff"))+
  scale_color_brewer(palette="Dark2", name="% de la population", labels=c("Saint","Infecté","Immunisé"))+
  labs(x = "temps", y = "% de la population")+
  # theme_dark()
  theme_bw()
gg1

ggsave("img/out_ose_solution.png",gg1, height = 6, width = 8)

