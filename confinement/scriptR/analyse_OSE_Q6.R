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
#     nb.Ir = median(nb.Ir),
#     nb.R = median(nb.R)
#     ) -> small.df

small.df <- subset(data.df, select =c(s.time,nb.S, nb.Ir, nb.R))

small.df <- melt(small.df,  id.vars = "s.time")

gg1 <- ggplot(data = small.df)+
  geom_smooth(aes(x = s.time, y = value, color= variable))+
  geom_point(aes(x = s.time, y = value, color= variable), alpha = 0.01)+
  scale_color_manual(values=c("#0099ff", "#ff0000", "#ffffff"), "")+
  labs(x = "temps", y = "% de la population")+
  theme_dark()
gg1


data.df %>% 
  group_by(s.time) %>%
  summarise(
    max.Ir = median(max.Ir)
  ) -> small2.df


gg2 <- ggplot(data = data.df)+
  geom_smooth(aes(x = s.time, y = max.Ir))
  labs(x = "temps", y = "% de la population max infecté")+
  theme_dark()
gg2
