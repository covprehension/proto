# Analyse des résultat de direct sampling réaliser avec OpneMole. 
#Auteur : E. Delay (CIRAD ES, GREEN)

library(ggplot2)
library(gganimate)

setwd("~/github/Covprehention/proto/confinement/")
data.df <- read.csv(file = "data/result.csv")

# OM directSampling 40 replication
# (init_conf in (10.0 to 80.0 by 4.0))x
# (relesae_conf in (10.0 to 24.0 by 4.0))x
# (duration_conf in (28.0 to 60 by 4.0))

table(data.df$init_conf)


