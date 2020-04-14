globals [ ;;global parameters
  population-size
  nb-house
  nb-infected-initialisation
  transmission-distance
  probability-asymptomatic-infection
  probability-transmission
  probability-transmission-unreported-infected
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
]

patches-own [wall]

breed [citizens citizen]
breed [houses house]

citizens-own
[
  epidemic-state;FA: 0 Susceptible 1 Infected 2 Asymptomatic Infected 3 Recovered
  infection-date
  infection-source
  nb-other-infected
  contagion-counter ;;counter to go from state 1 or 2 (infected) to state 3 recovered
  my-house
  lockdown ; 0 free 1 locked
  nb-step-confinement
  liste-contacts
  liste-contact-dates
  equiped?
  get-tested? ;0 no 1 yes
  list-date-test
  contact-order ;0 not contacted, 1 contacted at first order, 2 contacted at second order
]

to setup-globals
  set population-size Taille_population
  set nb-house (population-size / 2)
  set nb-infected-initialisation 1
  set transmission-distance 1
  set probability-asymptomatic-infection 0.3
  set probability-transmission 0.15
  set probability-transmission-unreported-infected 0.07
  set walking-angle 50
  set speed 0.5
  set transparency 145
  set nb-step-per-day 4
  set contagion-duration 14 * nb-step-per-day
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
    set epidemic-state 0
    set my-house one-of houses
    set liste-contacts []
    set liste-contact-dates []
    set list-date-test []
  ]
  set-infected-initialisation
  set-equiped-initialisation
end

to set-equiped-initialisation
  ifelse SCENARIO = "Laisser faire" [set Proportion-equiped 0]
  [ask n-of (round (population-size * (Proportion-equiped / 100))) citizens
  [set equiped? 1]
  ]
end


