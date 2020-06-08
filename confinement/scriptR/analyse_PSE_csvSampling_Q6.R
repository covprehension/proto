## Un script qui va reprendre les réplications des réplication des résultat de PSE pour valider les médianes
## Et produire un graph qui parle de cette robustesse. Les résultats et donc le graphe analyse PSE 
## n'est pas suffisant !Maintenant on peut véritablement parler de robustesse.

library('ggplot2')
library('dplyr')


rm(list = ls())

setwd("~/github/Covprehention/proto/confinement/")

data.df <- read.csv("data/replicated_post_pse.csv", header = TRUE)

data.df$nbS <- data.df$nbS/200*100
data.df$pic_max <- data.df$pic_max/200*100
data.df$init_conf <- data.df$init_conf / 4         ## input : date du début du premier confinement
data.df$duration_conf <- data.df$duration_conf / 4 ## input : Durée d'un confinement
data.df$relesae_conf <- data.df$relesae_conf / 4   ## input : temps entre deux confinement
data.df$infected <- 100 - data.df$nbS

data.df <- data.df %>% 
  group_by(duration_conf,init_conf,relesae_conf) %>% 
  summarise(
    mean_nbIr = mean(nbIr, na.rm = TRUE),
    mean_nbS = mean(nbS, na.rm = TRUE),
    mean_nb_confinement = mean(nb_confinement, na.rm = TRUE),
    mean_pic_max = mean(pic_max, na.rm = TRUE),
    mean_jours_confinement = mean(jours_confinement, na.rm = TRUE),
    mean_infected = mean(infected, na.rm = TRUE),
    sd_infected = sd(infected),
    count=n()
         )



# output jours_confinement : nombre de jour de confinement effectif
# output pic_max : nombre de personne toucher simultanenement


g2 <- ggplot() + 
  geom_point(data.df,  mapping = aes(x = mean_jours_confinement, y = mean_pic_max, colour = mean_infected, size = sd_infected))+
  annotate("segment", x = 19, y = 24.5, xend = 7, yend = 50)+
  annotate("text", x = 7, y = 53, label = "A")+
  annotate("segment", x = 25, y = 21.5, xend = 50, yend = 10)+
  annotate("text", x = 54, y = 10, label = "B")+
  annotate("rect", xmin = 0, xmax = 27, ymin = 0, ymax = 25, alpha = .2)+
  scale_color_gradient("% de pop\ninfectée au cours\nde l’épidémie ")+
  scale_size("écart type\n sur % de pop\ninfectée\n(Robustesse)")+
  labs(x = "Nombre total de jours de confinement pour chaque simulation", 
       y = "Nombre maximum de personnes infectées simultanément (pic de l’épidémie)")+
  # xlim(0,80)+
  # ylim(10, 100)+
  theme_bw()
g2

ggsave("img/Q6-A1-1-PSE2.png", plot = g2 ,width = 10, height = 8, dpi = 120)