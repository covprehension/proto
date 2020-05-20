library(tidyverse)
library(plot3D)

data <- read_csv("~/Documents/CoVprehension/proto/strategiesDepistage/explo/calib_population13000.csv") %>%
    select(strategy:nbUndetectedInfected, samples = "evolution$samples")

count(group_by(data, ))


data_color <- data %>%
    filter(samples > 50) %>%
    mutate(color = ifelse(strategy == "symptomatic", 1, ifelse(strategy == "workers", 2, 3)))

scatter3D(x = data_color$totalTests, y = data_color$FPTests, z = data_color$nbUndetectedInfected,
          # colvar = data_color$color, col = c("#ff0000", "#feb24c", "#999999"),
          # colkey = list(at = c(1.33, 2, 2.66), labels = c("symptomatic", "workers", "older"), side = 3, length = 0.5, width = 0.5),
          colvar = data_color$color, col = c("#ff0000"),
          colkey = list(at = 1, labels = c("symptomatic"), side = 3, length = 0.5, width = 0.5),
          theta = 25, phi = 40,
          xlab = "total nb tests", ylab = "nb of FP tests", zlab = "nb of infected undetected", ticktype = "detailed",
          pch = 19, bty = "b2")

data_limited <- data %>%
    filter(samples > 50) %>%
    ggplot(aes(x = totalTests, y = nbUndetectedInfected, color = numberDailyTestsPer10000)) +
    geom_point(size = 5) +
    # stat_smooth(method = "lm") +
    scale_color_viridis_c(name = "Nombre quotidien\nde tests") +
    xlab("Nombre total de tests utilisés") +
    ylab("Nombre de personnes infectées\nmais non détectées") +
    # scale_color_viridis_c(name = "Daily number\nof tests") +
    # xlab("Total number of tests") +
    # ylab("Number of undetected infected people") +
    theme_bw(base_size = 16)
data_limited

ggsave("../../../img/posts/Q17-calib-fr.png", plot = data_limited, device = "png", width = 8, height = 5, dpi = 300)
ggsave("../../../img/posts/Q17-calib-en.png", plot = data_limited, device = "png", width = 7, height = 5, dpi = 300)