to set-infected-initialisation
  ask n-of nb-infected-initialisation citizens [
    become-infected
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
  if not any? citizens with [epidemic-state = 1 or epidemic-state = 2 ] [ stop] ;send-user-message
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
    if equiped? = 1 and lockdown = 1
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
  ask citizens with [epidemic-state = 1 or epidemic-state = 2]
  [
    set contagion-counter (contagion-counter - 1)
    if contagion-counter <= 0 [ become-recovered ]
  ]
  ;;spread virus
;  ask citizens with [epidemic-state = 0][
;    get-virus
;  ]
end


to get-in-contact
  ask citizens
  [
    let contacts other citizens with [lockdown = 0] in-radius transmission-distance
    if equiped? = 1
    [
      let contacts-equiped contacts with [equiped? = 1]
      set liste-contacts lput contacts-equiped liste-contacts
      set liste-contact-dates lput ticks liste-contact-dates]
  let infection-contact one-of contacts with [epidemic-state = 1 or epidemic-state = 2]
  if epidemic-state = 0 and is-agent? infection-contact
  [get-virus infection-contact]
  ]
end




to get-virus [contact-source]
  if ([epidemic-state] of contact-source = 1  and random-float 1 < probability-transmission)
  or
  ([epidemic-state] of contact-source = 2 and random-float 1 < probability-transmission-unreported-infected)
  [
    ifelse random-float 1 < probability-asymptomatic-infection [become-asymptotic-infected] [become-infected]
    set infection-source contact-source
        ask contact-source [set nb-other-infected nb-other-infected + 1]
    ]
end


to get-tested
  ask citizens with
  [
    epidemic-state = 1
    and
    equiped? = 1
    and
    get-tested?  = 0
    and
    (ticks - infection-date) = (incubation-period * 4 + delay-before-test)
  ]
  [
    set get-tested?  get-tested? + 1
        set list-date-test lput ticks list-date-test
  if random-float 1 < probability-success-test-infected
  [set lockdown 1
      set lockdown-date ticks
      set contact-order 1
  backtrack-contacts 2]
  ]
end

to backtrack-contacts [order]

 ; probability-respect-lockdown-when-tagged
  let me self
  let my-lockdown-date lockdown-date
  let i 0
  repeat length liste-contacts
  [
      let date-i item i liste-contact-dates
      let contacts-i item i liste-contacts
      if is-agentset? contacts-i
      [
      if date-i >= (my-lockdown-date - (nb-days-before-test-tagging-contacts * nb-step-per-day))
        [
          ask contacts-i with [lockdown = 0 and contact-order = 0]
          [
            ;;ICI STRATEGIE DE DEPISTAGE SYSTEMATIQUE DE TOUS LES CONTACTS
            if Confinement_avec_Test?
            [
              ;On vérifie qu'on ne teste pas deux fois le même jour
              if not member? ticks  list-date-test
              [set get-tested?  get-tested? + 1
                set list-date-test lput ticks list-date-test]
              if epidemic-state = 1 or epidemic-state = 2
              [

              if random-float 1 < probability-success-test-infected
              [

                if random-float 1 < probability-respect-lockdown-when-tagged
                [set lockdown 1
                  set lockdown-date ticks]
                set contact-order order
                if montre-liens? [create-link-from me [set shape "link-arn" set color item (order - 2) list-colors-contacts  ]]
                if SCENARIO = "Rétro traçage2 + confinement des contacts2" [backtrack-contacts 3]
            ]
            ]
            ]

            if not Confinement_avec_Test?
            [
              if random-float 1 < probability-respect-lockdown-when-tagged
            [set lockdown 1
                set lockdown-date ticks]
            set contact-order order
            if montre-liens? [create-link-from me [set shape "link-arn" set color item (order - 2) list-colors-contacts  ]]
            if SCENARIO = "Rétro traçage2 + confinement des contacts2" [backtrack-contacts 3]
            ]
          ]


    ]
      set i i + 1
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

;;STATE TRANSITION PROCEDURES
to become-infected
  set epidemic-state 1
  set contagion-counter contagion-duration
  set infection-date ticks
  set current-nb-new-infections-reported (current-nb-new-infections-reported + 1)
  set color red ; lput transparency extract-rgb red
end

to become-asymptotic-infected
  set epidemic-state 2
  set color blue ; lput transparency extract-rgb blue
  set contagion-counter contagion-duration
  set infection-date ticks
  set current-nb-new-infections-reported (current-nb-new-infections-reported + 1)
end

to become-recovered
  set epidemic-state 3
  set color yellow ; lput transparency extract-rgb gray
end

;###############################
;REPORTERS
;###############################

to-report nb-S
  report count citizens with [epidemic-state = 0 ]
end

to-report nb-Ir
  report count citizens with [epidemic-state = 1 ]
end

to-report nb-Inr
  report count citizens with [epidemic-state = 2 ]
end

to-report nb-I
  report count citizens with [epidemic-state = 1 or epidemic-state = 2 ]
end

to-report nb-I-Total
  report (nb-I + nb-R) / population-size * 100
end

to-report nb-R
  report count citizens with [epidemic-state = 3 ]
end

to-report nb-Day-Confinement
  ;report nb-step-confinement / nb-step-per-day
end

to-report population-hit
report (nb-I + nb-R) / population-size * 100
end

to-report population-spared
report (nb-S) / population-size * 100
end
;==============

;TECHNICAL ADDS

;===============

to fix-seed
 random-seed 47822
end

to send-user-message
  ifelse population-spared > 75 and nb-lockdown-episodes = 1
  [user-message (word "Bravo ! Vous avez réussi a protéger " round population-spared " % de votre population en imposant un confinement total de " round (nb-day-confinement) " jours. Espérons juste que personne n'est mort de faim...")]

  [ifelse nb-day-confinement = 0
    [user-message (word "Bravo ! Tout le monde a été touché par le virus et les hôpitaux ont explosé, mais au moins personne n'a été empêché de sortir. Espérons juste que tout le monde est encore vivant...")]
    [ifelse nb-lockdown-episodes = 1
      [user-message (word "Bravo ! Vous avez réussi a protéger " round population-spared " % de votre population en imposant un confinement total de " round (nb-day-confinement) " jours et en limitant le pic épidémique à " round(max-I / population-size * 100)"%. C'est votre dernier mot ?")]
      [user-message (word "Bravo ! Vous avez réussi a protéger " round population-spared " % de votre population en imposant un confinement total de " round (nb-day-confinement) " jours et en limitant le pic épidémique à " round(max-I / population-size * 100)"%. Vous avez mis en phase plusieurs périodes de confinement. Si votre objectif était de faire en sorte que le nombre d'infectés ne dépasse pas une valeur seuil, alors vous avez exploré une stratégie actuellement étudiée par plusieurs équipes scientifiques !")]
]

    ]

end

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
592
10
1012
284
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
"Inr" 1.0 0 -1184463 true "" "if population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-Inr  / population-size * 100)]\n"
"I" 1.0 0 -955883 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) ((nb-Ir + nb-Inr) / population-size  * 100)]"
"R" 1.0 0 -7500403 true "" "\nif population-size > 0 [plotxy (ticks / nb-step-per-day) (nb-R / population-size  * 100)]"

TEXTBOX
23
418
201
568
Mode d'emploi à ajouter ici
12
105.0
1

SWITCH
703
451
912
484
Confinement_avec_Test?
Confinement_avec_Test?
0
1
-1000

MONITOR
805
289
1015
334
Proportion de population infectée (%)
(population-size - nb-s) / population-size * 100
1
1
11

MONITOR
594
289
804
334
Nombre de jours de confinement
round (nb-day-confinement)
17
1
11

CHOOSER
644
386
958
431
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
806
337
1016
382
Durée de l'épidémie (en jours)
round (ticks / nb-step-per-day)
17
1
11

MONITOR
594
337
805
382
Pic épidémique (Max I)
max-I / population-size * 100
2
1
11

MONITOR
1023
289
1096
334
# Infectés
(population-size - nb-s)
17
1
11

SWITCH
405
473
547
506
Montre-liens?
Montre-liens?
0
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
0
5
1.0
1
1
days
HORIZONTAL

MONITOR
1103
289
1180
334
#Confinés
count citizens with [lockdown = 1]
17
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
1197
104
incubation-period
incubation-period
0
5
3.0
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
6.0
6
1
hours
HORIZONTAL

MONITOR
1187
289
1257
334
#Equipés
count citizens with [equiped? = 1]
17
1
11

MONITOR
1024
336
1152
381
#Confinés équipés
count citizens with [equiped? = 1 and lockdown = 1]
17
1
11

MONITOR
1088
462
1152
507
#ordre2
count citizens with [contact-order = 2]
17
1
11

MONITOR
1023
462
1087
507
#ordre1
count citizens with [contact-order = 1]
17
1
11

MONITOR
1153
462
1217
507
#ordre3
count citizens with [contact-order = 3]
17
1
11

MONITOR
1155
336
1257
381
#Tests réalisés
sum  [get-tested?] of citizens
17
1
11

MONITOR
1024
384
1093
429
#S testés
count citizens with [epidemic-state = 0 and get-tested? =  1]
17
1
11

SLIDER
220
423
392
456
Taille_population
Taille_population
100
2000
500.0
100
1
NIL
HORIZONTAL

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