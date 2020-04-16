library(tidyverse)

myData <- tribble(
    ~immunised, ~infected,
    0, 99.93,
    5, 99.92,
    10, 99.91,
    15, 99.84,
    20, 99.69,
    25, 99.27,
    30, 99,
    35, 97.91,
    40, 96.37,
    45, 88.76,
    # 46, 86.89,
    47, 44.63,
    # 48, 58.91,
    # 49, 46.15,
    50, 6.57,
    55, 4.05,
    60, 3.29,
    65, 0.59,
    70, 0.21,
    75, 0.16
)

myPlot <- myData %>%
    ggplot(aes(immunised, infected)) +
    geom_point() +
    geom_line() +
    scale_x_continuous(breaks = seq(0, 100, 5), name = "% personnes immunisées initialement") +
    scale_y_continuous(breaks = seq(0, 100, 10), name = "% personnes saines infectées à la fin") +
    theme_bw()
myPlot

ggsave("~/Documents/CoVprehension/website/img/Q8-tauxImmuniteCollective-fr.png", myPlot, device = "png", width = 5, height = 5, dpi = 300)


repet <- read_csv("tauxImmunColl-table.csv")

avg <- repet %>%
    filter(infected != 0) %>%
    group_by(immunised) %>%
    summarise(mean = mean(infected))

distrib <- repet %>%
    filter(infected != 0) %>%
    ggplot(aes(immunised, infected)) +
    # geom_point() +
    # geom_boxplot() +
    # stat_smooth() +
    stat_summary(fun = mean, geom = "point") +
    # stat_summary(fun.data = mean_cl_normal, geom = "errorbar", color = "red") +
    # stat_summary(fun = median, geom = "point", color = "green") +
    # scale_x_continuous(breaks = seq(0, 100, 5), name = "% personnes immunisées initialement") +
    # scale_y_continuous(breaks = seq(0, 100, 10), name = "% personnes saines infectées à la fin") +
    scale_x_continuous(breaks = seq(0, 100, 5), name = "% of people initially immunised") +
    scale_y_continuous(breaks = seq(0, 100, 10), name = "% of people infected in the end") +
    theme_bw()
distrib

ggsave("~/Documents/CoVprehension/website/img/posts/Q8-tauxImmuniteCollective-fr.png", distrib, device = "png", width = 5, height = 5, dpi = 300)
ggsave("~/Documents/CoVprehension/website/img/posts/Q8-tauxImmuniteCollective-en.png", distrib, device = "png", width = 5, height = 5, dpi = 300)
