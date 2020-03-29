## Produire un graph qui mettent en évidence l'effet du coeff de trasnmision

library(ggplot2)
library(dplyr)
library(gganimate)

rm(list = ls())

setwd("~/github/Covprehention/proto/base/")

data.df <- read.csv("data/CoVprehension transmission_sim1b-table.csv", header = T, skip = 6)


## Graphique dynamique ####

ggplot(data = data.df, aes(x = X.step., y=nb_S, colour = i.proba.transmission))+
  geom_point()+
  # transition_time(i.proba.transmission)+
  # shadow_mark(alpha = 0.3, size = 0.5)+
  labs( title = 'Transmission probability', x = "time after first infection", y = "healthy person")+
  # ggtitle('Transmission probability : {i.proba.transmission}')+
  transition_states(i.proba.transmission,
                    transition_length = 2,
                    state_length = 1)
## Graphique statique ####

small.df <- data.df %>% ##Aggreger les résultats par run et récupérer le dernier tour
  group_by(X.run.number.) %>% summarise(maX.step = max(X.step.))