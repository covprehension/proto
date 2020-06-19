library(tidyverse)

setwd("~/Documents/CoVprehension/proto/confinement")

raw_data <- read_csv("data/replicated_post_pse.csv")

vec_index <- c()
for (i in 1:173) {
    tmp <- rep(i, 100)
    vec_index <- c(vec_index, tmp)
}

data <- raw_data %>%
    mutate_at(vars(ends_with("_conf")), ~ . / 4) %>%
    mutate_at(vars(nbIr:nbS, pic_max), ~ . / 200 * 100) %>%
    select(lockdownStartingDate = init_conf, lockdownDuration = duration_conf, lockdownPauseDuration = relesae_conf,
           propS = nbS, propI = nbIr, propR = nbR,
           peakHeight = pic_max, totalLockdownDuration = jours_confinement, nbLockdowns = nb_confinement, seed) %>%
    arrange(lockdownStartingDate, lockdownDuration, lockdownPauseDuration) %>%
    add_column(index = vec_index) %>%
    select(index, everything())



plot_pse <- data %>%
    # group_by(lockdownStartingDate, lockdownDuration, lockdownPauseDuration) %>%
    # summarise_at(vars(propR:totalLockdownDuration), list(mean)) %>%
    ggplot(aes(x = peakHeight, y = totalLockdownDuration, color = propR)) +
    # ggplot(aes(x = propR, y = totalLockdownDuration, color = peakHeight)) +
    # ggplot(aes(x = peakHeight, y = propR, color = totalLockdownDuration)) +
    geom_point() +
    scale_color_viridis_c() +
    # scale_y_continuous(breaks = seq(0, 100, 25), limits = c(0, 100)) +
    theme_bw()
plot_pse



best_area <- data %>%
    group_by(index) %>%
    summarise_at(vars(propR:totalLockdownDuration), list(mean)) %>%
    filter(totalLockdownDuration < 25 & peakHeight < 25 & propR < 40) %>%
    select(index) %>%
    inner_join(data)

plot_distrib <- best_area %>%
    pivot_longer(cols = propR:totalLockdownDuration, names_to = "output", values_to = "value") %>%
    # ggplot(aes(x = output, y = value, color = lockdownPauseDuration)) +
    ggplot(aes(x = output, y = value)) +
    geom_boxplot(aes(group = output)) +
    # facet_grid(lockdownStartingDate ~ lockdownDuration) +
    facet_wrap(~ index) +
    theme_bw()
plot_distrib


plot_input_space <- best_area %>%
    ggplot(aes(x = lockdownDuration, y = lockdownPauseDuration, color = lockdownStartingDate)) +
    geom_point() +
    scale_color_viridis_c() +
    theme_bw()
plot_input_space
