globals [ ;;global parameters
  population-size
  nb-house
 ; transmission-distance ==> SUPPRIMER POUR ACCELERATION CODE DANS get-in-contact AVEC PRIMITIVE NEIGHBORS
  probability-asymptomatic-infection
  probability-transmission
  probability-transmission-asymptomatic
  walking-angle
  speed
  current-nb-new-infections-reported
  current-nb-new-infections-asymptomatic
  transparency
  contagion-duration
  nb-step-per-day
  lockdown-date
  previous-lockdown-state
  lock-down-color
  nb-lockdown-episodes
  max-I
  list-colors-contacts
  ;epidemic symbolic constants
  S ; Susceptible
  Ex ; Exposed - Infected and incubating, but already contagious.
  Ia ; Infected asymptomatic
  I ; Infected symptomatic
  R ; Recovered
]

patches-own [wall]

breed [citizens citizen]
breed [houses house]

citizens-own
[
  epidemic-state;FA: S, Ex, Ia, I or R
  infection-date
  infection-source
  nb-other-infected
  contagion-counter ;;counter to go from state 1 or 2 (infected) to state 3 recovered
  contagious? ; boolean
  resistant? ; boolean - indicates in case of infection wether the citizen will express symptoms
  my-house
  lockdown ; 0 free 1 locked
  nb-step-confinement
  liste-contacts
  liste-contact-dates
  equiped?
  tested? ;0 no 1 yes
  list-date-test
  contact-order ;0 not contacted, 1 contacted at first order, 2 contacted at second order
]

to setup-globals
  ;symbolic constants
  set S 0
  set Ex 1
  set Ia 2
  set I 3
  set R 4


  set population-size Taille_population
  set nb-house (population-size / 2)

 ; set transmission-distance 1 ACCELERATION CODE DANS get-in-contact AVEC PRIMITIVE NEIGHBORS
  set probability-asymptomatic-infection 0.3
  set probability-transmission 0.15
  set probability-transmission-asymptomatic 0.07
  ;set incubation-period 5 * nb-step-per-day
  set walking-angle 50
  set speed 0.5
  set transparency 145
  set nb-step-per-day 4
  set contagion-duration (incubation-duration + (14 * nb-step-per-day))
  set list-colors-contacts [white 125]
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
  ]
end

to setup-population
  create-citizens population-size
  [
    move-to one-of patches with [wall = 0]
    fd random-float 0.5
    set shape "circle"
    set size 1
    set color green ; lput transparency extract-rgb  green
    set epidemic-state S
    set my-house one-of houses
    set liste-contacts []
    set liste-contact-dates []
    set list-date-test []
    set equiped? false
    set tested? false
    set contagious? false
    set resistant? false ; resistance is really "defined" when the citizen is Exposed to the virus
  ]
  set-infected-initialisation
  set-equiped-initialisation
end

to set-equiped-initialisation
  ifelse SCENARIO = "Laisser faire" [set Proportion-equiped 0]
  [ask n-of (round (population-size * (Proportion-equiped / 100))) citizens
  [set equiped? true]
  ]
end


