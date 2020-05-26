# Après OSE dans OpenMole, un seul résultat permet d'atteindre l'optimum 
# udentifier dans PSE
# evolution.generation init_conf duration_conf relesae_conf jours_confinement
# 1                 2100  1      53           77             5
# pic_max evolution.samples
# 1      49                 1
# On va chercher à repliquer cette configuration avec BS pour evaluer ça stabilité

#Auteur : E. Delay (CIRAD ES, GREEN)
  
  library(ggplot2)
  library(dplyr)
  library(reshape2)
  
  rm(list = ls())
  
  setwd("~/github/Covprehention/proto/confinement/")
  
  data.df <- read.csv(file = "data/CoVprehension_300320_Confinement_Q6_explo experiment-pse-table.csv",
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
  
  
  
  data.dfgg <- data.dfgg[!data.dfgg$s.time%%1,]
  # confinement 13,25j
  # deconfinement 1.25j
  
  gg1 <- ggplot()+
    geom_boxplot(data = data.dfgg, aes(x = as.factor(s.time), y = value, color= variable), alpha = 0.03)+
    scale_x_discrete(breaks=seq(0, 130, 20))+
    geom_vline(xintercept = c(1, 14.25, 15.5, 28.75, 30, 43.25, 44.5, 57.75, 59,72.25, 73.5, 86.75), linetype="twodash")+
    annotate("rect", xmin = c(1,15.5,30, 44.5, 59, 73.5), xmax = c(14.25, 28.75, 43.25,57.75, 72.25, 86.75), ymin = 0, ymax = 100, alpha = .2)+
    annotate("text", x = c(1,15.5,30, 44.5, 59, 73.5)+2, y = 95, label = c("confinement","confinement",
                                                                           "confinement","confinement",
                                                                           "confinement","confinement"),
             angle = 90,)+
    annotate("segment", x = 15, y = 10, xend = 7, yend = 45)+
    annotate("text", x = 10, y = 47, label = "Déconfinement")+
    scale_color_brewer(palette="Dark2", name="Proportion\nde la population", 
                       labels=c("Saine","Infectée","Guérie"))+
    labs(x = "Durée de l’épidémie, en jours", y = "Proportion de la population")+
    theme_bw()
  gg1
  
  ggsave("img/Q6-A1-BS-PSE-explo.png",gg1, height = 8, width = 10)


#########################################################################################
## On veut regarder par simulation si on ne dépasse jamais les critère de l'ago génétique 
#########################################################################################
# On va partir de data.df
# On selection toutes les ticks qui remplisse les condition de l'algo générique
# C'est à dire (considérant résultat de PSE):
#  (jours_confinement = nb.j.conf ) < 15
#  (pic_max = max.Ir) < 40
#  (nbS = nb.S) > 60
#  (nb conf=nb.confinement) <=2
#  (init_conf=i.Confinement.init) <=10


good.condition.df <- data.frame()

for(i in c(1:max(data.df$X.run.number.))){
  sub.df <- data.df[data.df$X.run.number. == i,]
  if(max(sub.df$nb.j.conf) <=30){
    if(max(sub.df$max.Ir) <= 21){
      if(max(sub.df$nb.S) > 71){ # remplacer 60 par 56
        if(max(sub.df$nb.confinement <= 2)){
          #if(max(sub.df$i.Confinement.init) <= 10){
            good.condition.df <- rbind(good.condition.df, sub.df)
          #}
        }
      }
    }
  }
}

n <- length(unique(good.condition.df$X.run.number.))/length(unique(data.df$X.run.number.))*100
paste( "Proportion de réussite ", n, " %")

##Je veut compter le nombre de ligne avec le même X.Step. pour savoir combien
## de simulation on tourner 

data.dfgg %>% 
  count(s.time) -> %>%
  left_join(data.dfgg) -> data2.dfgg

data2.dfgg$n <- data2.dfgg$n / 3000 * 100

gg2 <- ggplot(data = data.dfgg)+
  geom_boxplot( aes(x = as.factor(s.time), y = value, color= variable), alpha = 0.3)+
  geom_line(aes(x = as.factor(s.time), y = n))+
  scale_x_discrete(breaks=seq(0, 130, 20))+
  geom_vline(xintercept = c(1, 14.25, 15.5, 28.75, 30, 43.25, 44.5, 57.75, 59,72.25, 73.5, 86.75), linetype="twodash")+
  annotate("rect", xmin = c(1,15.5,30, 44.5, 59, 73.5), xmax = c(14.25, 28.75, 43.25,57.75, 72.25, 86.75), ymin = 0, ymax = 100, alpha = .2)+
  annotate("text", x = c(1,15.5,30, 44.5, 59, 73.5)+2, y = 95, label = c("confinement","confinement",
                                                                         "confinement","confinement",
                                                                         "confinement","confinement"),
           angle = 90,)+
  annotate("segment", x = 15, y = 10, xend = 7, yend = 45)+
  annotate("text", x = 10, y = 47, label = "Déconfinement")+
  scale_color_brewer(palette="Dark2", name="Proportion\nde la population", 
                     labels=c("Saine","Infectée","Guérie"))+
  labs(x = "Durée de l’épidémie, en jours", y = "Proportion de la population")+
  theme_bw()
gg2

ggsave("img/Q6-A1-BS-PSE-explo-alpha.png",gg, height = 8, width = 10)
