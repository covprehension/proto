# analyse des sortie de l'ago génétique d'openMole
# Auteur : E. Delay (CIRAD ES, GREEN)
library(ggplot2)
# library(gganimate)
#library(gridExtra)

rm(list = ls())

setwd("~/github/Covprehention/proto/confinement/")

data.df <- read.csv("data/results_pse/population20000.csv", header = T)

summary(data.df)

data.df$nbS <- data.df$nbS/200*100
data.df$pic_max <- data.df$pic_max/200*100
data.df$init_conf <- data.df$init_conf / 4         ## input : date du début du premier confinement
data.df$duration_conf <- data.df$duration_conf / 4 ## input : Durée d'un confinement
data.df$relesae_conf <- data.df$relesae_conf / 4   ## input : temps entre deux confinement

# output jours_confinement : nombre de jour de confinement effectif
# output pic_max : nombre de personne toucher simultanenement


g2 <- ggplot() + 
  geom_point(data.df,  mapping = aes(x = jours_confinement, y = pic_max, colour = nbS, size = evolution.samples))+
  annotate("segment", x = 26.5, y = 21.5, xend = 50, yend = 10)+
  annotate("text", x = 54, y = 10, label = "Simu. 1")+
  annotate("segment", x = 13.5, y = 10, xend = 7, yend = 50)+
  annotate("text", x = 7, y = 52, label = "Simu. 2")+
  scale_color_gradient("% de pop\nnon touché par\nle virus")+
  scale_size("Robustesse\ndu résultat")+
  labs(x = "Nombre de jours de confinement effectif", 
       y = "Nombre maximum de personne infecté simultanément")+
  # xlim(0,80)+
  # ylim(10, 100)+
  theme_bw()
g2

ggsave("img/Q6-A1-1-PSE.png", plot = g2 ,width = 10, height = 8, dpi = 120)


## identifier les paramètres de simulation


data.df$nb_conf_effectif <- data.df$jours_confinement / data.df$duration_conf
length(data.df[data.df$nb_conf_effectif >= 1,1])
