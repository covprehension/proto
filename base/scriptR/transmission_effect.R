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

small.df <- data.df %>% ##Aggreger les résultats 
  group_by(X.step., i.proba.transmission) %>%
  summarise(med.contamination = median(current.nb.new.infections.reported) + median(current.nb.new.infections.asymptomatic),
            med.s = median(nb_S),
            med.Ir = median(nb_Ir),
            med.Inr = median(nb_Inr))

ggplot(data = small.df)+
  geom_col(aes(x = X.step., y = med.contamination, fill = i.proba.transmission),
           binwidth = 0.2)+
  facet_wrap(.~i.proba.transmission)+
  xlim(0,300)+
  theme_light()

ggplot(data = small.df)+
  geom_line(aes(x = X.step., y = med.s/500*100, group = i.proba.transmission, colour = i.proba.transmission))+
  labs(title = "Evolution du nombre de personnes\nen bonne santé", x = "temps", y = "% de malade")+
  scale_color_continuous("Probabilité\nde contaminer\nune personne\nrencontré")+
  theme_light()
ggsave("img/pct_saint.png")  
