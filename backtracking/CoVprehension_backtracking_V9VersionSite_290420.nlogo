;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;DECLARATION;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [ ;;global parameters
  ;epidemic symbolic constants
  S ; Susceptible
  Ex ; Exposed - Infected and incubating, but already contagious.
  Ia ; Infected asymptomatic
  I ; Infected symptomatic
  R ; Recovered

  delay-before-test
  incubation-duration
  nb-days-before-test-tagging-contacts
  proportion-equiped
  probability-respect-lockdown
  probability-success-test-infected
  probability-asymptomatic-infection
  R0-a-priori
  initial-R-proportion
  size_population
  Nb_infected_initialisation

  population-size
  nb-house
  probability-transmission
  probability-transmission-asymptomatic
  walking-angle
  speed
  probability-car-travel
  current-nb-new-infections-reported
  current-nb-new-infections-asymptomatic
  transparency
  infection-duration
  contagion-duration
  nb-step-per-day
  lockdown-date
  previous-lockdown-state
  lock-down-color
  nb-lockdown-episodes
  max-I
  max-conf

  nb-infected-identified
  nb-infected-identified-removed
  nb-contagious-cumulated
  nb-non-infected-lockeddown
  nb-co-infected
  mean-daily-contacts
  mean-mean-daily-contacts
  contacts-to-warn
  contacts-to-warn-next
  list-mean-contacts

  tracers-this-tick
  traced-this-tick
  REACTING? ; doing anything?
  TRACING? ; contact-TRACING?
  TESTING? ; secondary testing, primary infected is always tested
  FAMILY-LOCKDOWN?
  fixed-seed?
]

patches-own [wall]

breed [citizens citizen]
breed [houses house]

citizens-own
[
  epidemic-state; S, Ex, Ia, I or R
  infection-date
  infection-source
  nb-other-infected
  contagion-counter ;;counter to go from state 1 or 2 (infected) to state 3 recovered
  contagious? ; boolean
  resistant? ; boolean - indicates in case of infection wether the citizen will express symptoms
  my-house
  lockdown? ; 0 free 1 locked
  nb-step-confinement
  liste-contacts
  liste-contact-dates
  daily-contacts
  equiped?
  detected?
  list-date-test
  nb-tests
  contact-order ;0 not contacted, 1 contacted at first order, 2 contacted at second order
  nb-contacts-ticks
  nb-contacts-total-Infectious ; total number of contacts during infectious period
  nb-lockeddown
  difference
  potential-co-infected
  family-infection?
  delayed-test
  to-be-tested
]