to set-infected-initialisation
  ask n-of Nb_infected_initialisation citizens [
    become-exposed
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

to go
  if not any? citizens with [contagious? ] [stop] ;send-user-message
  move-citizens
  get-in-contact
  get-tested
  update-epidemics
  update-max-I
  ;wait 0.1

  tick
end

;;MOVEMENT PROCEDURES
to move-citizens
  ask citizens[
    if equiped? and lockdown = 1
    [
      ifelse nb-step-confinement = 0
      [move-to my-house]
      [set nb-step-confinement (nb-step-confinement + 1)]
    ]
      avoid-walls
      fd speed
   ]
end

to avoid-walls
  ifelse  any? neighbors with [wall = 1]
    [ face one-of neighbors with [wall = 0] ]
  [set heading heading + random walking-angle - random walking-angle
      ]
end

;;EPIDEMICS PROCEDURE
to update-epidemics
  ;;update the counters for the infected at this timestep
  set current-nb-new-infections-reported 0
  set  current-nb-new-infections-asymptomatic 0
  ;;update recovered
  ask citizens with [contagious?]
  [  ;show  contagion-counter
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
  ;;spread virus
;  ask citizens with [epidemic-state = S][
;    get-virus
;  ]
end


to get-in-contact
  ask citizens
  [
    ;ACCELERATION CODE AVEC PRIMITIVE NEIGHBORS
    let contacts other citizens-on neighbors
    set contacts contacts with [lockdown = 0]
    if equiped? [
      let contacts-equiped contacts with [equiped?]
      set liste-contacts lput contacts-equiped liste-contacts
      set liste-contact-dates lput ticks liste-contact-dates
    ]
    let infection-contact one-of contacts with [contagious?]
    if epidemic-state = S and is-agent? infection-contact [
      get-virus infection-contact
    ]
  ]
end




to get-virus [contact-source]
  if ( ([contagious?] of contact-source)  and (random-float 1 < (contagiousness contact-source)) ) [
    become-exposed
    set infection-source contact-source
    ask contact-source [set nb-other-infected nb-other-infected + 1]
  ]
end


;;BACKTRACKING
to get-tested
  ask citizens with
  [
    epidemic-state = I
    and
    equiped?
    and
    not tested?
    and
    (ticks - infection-date) >= (incubation-duration * nb-step-per-day + delay-before-test)
  ]
  [
    show ["tested"]
    set tested? true
    set list-date-test lput ticks list-date-test
    if random-float 1 < probability-success-test-infected [
      show ["lockdowned"]
      set lockdown 1
      set lockdown-date ticks
      set contact-order 1
      backtrack-contacts 2
    ]
  ]
end

to backtrack-contacts [order]

 ; probability-respect-lockdown-when-tagged
  let me self
  let my-lockdown-date lockdown-date
  let j 0

  repeat length liste-contacts[
      let date-j item j liste-contact-dates
      let contacts-j item j liste-contacts

      if is-agentset? contacts-j[
        if date-j >= (my-lockdown-date - (nb-days-before-test-tagging-contacts * nb-step-per-day))[
          ask contacts-j with [lockdown = 0 and contact-order = 0][
            ;;ICI STRATEGIE DE DEPISTAGE SYSTEMATIQUE DE TOUS LES CONTACTS
            if Confinement_avec_Test?[
              ;On vérifie qu'on ne teste pas deux fois le même jour
              if not member? ticks  list-date-test[
                set tested? true
                set list-date-test lput ticks list-date-test
              ]
              if contagious?[
                if random-float 1 < probability-success-test-infected[
                  if random-float 1 < probability-respect-lockdown-when-tagged[
                    set lockdown 1
                    set lockdown-date ticks
                  ]
                  set contact-order order
                  if montre-liens?[
                    create-link-from me [set shape "link-arn" set color item (order - 2) list-colors-contacts]
                  ]
                  if ((SCENARIO = "Rétro traçage2 + confinement des contacts2") and (order = 2)) [
                    backtrack-contacts 3
                  ]
                ]
              ]
            ]

            if not Confinement_avec_Test?[
              if random-float 1 < probability-respect-lockdown-when-tagged[
                set lockdown 1
                set lockdown-date ticks
              ]
              set contact-order order
              if montre-liens?[
                  create-link-from me [set shape "link-arn" set color item (order - 2) list-colors-contacts  ]
              ]
              if ((SCENARIO = "Rétro traçage2 + confinement des contacts2") and (order = 2))[
                  backtrack-contacts 3
              ]
            ]
          ]
      ]
      set j j + 1
    ]
  ]

end


to connect-contacts-foreach
  ask citizens with [not empty? liste-contact-dates]
  [
    let me self
  foreach liste-contacts
  [
    [the-turtle] -> ask the-turtle [ create-link-with me ]
    ]
  ]

end

;;CITIZEN PROCEDURES
to-report contagiousness [a-citizen]
  if ([epidemic-state] of a-citizen) = Ex [
    ifelse resistant? [
      report (((ticks - infection-date) / (incubation-duration * nb-step-per-day)) * probability-transmission-asymptomatic) ; linear growth from 0 at infection time to full asymptomatic transmission probability at the end of incubation time
    ][
      report (((ticks - infection-date) / (incubation-duration * nb-step-per-day)) * probability-transmission)
    ]
  ]

  if ([epidemic-state] of a-citizen) = I [
      report probability-transmission
  ]

  if ([epidemic-state] of a-citizen) = Ia [
      report probability-transmission-asymptomatic
  ]


end

;;STATE TRANSITION PROCEDURES
to become-exposed
  set epidemic-state Ex
  set contagion-counter contagion-duration
  set infection-date ticks
  set current-nb-new-infections-reported (current-nb-new-infections-reported + 1)
  set color violet ; lput transparency extract-rgb red
  set resistant? (random-float 1 < probability-asymptomatic-infection)
  set contagious? true
  ;show ["exposed"]
end

to become-infected
  set epidemic-state I
  ;set contagion-counter contagion-duration
  ;set infection-date ticks
  ;set current-nb-new-infections-reported (current-nb-new-infections-reported + 1)
  set color red ; lput transparency extract-rgb red
end

to become-asymptomatic-infected
  set epidemic-state Ia
  set color blue ; lput transparency extract-rgb blue
  ;set contagion-counter contagion-duration
  ;set infection-date ticks
  ;set current-nb-new-infections-reported (current-nb-new-infections-reported + 1)
end

to become-recovered
  set epidemic-state R
  set contagious? false
  set color yellow ; lput transparency extract-rgb gray
end

;###############################
;REPORTERS
;###############################

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


; % Population touchée par l'épidémie
to-report %nb-I-Total
  report (population-size - nb-S) / population-size * 100
end


to-report population-spared
report (nb-S) / population-size * 100
end


to-report %locked
  report (count citizens with [lockdown = 1] / population-size) * 100
end

to-report nb-tests
  report count citizens with [tested?]
end

to-report %tested
  report (count citizens with  [tested?] / population-size) * 100
end

to-report epidemic-duration
  report round (ticks / nb-step-per-day)

end

to-report MaxI%
 report max-I / population-size * 100
end

to-report H0
  ;report mean [nb-other-infected] of citizens with [ epidemic-state != S] - To see in real time the nb of other citizens infected by people who wera affected by the infection
  report mean [nb-other-infected] of citizens with [ epidemic-state = R]
  ;To see once someone is cured in average how many people he infected. Converges towards 1 as time goes by as the population is finite:
  ;the sum of nb-other-infected is the population of infected, as in our model an infected has one and only one source
end



;==============

;TECHNICAL ADDS

;===============

to fix-seed
 random-seed 47822
end

;to send-user-message
;  ifelse population-spared > 75 and nb-lockdown-episodes = 1
;  [user-message (word "Bravo ! Vous avez réussi a protéger " round population-spared " % de votre population en imposant un confinement total de " round (nb-day-confinement) " jours. Espérons juste que personne n'est mort de faim...")]
;
;  [ifelse nb-day-confinement = 0
;    [user-message (word "Bravo ! Tout le monde a été touché par le virus et les hôpitaux ont explosé, mais au moins personne n'a été empêché de sortir. Espérons juste que tout le monde est encore vivant...")]
;    [ifelse nb-lockdown-episodes = 1
;      [user-message (word "Bravo ! Vous avez réussi a protéger " round population-spared " % de votre population en imposant un confinement total de " round (nb-day-confinement) " jours et en limitant le pic épidémique à " round(max-I / population-size * 100)"%. C'est votre dernier mot ?")]
;      [user-message (word "Bravo ! Vous avez réussi a protéger " round population-spared " % de votre population en imposant un confinement total de " round (nb-day-confinement) " jours et en limitant le pic épidémique à " round(max-I / population-size * 100)"%. Vous avez mis en phase plusieurs périodes de confinement. Si votre objectif était de faire en sorte que le nombre d'infectés ne dépasse pas une valeur seuil, alors vous avez exploré une stratégie actuellement étudiée par plusieurs équipes scientifiques !")]
;]
;
;    ]
;
;end

to update-max-I
  if nb-I > max-I [set max-I nb-I]
end
@#$#@#$#@
GRAPHICS-WINDOW
2
10
591
409
-1
-1
9.525
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
-20
20
1
1
1
ticks
30.0

BUTTON
405
414
493
469
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
494
414
582
469
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
593
10
1013
266
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
"S" 1.0 0 -13840069 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-S / population-size * 100)]"
"Ir" 1.0 0 -2674135 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-Ir  / population-size * 100)]"
"Inr" 1.0 0 -13345367 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-Inr  / population-size * 100)]\n"
"I" 1.0 0 -955883 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) ((nb-Ir + nb-Inr) / population-size  * 100)]"
"R" 1.0 0 -7500403 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-R / population-size  * 100)]"
"Ex" 1.0 0 -8630108 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-Ex / population-size  * 100)]"

