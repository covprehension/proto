# Après OSE dans OpenMole, un seul résultat permet d'atteindre l'optimum 
# udentifier dans PSE
# evolution.generation init_conf duration_conf relesae_conf jours_confinement
# 1                 2100  1      53           77             15.75
# pic_max evolution.samples
# 1      49                 1
# On va chercher à repliquer cette configuration avec BS pour evaluer ça stabilité

#Auteur : E. Delay (CIRAD ES, GREEN)

library(ggplot2)
library(dplyr)
library(reshape2)

rm(list = ls())

setwd("~/github/CoVprehension_git/proto/confinement/")

data.df <- read.csv(file = "data/CoVprehension_300320_Confinement_Q6_explo experiment-ose-table.csv",
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


gg1 <- ggplot()+
  geom_boxplot(data = data.dfgg, aes(x = as.factor(s.time), y = value, color= variable), alpha = 0.03)+
  scale_x_discrete(breaks=seq(0, 130, 20))+
  geom_vline(xintercept = c(1, 14.5, 33, 46, 65, 78, 97, 110, 129, 142), linetype="twodash")+
  annotate("rect", xmin = c(1,33,65,97, 129), xmax = c(14.5, 46, 78, 110, 142), ymin = 0, ymax = 100, alpha = .2)+
  annotate("text", x = c(1, 14.5, 33, 46, 65, 78, 97, 110, 129, 142)+2, y = 95, label = c("confinement","déconfinement",
                                                                 "confinement","déconfinement",
                                                                 "confinement","déconfinement",
                                                                 "confinement","déconfinement",
                                                                 "confinement","déconfinement"),
           angle = 90,)+
  scale_color_brewer(palette="Dark2", name="Proportion\nde la population", labels=c("Sains","Infectés","Immunisés"))+
  labs(x = "Durée de l'épidémie en jour", y = "Proportion de la population")+
  theme_bw()
gg1

ggsave("img/Q6-A1-BS-OSE.png",gg1, height = 8, width = 10)


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
  if(max(sub.df$nb.j.conf) <=15){
    if(max(sub.df$max.Ir) <= 40){
      if(max(sub.df$nb.S) > 56){ # remplacer 60 par 56
        if(max(sub.df$nb.confinement <= 2)){
          #if(max(sub.df$i.Confinement.init) <= 10){
            good.condition.df <- rbind(good.condition.df, sub.df)
          #}
        }
      }
    }
  }
}

gg3 <- ggplot(data = good.condition.df)+
  geom_point(aes(x = s.time, y = nb.S, color = X.run.number.))+
  annotate("rect", xmin = c(6,41,75,110), xmax = c(21, 56, 90, 125), ymin = 0, ymax = 100, alpha = .2)+
  annotate("text", x = c(6,21,41,56, 75,90, 110,125)+2, y = 90, label = c("confinement","déconfinement",
                                                                          "confinement","déconfinement",
                                                                          "confinement","déconfinement",
                                                                          "confinement","déconfinement"),
           angle = 90,)+
  theme_bw()
gg3