houses-own
[
  my-humans
  clean ; private. Should be accessed through reporter clean? [house]
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;SETUP;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-globals
  ;symbolic constants
  set S 0
  set Ex 1
  set Ia 2
  set I 3
  set R 4

  set delay-before-test  Temps-d'attente-pour-la-réalisation-du-test
  set nb-days-before-test-tagging-contacts Profondeur-temporelle-pour-l'identification-des-contacts
  set proportion-equiped Taux-de-couverture-de-l'application-de-traçage
  set probability-respect-lockdown Probabilité-de-respect-du-confinement
  set probability-success-test-infected Probabilité-que-le-test-soit-efficace
  set R0-a-priori R0-fixé
  set initial-R-proportion 0
  set size_population 1750
  set Nb_infected_initialisation 10

  set fixed-seed? false
  if fixed-seed?[
    random-seed 10
  ]

  set population-size  size_population
  set nb-house (population-size / 2)

  set walking-angle 50
  set speed 0.5
  set probability-car-travel 0.2
  set transparency 145
  set nb-step-per-day 4
  set incubation-duration 4
  set infection-duration 14
  set contagion-duration ((incubation-duration + infection-duration) * nb-step-per-day)
  set probability-asymptomatic-infection 0.3

  let nb-contacts (((population-size  / count patches) * 9) - 1) / 2 ; the / 2 is an approximate experimental value on how to go from #contacts per ticks to #contacts per day, without counting a contact twice
  set probability-transmission R0-a-priori / (nb-contacts * contagion-duration)
  set probability-transmission-asymptomatic probability-transmission / 2

  set contacts-to-warn-next no-turtles
  set contacts-to-warn no-turtles
  set list-mean-contacts []
  set mean-mean-daily-contacts []


  ifelse SCENARIO = "Laisser faire"[
    set REACTING? false
    set TRACING? false
    set TESTING? false
    set FAMILY-LOCKDOWN? false
  ][ifelse SCENARIO = "Confinement simple"[
    set REACTING? true
    set TRACING? false
    set TESTING? false
    set FAMILY-LOCKDOWN? true
  ][ifelse SCENARIO = "Traçage et confinement systématique"[
    set REACTING? true
    set TRACING? true
    set TESTING? false
    set FAMILY-LOCKDOWN? false
  ][ifelse SCENARIO = "Traçage et confinement sélectif"[
    set REACTING? true
    set TRACING? true
    set TESTING? true
    set FAMILY-LOCKDOWN? false
  ][
    show "error"
    stop
]]]]


end

to setup-walls
  ask patches with [abs(pxcor) = max-pxcor or abs(pycor) = max-pycor] [set wall 1]
end


to setup-houses
  create-houses nb-house[
    move-to one-of patches with [wall = 0]
    set shape "house"
    fd random-float 0.5
    setxy random-xcor random-ycor
    set size 2
    set color lput transparency extract-rgb  white
    set my-humans []
    set clean true
  ]
end

to setup-population
  create-citizens population-size
  [
    let me self
    move-to one-of patches with [wall = 0]
    fd random-float 0.5
    set shape "circle"
    set size 1
    set color green ; lput transparency extract-rgb  green
    set epidemic-state S
    set delayed-test delay-before-test / 6
    set to-be-tested false
    set nb-contacts-ticks 0
    set my-house one-of houses
    ask my-house[
      set my-humans lput me my-humans
    ]
    set liste-contacts []
    set liste-contact-dates []
    set list-date-test []
    set daily-contacts nobody
    set nb-other-infected 0
    set contact-order 0
    set potential-co-infected false
    set family-infection? false
    set equiped? false
    set detected? false
    set contagious? false
    set resistant? false ; resistance is really "defined" when the citizen is Exposed to the virus
  ]
  set-infected-initialisation
  set-R-initialisation
  set-equiped-initialisation
end

to set-equiped-initialisation
  ask n-of (round (population-size * (Proportion-equiped / 100))) citizens[
    set equiped? true
  ]
end


to set-infected-initialisation
  ask n-of Nb_infected_initialisation citizens [
    become-exposed
  ]
end

to set-R-initialisation
  ask n-of (initial-R-proportion / 100 * population-size) citizens with [not (epidemic-state = Ex)][
    set epidemic-state R
  ]
end

to setup
  clear-all
  reset-ticks
  setup-globals
  setup-walls
  setup-houses
  setup-population
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;GO;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if not any? citizens with [contagious?] [stop]

  move-citizens
  get-in-contact

  if TRACING?[
    set tracers-this-tick 0
    set traced-this-tick 0
    if any? contacts-to-warn[
      warn-contacts 2
    ]
  ]
  if REACTING?[
    ask citizens with [(epidemic-state = I) and (not detected?) and (lockdown? = 0) and (to-be-tested = false)] [
      set to-be-tested true
      set contact-order 1
    ]
    ask citizens with [to-be-tested = true][
      ifelse delayed-test = 0[
        get-tested
      ][
        set delayed-test delayed-test - 1
      ]
    ]
  ]

  if TRACING?[
    set traced-this-tick count contacts-to-warn-next
    set contacts-to-warn contacts-to-warn-next
    set contacts-to-warn-next no-turtles
  ]


  update-epidemics
  update-max-I
  update-max-conf
  update-list-mean-contacts
  update-mean-daily-contacts
  update-mean-mean-daily-contacts

  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;MOVEMENT PROCEDURES;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move-citizens
  ask citizens[
    ifelse lockdown? = 1[
      set nb-step-confinement (nb-step-confinement + 1)
      if epidemic-state = R[
        if clean? my-house[
          ask my-house[
          foreach my-humans[
            [my-human] -> ask my-human [
              set lockdown? 0
              ]
            ]
          ]
        ]
      ]
    ][
      let nighttime? (ticks mod 4) = 0
      ifelse nighttime?[
        move-to my-house ; night time
      ][
        ifelse random-float 1 < probability-car-travel[
          move-to one-of patches with [wall = 0]
        ][
          rt random 360
          avoid-walls
          fd speed
        ]
      ]
    ]
  ]
end

to avoid-walls
  ifelse  any? neighbors with [wall = 1]
    [ face one-of neighbors with [wall = 0] ]
  [set heading heading + random walking-angle - random walking-angle
      ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;EPIDEMIC PROCEDURES;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-epidemics
  ;;update the counters for the infected at this timestep
  set current-nb-new-infections-reported 0
  set  current-nb-new-infections-asymptomatic 0
  ;;update recovered
  ask citizens with [contagious?][
    set contagion-counter (contagion-counter - 1)
    if ( (ticks - infection-date) = incubation-duration ) [
      ifelse resistant?
        [ become-asymptomatic-infected ]
        [ become-infected ]
    ]

    if contagion-counter <= 0 [
      become-recovered
    ]
  ]
end

to get-virus [contact-source]
  ifelse ( ([contagious?] of contact-source)  and (random-float 1 < (contagiousness contact-source)) ) [
    become-exposed
    set infection-source contact-source
    ask contact-source [set nb-other-infected nb-other-infected + 1]
    set family-infection? (my-house = [my-house] of contact-source)
    if potential-co-infected [
      set nb-co-infected nb-co-infected + 1
    ]
  ][
    set potential-co-infected false
  ]
end


to get-in-contact
  ask citizens
  [
    ifelse lockdown? = 0[
      if (((ticks - 1) mod 4) = 0)[
        set daily-contacts nobody
      ]
      let contacts (turtle-set other citizens-here citizens-on neighbors)
      set nb-contacts-ticks count contacts
      set daily-contacts (turtle-set daily-contacts contacts)
      if contagious? [set nb-contacts-total-Infectious nb-contacts-total-Infectious + nb-contacts-ticks]
      set contacts contacts with [lockdown? = 0]
      if equiped? [
        let contacts-equiped contacts with [equiped?]
        set liste-contacts lput contacts-equiped liste-contacts
        set liste-contact-dates lput ticks liste-contact-dates
      ]
      let infection-contact one-of contacts with [contagious?]
      if epidemic-state = S and is-agent? infection-contact [
        get-virus infection-contact
      ]
    ][
      if epidemic-state = S[
        let co-infected? false
        let infection-contact nobody
        ask my-house[
          foreach my-humans[
            [my-human] -> ask my-human [
              if contagious?[
                set co-infected? true
                set infection-contact self
              ]
            ]
          ]
        ]
        if co-infected?[
          get-virus infection-contact
          set potential-co-infected true
        ]
      ]
    ]
  ]
end


to lockdown
  set lockdown? 1
  set lockdown-date ticks
  move-to my-house
  set nb-step-confinement 0
  set nb-lockeddown nb-lockeddown + 1
  ifelse contagious?[
    set nb-infected-identified-removed nb-infected-identified-removed + 1
  ][
    set nb-non-infected-lockeddown nb-non-infected-lockeddown + 1
  ]
end

to get-tested
  ;citizens get tested
  set list-date-test lput ticks list-date-test
  set nb-tests nb-tests + 1
  set delayed-test delay-before-test / 6
  set to-be-tested false
  ;test results and consequences
  if contagious? and random-float 1 < probability-success-test-infected [
    set detected? true
    set  nb-infected-identified nb-infected-identified + 1
    if (random-float 1 < probability-respect-lockdown)[
      ifelse FAMILY-LOCKDOWN? [
        ask my-house[
          foreach my-humans[
            [my-human] -> ask my-human [
              if lockdown? = 0 [
                lockdown
              ]
            ]
          ]
        ]
      ][
        if lockdown? = 0 [
          lockdown
        ]
      ]
    ]
    if equiped? and TRACING?[
        detect-contacts
      ]
  ]

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;BACKTRACKING;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to detect-contacts
  let me self
  let my-lockdown-date lockdown-date
  let j 0

  set tracers-this-tick tracers-this-tick + 1
  repeat length liste-contacts[
    let date-j item j liste-contact-dates
    let contacts-j item j liste-contacts

    if is-agentset? contacts-j[
      if date-j >= (my-lockdown-date - (nb-days-before-test-tagging-contacts * nb-step-per-day))[
        set contacts-to-warn-next (turtle-set contacts-to-warn-next (contacts-j with [detected? = false]))
      ]
    ]
    set j j + 1
  ]
end

to warn-contacts [order]
  ifelse TESTING?[
    ask contacts-to-warn with [detected? = false][
      set to-be-tested true
      set contact-order order
    ]
  ][
    ask contacts-to-warn with [lockdown? = 0][
      if random-float 1 < probability-respect-lockdown[
        set contact-order order
        lockdown
      ]
      detect-contacts
    ]
  ]


end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;STATE TRANSITION PROCEDURES;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to become-exposed
  set epidemic-state Ex
  set contagion-counter contagion-duration
  set infection-date ticks
  set current-nb-new-infections-reported (current-nb-new-infections-reported + 1)
  set nb-contagious-cumulated nb-contagious-cumulated + 1
  set color violet ;
  set resistant? (random-float 1 < probability-asymptomatic-infection)
  set contagious? true
end

to become-infected
  set epidemic-state I
  set color red ;
end

to become-asymptomatic-infected
  set epidemic-state Ia
  set color blue ;
end

to become-recovered
  set epidemic-state R
  set contagious? false
  set color yellow ;
end



;###############################
;REPORTERS
;###############################

to-report contagiousness [a-citizen]
  if ([epidemic-state] of a-citizen) = Ex [
    ifelse resistant? [
      report (((ticks - infection-date) / (incubation-duration * nb-step-per-day)) * probability-transmission-asymptomatic) ; linear growth from 0 at infection time to full asymptomatic transmission probability at the end of incubation time
    ][
      report (((ticks - infection-date) / (incubation-duration * nb-step-per-day)) * probability-transmission) ; linear growth from 0 at infection time to full symptomatic transmission probability at the end of incubation time
    ]
  ]

  if ([epidemic-state] of a-citizen) = I [
      report probability-transmission
  ]

  if ([epidemic-state] of a-citizen) = Ia [
      report probability-transmission-asymptomatic
  ]


end

to-report clean? [a-house]
  let local-clean true
  ask a-house[
    foreach my-humans[
      [my-human] -> ask my-human [
        if contagious?[
          set local-clean false
        ]
      ]
    ]
    set clean local-clean
  ]
  report [clean] of a-house
end

to-report nb-S
  report count citizens with [epidemic-state = S ]
end

to-report nb-Ir
  report count citizens with [epidemic-state = I ]
end

to-report nb-Ex
  report count citizens with [epidemic-state = Ex ]
end

to-report nb-Inr
  report count citizens with [epidemic-state = Ia ]
end

to-report nb-I
  report count citizens with [epidemic-state = I or epidemic-state = Ia ]
end

  to-report nb-R
  report count citizens with [epidemic-state = R]
end

to-report %nb-I-Total
  report (population-size - nb-S) / population-size * 100
end


to-report population-spared
report (nb-S) / population-size * 100
end


to-report %locked
  report (count citizens with [lockdown? = 1] / population-size) * 100
end

to-report nb-detected
  report count citizens with [detected?]
end

to-report nb-detected%
  report nb-detected / population-size * 100
end

to-report %detected
  report (count citizens with  [detected?] / population-size) * 100
end

to-report epidemic-duration
  report round (ticks / nb-step-per-day)

end

to-report MaxI%
 report max-I / population-size * 100
end

to-report Max-Conf%
  report max-conf /  size_population  * 100
end

to-report R0
  ;report mean [nb-other-infected] of citizens with [ epidemic-state != S] - To see in real time the nb of other citizens infected by people who wera affected by the infection
  ifelse nb-R > 0 [
    report mean [nb-other-infected] of citizens with [epidemic-state = R]
  ][
    report "N/A"
  ]
  ;To see once someone is cured in average how many people he infected. Converges towards 1 as time goes by as the population is finite:
  ;the sum of nb-other-infected is the population of infected, as in our model an infected has one and only one source
end

to-report family-locked-down
  report count citizens with [not detected? and lockdown? = 1]
end

to-report mean-contacts-ticks
  report mean [nb-contacts-ticks] of citizens
end

to-report mean-difference
  report mean [difference] of citizens
end

to-report symptom-detected
  report count citizens with [detected? and contact-order = 1]
end

to-report contact-detected
  report count citizens with [detected? and contact-order = 2]
end

to-report citizens-per-house
  report mean [length my-humans] of houses
end

to-report mean-contacts
  report mean list-mean-contacts
end

to-report mean-mean-daily-contacts-nb
  report mean mean-mean-daily-contacts
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;COUNTERS;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to update-max-I
  if nb-I > max-I [set max-I nb-I]
end

to update-max-conf
  let nb-conf count citizens with [lockdown? = 1]
  if nb-conf > max-conf [set max-conf nb-conf]
end

to update-list-mean-contacts
  set list-mean-contacts lput mean-contacts-ticks list-mean-contacts
end

to update-mean-daily-contacts
  if ((ticks mod 4) = 0)[
    set mean-daily-contacts mean [count daily-contacts] of citizens
  ]
end

to update-mean-mean-daily-contacts
  set mean-mean-daily-contacts lput mean-daily-contacts mean-mean-daily-contacts
end
@#$#@#$#@
GRAPHICS-WINDOW
3
6
621
825
-1
-1
10.0
1
10
1
1
1
0
0
0
1
-30
30
-40
40
1
1
1
ticks
30.0

BUTTON
217
827
306
868
Initialiser
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
307
827
396
868
Simuler
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
628
6
1401
263
EVOLUTION DE L'EPIDEMIE
Durée de l'épidémie
% de population
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Sains" 1.0 0 -13840069 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-S / population-size * 100)]"
"Exposés" 1.0 0 -6459832 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-Ex / population-size  * 100)]"
"I. Symptomatiques" 1.0 0 -2139308 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-Ir  / population-size * 100)]"
"I. Asymptomatiques" 1.0 0 -1184463 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-Inr  / population-size * 100)]"
"Contagieux" 1.0 0 -955883 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) ((nb-Ir + nb-Inr + nb-Ex) / population-size  * 100)]"
"Guéris" 1.0 0 -13791810 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-R / population-size  * 100)]"
"Confinés" 1.0 0 -8630108 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) %locked] "

