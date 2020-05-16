# analyse des sortie de l'ago génétique d'openMole
#Auteur : E. Delay (CIRAD ES, GREEN)
## Attention 
# Dans tout les algo génétique, il ne faut pas prendre toutes les sorties.
# seulement le dernier fichier générer qui normalement porte les simu
# les plus prometeuse.

library(ggplot2)
# library(gganimate)

rm(list = ls())

setwd("~/github/Covprehention/proto/confinement/")
my.path <- "data/calibration_nsga2/"
# 
# files.l <- list.files(my.path)
# data.df <- data.frame()
# 
# ## aggreger les fichers
# for(i in 1:length(files.l)){
#   tmp <- read.csv(paste0(my.path, files.l[i]), header = T)
#   data.df <- rbind(data.df, tmp)
# }

data.df <- read.csv("data/calibration_nsga2/population20000.csv")

sel <- data.df$evolution.samples >= 100
data.df <- data.df[sel,]
summary(data.df)


data.df$pic_max <- data.df$pic_max/200*100
data.df$init_conf <- data.df$init_conf / 4
data.df$duration_conf <- data.df$duration_conf / 4
data.df$relesae_conf <- data.df$relesae_conf / 4


g1 <- ggplot() + 
  geom_point(data = data.df, aes(x = jours_confinement, y = pic_max, size = evolution.samples), alpha = 0.5)+
  # geom_point(data = small.df, aes(x = duration_conf, y = init_conf, size = -pic_max.1 ,colour = pic_max))+
  annotate("segment", x = 19, xend = 30, y = 24, yend = 70)+
  scale_size("Robustesse\ndu résultat")+
  scale_color_gradient("% de pop\nnon touché par\nle virus")+
  labs(x = "Nombre de jours de confinement effectif", 
       y = "Nombre maximum de personne infecté simultanément)")+
  xlim(0,80)+
  ylim(10, 100)+
  theme_bw()
g1

ggsave("img/Q6-A1-1-NSGA2.png", plot = g1 ,width = 10, height = 8, dpi = 120)

############################################################################################################
##
############################################################################################################



ggplot(data.df, aes(x = duration_conf, y = init_conf, 
                    colour = pic_max, size = -pic_max.1, group =1) ) + 
  geom_point()+
  #facet_wrap(.~relesae_conf, labeller = label_both)+
  scale_color_gradient("% de pop\nconserné\npar le pic")+
  scale_size("Ecart type",breaks=c(0,-10,-20, -30), labels=c(0,10,20, 30))+
  labs(title="Le pic max de contiaminé", 
       subtitle = 'Frame {frame} of {nframes}',
       x = "jours de confinements", 
       y = "premier jours de confinement\n(après le premier cas)")+
  geom_text(x = 50 , y = 18,  
            family = "Times",  
            aes(label = as.character(round(relesae_conf))),  
            size = 10, col = "grey18")+
  theme_bw()+
  transition_time(relesae_conf)


ggplot() + 
  geom_point(data = data.df, aes(x = duration_conf, y = init_conf, colour = pic_max, size = -pic_max.1))+
  # geom_point(data = small.df, aes(x = duration_conf, y = init_conf, size = -pic_max.1 ,colour = pic_max))+
  scale_size("Ecart type",breaks=c(0,-10,-20, -30), labels=c(0,10,20, 30))+
  facet_grid(.~relesae_conf)+
  scale_color_gradient("% de pop\nconserné\npar le pic")+
  labs(title="L'effet de la durée de la pause de confinement\nsur le pic max de contiaminé", 
       x = "nombre de jours de confinements effectif", 
       y = "premier jours de confinement\n(après le premier cas)")+
  theme_bw()