TEXTBOX
23
418
201
568
Mode d'emploi à ajouter ici\n\nCréer indicateurs de sortie behaviour space
12
105.0
1

SWITCH
695
470
904
503
Confinement_avec_Test?
Confinement_avec_Test?
0
1
-1000

MONITOR
786
269
1013
314
Population touchée par l'épidémie (%)
%nb-I-Total
1
1
11

CHOOSER
640
414
954
459
SCENARIO
SCENARIO
"Laisser faire" "Rétro traçage + confinement des contacts" "Rétro traçage2 + confinement des contacts2"
2

TEXTBOX
1020
11
1344
32
La période de contagion est fixée à 14 jours
14
25.0
1

MONITOR
593
317
784
362
Durée de l'épidémie (en jours)
round (ticks / nb-step-per-day)
17
1
11

MONITOR
593
269
783
314
Pic épidémique (Max I)
MaxI%
2
1
11

SWITCH
405
473
547
506
Montre-liens?
Montre-liens?
1
1
-1000

BUTTON
405
508
507
541
Cache liens
ask links [die]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1016
223
1279
256
probability-success-test-infected
probability-success-test-infected
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1016
185
1298
218
probability-respect-lockdown-when-tagged
probability-respect-lockdown-when-tagged
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1015
109
1293
142
nb-days-before-test-tagging-contacts
nb-days-before-test-tagging-contacts
1
5
3.0
1
1
days
HORIZONTAL