MONITOR
897
360
1120
405
Population touchée par l'épidémie (%)
%nb-I-Total
1
1
11

CHOOSER
410
841
668
886
SCENARIO
SCENARIO
"Laisser faire" "Confinement simple" "Traçage et confinement systématique" "Traçage et confinement sélectif"
2

MONITOR
1123
360
1401
405
Durée de l'épidémie (en jours)
round (ticks / nb-step-per-day)
17
1
11

MONITOR
628
359
895
404
Pic épidémique (%)
MaxI%
2
1
11

SLIDER
404
905
674
938
Probabilité-que-le-test-soit-efficace
Probabilité-que-le-test-soit-efficace
0
1
0.7
0.1
1
NIL
HORIZONTAL

SLIDER
405
939
675
972
Probabilité-de-respect-du-confinement
Probabilité-de-respect-du-confinement
0
1
0.7
0.1
1
NIL
HORIZONTAL

SLIDER
3
939
403
972
Profondeur-temporelle-pour-l'identification-des-contacts
Profondeur-temporelle-pour-l'identification-des-contacts
1
5
1.0
1
1
jours
HORIZONTAL

SLIDER
3
869
403
902
Taux-de-couverture-de-l'application-de-traçage
Taux-de-couverture-de-l'application-de-traçage
0
100
0.0
10
1
%
HORIZONTAL

