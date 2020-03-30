## Produire un graph qui mettent en évidence l'effet du coeff de trasnmision

library(ggplot2)
library(dplyr)
library(extrafont)
library(xkcd)
library(gganimate)

rm(list = ls())

setwd("~/github/Covprehention/proto/base/")

data.df <- read.csv("data/CoVprehension transmission_sim1b-table.csv", header = T, skip = 6)


## Graphique dynamique ####

ggplot(data = data.df, aes(x = X.step., y=(nb_Ir/500)*100, colour = i.proba.transmission))+
  geom_point()+
  # transition_time(i.proba.transmission)+
  # shadow_mark(alpha = 0.3, size = 0.5)+
  labs( x = "temps", y = "% de personnes infectées")+
  xlim(0,350)+
  scale_colour_gradient(low = "yellow", high = "red", na.value = NA, 
                        "probabilité de transmission\ndu virus à chaque contact")+
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

## Histograme des contamination
# ggplot(data = small.df)+
#   geom_col(aes(x = X.step., y = med.contamination, fill = i.proba.transmission),
#            binwidth = 0.2)+
#   facet_wrap(.~i.proba.transmission)+
#   xlim(0,300)+
#   theme_light()

ggplot(data = small.df)+
  geom_line(aes(x = X.step., y = med.Ir/500*100, group = i.proba.transmission, colour = i.proba.transmission))+
  labs(x = "temps", y = "% de personnes infectées")+
  scale_colour_gradient(low = "yellow", high = "red", na.value = NA, 
                        "probabilité de transmission\ndu virus à chaque contact")+
  # theme_light()
  theme_classic()
ggsave("img/pct_infected.png")  
