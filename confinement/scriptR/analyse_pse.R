# analyse des sortie de l'ago génétique d'openMole
# Auteur : E. Delay (CIRAD ES, GREEN)
library(ggplot2)
library(gganimate)
library(gridExtra)

rm(list = ls())

setwd("~/github/Covprehention/proto/confinement/")
my.path <- "data/results_pse/"

files.l <- list.files(my.path)
data.df <- data.frame()

## aggreger les fichers
for(i in 1:length(files.l)){
  tmp <- read.csv(paste0(my.path, files.l[i]), header = T)
  data.df <- rbind(data.df, tmp)
}

summary(data.df)

data.df$nbS <- data.df$nbS/200*100
data.df$pic_max <- data.df$pic_max/200*100
data.df$init_conf <- data.df$init_conf / 4
data.df$duration_conf <- data.df$duration_conf / 4
data.df$relesae_conf <- data.df$relesae_conf / 4

# ggplot(data.df, aes(x = jours_confinement, y = pic_max, colour = nbS)) + 
#   geom_point()+
#   transition_states(evolution.generation)+
#   ease_aes('linear')

# colnames(data.df)[4] <- "pause"
# sel <- data.df$pause%%1==0

g1 <- ggplot(data.df ) + 
        geom_point(aes(x = duration_conf, y = init_conf, colour = pic_max, size = jours_confinement), alpha = 0.3)+
        scale_color_gradient("% de pop\nconserné\npar le pic")+
        scale_size("Nombre de jour\nréelement confinés")+
        labs(title="Résultat de l'ago PSE",
             subtitle = "effets sur les parametres d'entrés",
             x = "Durée du confinement imposé", 
             y = "premier jours de confinement\n(après le premier cas)")+
        theme_bw()
g1


ggsave("img/ag_explration_pse.png", plot = g1 ,width = 15, dpi = 120)

sel <- data.df$duration_conf <= 20 & data.df$init_conf <= 10
small.df <- data.df[sel,]

g2 <- ggplot() + 
  geom_point(data.df,  mapping = aes(x = jours_confinement, y = pic_max), shape = 1, alpha = 0.1)+
  # geom_smooth(data.df,  mapping = aes(x = jours_confinement, y = pic_max, colour = nbS, size = nbS))+
  geom_point(small.df,  mapping = aes(x = jours_confinement, y = pic_max, colour = nbS, size = nbS))+
  geom_smooth(small.df,  mapping = aes(x = jours_confinement, y = pic_max, colour = nbS, size = nbS))+
  # facet_wrap(.~pause, labeller = label_both)+
  #scale_color_gradient("% de pop\nconserné\npar le pic")+
  #scale_size("Nombre de personnes saine")+
  labs(title="Résultat de l'ago PSE",
       subtitle = "effets sur les parametres de sortie")+
  theme_bw()
g2


ggsave("img/ag_explration_pse2_loess.png", plot = g2 ,width = 15, dpi = 120)

g <- grid.arrange(g1, g2, nrow = 2)
ggsave("img/ag_explration_psearrange.png", g,width = 15, height = 10, dpi = 120)

g3 <- ggplot() + 
  geom_bin2d(data.df,  mapping = aes(x = jours_confinement, y = pic_max),binwidth = c(5, 5))+
  # geom_point(small.df,  mapping = aes(x = jours_confinement, y = pic_max, colour = nbS, size = nbS))+
  # geom_smooth(small.df,  mapping = aes(x = jours_confinement, y = pic_max, colour = nbS, size = nbS))+
  # facet_wrap(.~pause, labeller = label_both)+
  #scale_color_gradient("% de pop\nconserné\npar le pic")+
  #scale_size("Nombre de personnes saine")+
  labs(title="Résultat de l'ago PSE",
       subtitle = "effets sur les parametres d'entrés")+
  theme_bw()
g3


ggsave("img/ag_explration_pse3_tile.png", plot = g3 ,width = 15, dpi = 120)