SLIDER
3
904
403
937
Temps-d'attente-pour-la-réalisation-du-test
Temps-d'attente-pour-la-réalisation-du-test
0
72
0.0
6
1
heures
HORIZONTAL

MONITOR
1123
408
1401
453
Nombre de tests réalisés
nb-detected
0
1
11

MONITOR
898
408
1121
453
Population testée (%)
%detected
2
1
11

MONITOR
1122
264
1400
309
Nombre d'infectés
nb-I
17
1
11

MONITOR
1123
312
1401
357
Nombre de guéris
nb-R
17
1
11

MONITOR
897
264
1120
309
Nombre d'exposés
nb-Ex
17
1
11

MONITOR
628
264
894
309
Nombre de sains
nb-S
17
1
11

MONITOR
629
730
1009
775
Nombre de personnes contagieuses confinées
nb-infected-identified-removed
0
1
11

MONITOR
1011
683
1401
728
Nombre de personnes contagieuses Identifiées
nb-infected-identified
2
1
11

PLOT
629
456
1401
680
EFFICACITE DU DISPOSITIF
Durée de l'épidémie
Nombre cumulé
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Contagieux (nombre total)" 1.0 0 -817084 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) nb-contagious-cumulated ]"
"Contagieux identifiés" 1.0 0 -13791810 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) nb-infected-identified]\n\n"
"Contagieux confinés" 1.0 0 -5825686 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) nb-infected-identified-removed]\n\n"
"Sains confinés" 1.0 0 -7500403 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) nb-non-infected-lockeddown]"
"Tests réalisés" 1.0 0 -2674135 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day)  nb-detected]"

