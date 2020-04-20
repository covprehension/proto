# analyse des sortie de l'ago génétique d'openMole
#Auteur : E. Delay (CIRAD ES, GREEN)
library(ggplot2)
library(gganimate)

rm(list = ls())

setwd("~/github/Covprehention/proto/confinement/")
my.path <- "data/calibration/"

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

colnames(data.df)[4] <- "pause"
sel <- data.df$pause%%1==0

g1 <- ggplot(data.df[sel,], aes(x = duration_conf, y = init_conf, colour = pic_max)) + 
        geom_point()+
        facet_wrap(.~pause, labeller = label_both)+
        scale_color_gradient("% de pop\nconserné\npar le pic")+
        labs(title="L'effet de la durée de la pause de confinement\nsur le pic max de contiaminé", 
             x = "jours de confinements", 
             y = "premier jours de confinement\n(après le premier cas)")
g1

ggsave("img/ag_explration_1.png", plot = g1 ,width = 15, dpi = 120)


