## Produire un graph qui mettent en évidence l'effet du coeff de trasnmision

library(ggplot2)
library(dplyr)
library(gganimate)

rm(list = ls())

setwd("~/github/Covprehention/proto/base/")

data.df <- read.csv("data/CoVprehension transmission_sim1b-table.csv", header = T, skip = 6)


## Graphique dynamique ####

ggplot(data = data.df, aes(x = X.step., y=(nb_Ir/500)*100, colour = i.proba.transmission))+
  geom_point()+
  labs( x = "temps", y = "% de personnes infectées")+
  xlim(0,350)+
  scale_colour_gradient(low = "yellow", high = "red", na.value = NA, 
                        "probabilité de transmission\ndu virus à chaque contact")+
  theme_classic()+
  transition_states(i.proba.transmission,
                    transition_length = 2,
                    state_length = 1)
  options(gganimate.dev_args = list(width = 400,height= 300))



## Graphique statique ####

small.df <- data.df %>% ##Aggreger les résultats 
  group_by(X.step., i.proba.transmission) %>%
  summarise(med.contamination = median(current.nb.new.infections.reported) + median(current.nb.new.infections.asymptomatic),
            med.s = median(nb_S),
            med.Ir = median(nb_Ir),
            med.Inr = median(nb_Inr))

small.df %>%
  ungroup() %>%
  # Aggregate to groups of length 5 Steps using integer division "%/%"
  # First Group = 0 to 4, second = 5 to 9, ...
  mutate(X.step.1 = 5 * (X.step. %/% 5)) %>%
  # Aggregate med.contamination for new groups by i.proba.transmission
  count(X.step.1, i.proba.transmission, wt = med.contamination, name = "med.contamination") -> small2.df 

# Histograme des contamination
ggplot(data = small2.df,aes(x = X.step.1, 
                           y = med.contamination, 
                           colour = as.factor(i.proba.transmission)))+
  geom_smooth(alpha = 1/5)+
  scale_fill_discrete("Probability of\ntransmission at\neach individual contact")+
  # geom_line(aes(group = as.factor(i.proba.transmission)), position = "stack")+
  labs(x = "Time",y ="% Infected People")+
  xlim(0,300)+
  theme_classic()
ggsave("img/pct_contamines.png") 

ggplot(data = small.df)+
  geom_line(aes(x = X.step., y = med.Ir/500*100, group = i.proba.transmission, colour = i.proba.transmission))+
  labs(x = "Time",y ="% Infected People")+
  scale_colour_gradient(low = "yellow", high = "red", na.value = NA, 
                        "Probability of\ntransmission at\neach individual\ncontact")+
  xlim(0,300)+
  theme_classic()
ggsave("img/pct_infected.png")  