MONITOR
629
683
1009
728
Nombre de personnes contagieuses (cumul)
nb-contagious-cumulated
17
1
11

MONITOR
1011
730
1401
775
Nombre de personnes non contagieuses confinées
nb-non-infected-lockeddown
17
1
11

MONITOR
628
407
895
452
Pic de confinement (%)
Max-Conf%
2
1
11

MONITOR
1012
778
1402
823
Nombre de personnes contagieuses identifiées suite aux symptômes
symptom-detected
17
1
11

MONITOR
629
778
1011
823
Nombre de personnes contagieuses identifiées grâce au traçage
contact-detected
17
1
11

SLIDER
3
829
175
862
R0-fixé
R0-fixé
0
10
1.0
1
1
NIL
HORIZONTAL

MONITOR
628
312
894
357
Nombre d'infectés symptomatiques
nb-Ir
17
1
11

MONITOR
897
312
1119
357
Nombre d'infectés asymptomatiques
nb-Inr
17
1
11

TEXTBOX
725
843
1368
976
EXPLICATIONS\n\nLa durée de la phase contagieuse est de 14 jours plus 4 jours d'incubation pendant laquelle la contagiosité croît linéairement jusqu'au début de la phase infectieuse.
14
65.0
1

@#$#@#$#@
## THINGS TO TRY

