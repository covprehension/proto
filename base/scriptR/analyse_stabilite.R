###un script pour estimer le nombre de réplication nécessaire pour stabiliser les résultats de Dion
rm(list = ls())
library(ggplot2)
library(dplyr)


##definition du repertoir de travail
setwd("~/github/Covprehention/proto/base/")

##chargement de la fonction
source("scriptR/fon_sample_random.R")

##lecture des données
data.df<-read.csv("data/CoVprehension vraiabilite_simu1a-table.csv",header = T, skip = 6)


##defintion du theme ggplot
ggtheme<-theme(strip.text.x = element_text(size=15),
               strip.text.y = element_text(size=15),
               legend.title = element_text(size=14),
               axis.title.x = element_text(face="bold", size=24),
               axis.title.y = element_text(face="bold", size=24)
)


small.df <- data.df %>% ##Aggreger les résultats par run et récupérer le dernier tour
  group_by(X.run.number.) %>% summarise(maX.step = max(X.step.))

variance.df<-NULL
seq.v<-seq(from=10, to=100, by=5) #nombre de simulation par sample
for(i in seq.v){
  ##On passe a la fonction poolRandom la colonne qu'on veux sampler, le nombre d'indiv et le nombre de groupe
  mySample.df<-as.data.frame(poolRandom_fct(small.df[['maX.step']],i,10))
  colnames(mySample.df)<-c("value","group")
  
  ###Partie numérique
  a<-aggregate(value~group,mySample.df,median)
  vari<-c(i,var(a$value))
  variance.df<-rbind(variance.df, vari)
  ###Partie graphique
  bplot<-ggplot()+
    geom_boxplot(data=mySample.df, aes(x=as.factor(group), y=value))+
    labs(x="échantillon", y="NPC")+
    scale_fill_discrete(name="")+
    ggtheme
  #print(bplot)
  ggsave(paste("img/exploration_repetition/echantillon10",i,".png",sep=""), bplot, height = 8, width = 10)
}


## Il semble qu'il y ait une stabilité à partir de 60 réplication