MONITOR
786
317
1013
362
Population confinée (%)
%locked
2
1
11

SLIDER
1016
147
1194
180
proportion-equiped
proportion-equiped
0
100
100.0
10
1
NIL
HORIZONTAL

SLIDER
1015
71
1210
104
incubation-duration
incubation-duration
0
5
5.0
1
1
days
HORIZONTAL

SLIDER
1014
35
1217
68
delay-before-test
delay-before-test
0
72
0.0
6
1
hours
HORIZONTAL

MONITOR
1115
269
1179
314
#ordre2
count citizens with [contact-order = 2]
17
1
11

MONITOR
1050
269
1114
314
#ordre1
count citizens with [contact-order = 1]
17
1
11

MONITOR
1180
269
1244
314
#ordre3
count citizens with [contact-order = 3]
17
1
11

MONITOR
787
364
1013
409
Nombre de tests réalisés
nb-tests
0
1
11

SLIDER
220
423
392
456
Taille_population
Taille_population
0
10000
5000.0
1000
1
NIL
HORIZONTAL

MONITOR
593
364
785
409
Population testée (%)
%tested
17
1
11

SLIDER
220
460
392
493
Nb_infected_initialisation
Nb_infected_initialisation
1
50
1.0
1
1
NIL
HORIZONTAL

MONITOR
1144
368
1201
413
H0
H0
17
1
11

MONITOR
1297
271
1354
316
NIL
nb-I
17
1
11

MONITOR
1412
271
1469
316
NIL
nb-R
17
1
11

MONITOR
1355
271
1412
316
NIL
nb-Ex
17
1
11

MONITOR
1507
270
1564
315
NIL
nb-S
17
1
11

PLOT
1448
101
1648
251
H0 evolution
Durée de l'épidémie
H0
0.0
70.0
0.0
10.0
true
false
"" ""
PENS
"H0" 1.0 0 -16777216 true "" "if (H0  > 0) [plotxy (ticks / nb-step-per-day) (H0)]"

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
  <experiment name="Test_V2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>nb-I = 0</exitCondition>
    <metric>MaxI%</metric>
    <metric>epidemic-duration</metric>
    <metric>%tested</metric>
    <metric>nb-tests</metric>
    <metric>%locked</metric>
    <metric>%nb-I-Total</metric>
    <enumeratedValueSet variable="Confinement_avec_Test?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="delay-before-test">
      <value value="6"/>
      <value value="12"/>
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Nb_infected_initialisation">
      <value value="1"/>
      <value value="10"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Rétro traçage + confinement des contacts&quot;"/>
      <value value="&quot;Rétro traçage2 + confinement des contacts2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-days-before-test-tagging-contacts">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-equiped">
      <value value="10"/>
      <value value="40"/>
      <value value="70"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Nb_infected_initialisation">
      <value value="1"/>
      <value value="10"/>
      <value value="50"/>
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