to be done 


## THINGS TO NOTICE

to be done


## AUTHOR

Developped by Arnaud Banos & Pierrick Tranouez for https://covprehension.org/
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

circle white
false
0
Circle -7500403 true true 0 0 300
Circle -1 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

sploch
true
0
Polygon -2674135 true false 60 105 45 60 90 75 120 15 150 90 240 45 240 90 285 165 210 225 210 165 180 195 165 255 135 240 135 180 45 225 120 120 30 135

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Explo_V9_Scenarios3-4" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>%nb-I-Total</metric>
    <metric>epidemic-duration</metric>
    <metric>Max-Conf%</metric>
    <metric>%detected</metric>
    <metric>nb-contagious-cumulated</metric>
    <metric>nb-infected-identified</metric>
    <metric>nb-infected-identified-removed</metric>
    <metric>nb-non-infected-lockeddown</metric>
    <metric>contact-detected</metric>
    <metric>symptom-detected</metric>
    <enumeratedValueSet variable="R0-fixé">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Taux-de-couverture-de-l'application-de-traçage" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="Temps-d'attente-pour-la-réalisation-du-test">
      <value value="0"/>
      <value value="6"/>
      <value value="12"/>
      <value value="24"/>
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Profondeur-temporelle-pour-l'identification-des-contacts">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-que-le-test-soit-efficace">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-de-respect-du-confinement">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Traçage et confinement systématique&quot;"/>
      <value value="&quot;Traçage et confinement sélectif&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V9_Scenario2" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>%nb-I-Total</metric>
    <metric>epidemic-duration</metric>
    <metric>Max-Conf%</metric>
    <metric>%detected</metric>
    <metric>nb-contagious-cumulated</metric>
    <metric>nb-infected-identified</metric>
    <metric>nb-infected-identified-removed</metric>
    <metric>nb-non-infected-lockeddown</metric>
    <metric>contact-detected</metric>
    <metric>symptom-detected</metric>
    <enumeratedValueSet variable="R0-fixé">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Temps-d'attente-pour-la-réalisation-du-test">
      <value value="0"/>
      <value value="6"/>
      <value value="12"/>
      <value value="24"/>
      <value value="48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-que-le-test-soit-efficace">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-de-respect-du-confinement">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Confinement simple&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V9_Scenario1" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>%nb-I-Total</metric>
    <metric>epidemic-duration</metric>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Laisser faire&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

link-arn
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Polygon -7500403 true true 150 150 105 210 195 210
@#$#@#$#@
0
@#$#@#$#@
