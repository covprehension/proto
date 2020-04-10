globals [ ;;global parameters
  ;;population
  population-size
  nb-house

  ;;epidemics
  nb-infected-initialisation ;; nb d'infectés asympatomatic au départ
  transmission-distance
  probability-transmission
  current-nb-new-infections-reported
  recovered-duration
  asymptomatic-duration
  nb-step-confinement
  nb-step-per-day
  frequence-sortie-confinés
  distance-from-home-pour-confinés
  frequence-sortie-infectés
  distance-from-home-pour-infectés
  probability-transmission-at-home

  ;;movement
  walking-angle
  speed

  ;;pour gérer le décalage entre jours et nb d'itérations et faire en sorte que les jouors soient affichés sur les graphiques
  nbsteps

  ;;pour gérer arrêt de simulation
  oldNbSusceptibles
  oldNbRecovered

  ;;couleurs
  color-susceptible
  color-incubating
  color-infected
  color-hospitalized
  color-recovered
  color-houses
]

breed [citizens citizen]
breed [houses house]

citizens-own
[
  epidemic-state;FA: 0 Susceptible 1 Infected Asymptomatic 2 Infected symptomatic 3 Recovered
  infection-date
  recovered-counter ;;counter to go from state 2  to state 3 recovered
  asymptomatic-counter ;;counter to go from state 1  to state 2 symptomatic
  my-house
  confined?
  at-home?
]

to setup-globals
  set population-size 500
  set nb-house population-size / 2
  set nb-infected-initialisation 1 ;;nb d'asymptomatic au départ
  set transmission-distance 1
  set probability-transmission 0.2
  set probability-transmission-at-home probability-transmission / 2
  set walking-angle 50
  set speed 0.5
  set nb-step-per-day 4
  set recovered-duration 14 * nb-step-per-day
  set asymptomatic-duration 8 * nb-step-per-day
  set nbsteps 0
  set oldNbSusceptibles population-size
  set oldNbRecovered 0
  setup-colors
end

to setup-colors
  set color-susceptible [223 194 125] ; beige
  set color-incubating [166 97 26] ; marron
  set color-infected [0 0 0] ; noir
  set color-hospitalized [1 133 113] ; turquoise foncé
  set color-recovered [128 205 193] ; turquoise clair
  set color-houses  [175 141 195] ;violet
  ask patches [set pcolor white]
end

to setup-houses
  create-houses nb-house[
    set shape "house"
    setxy random-xcor random-ycor
    set size 2
    set color color-houses
  ]
end

to setup-population
  create-citizens population-size
  [
    setxy random-xcor random-ycor
    set shape "circle"
    set size 1
    set color color-susceptible
    set epidemic-state 0
    set my-house one-of houses
    set confined? false
    set at-home? false
  ]
  set-infected-initialisation
end

to set-infected-initialisation
  ask n-of nb-infected-initialisation citizens [
    become-infected-asymptomatic
  ]
end

to setup
  clear-all
  reset-ticks
  setup-globals
  setup-houses
  setup-population
end

to go
  update-confined
  move-citizens
  update-epidemics
  wait 0.1
  set nbsteps nbsteps + 1
  ;;update des ticks et gestion de l'arrêt de simulation
  if (nbsteps mod nb-step-per-day = 0)[
    tick
    if (ticks mod 10 = 9)[
      ifelse(oldNbSusceptibles = count citizens with [epidemic-state = 0] and oldNbRecovered = count citizens with [epidemic-state = 3])[
        stop]
      [ set oldNbSusceptibles count citizens with [epidemic-state = 0]
        set oldNbRecovered count citizens with [epidemic-state = 3]]
  ]]
end

to checkStop
    ifelse(oldNbSusceptibles = count citizens with [epidemic-state = 0] and oldNbRecovered = count citizens with [epidemic-state = 3])[
    stop]
  [  set oldNbSusceptibles count citizens with [epidemic-state = 0]
   set oldNbRecovered count citizens with [epidemic-state = 3]]
end

to update-confined
  if pourcentage-confinés > 0 [
    set confiner-infectés-symptomatiques? true

  ifelse scenario-confinement = "Très Strict" [
  set frequence-sortie-confinés 0.05
  set distance-from-home-pour-confinés 0.5][
  ifelse scenario-confinement = "Strict" [
      set frequence-sortie-confinés 0.1
  set distance-from-home-pour-confinés 1.0
    ][;;scenario souple
      set frequence-sortie-confinés 0.25
  set distance-from-home-pour-confinés 2.0
    ]
  ]

  set frequence-sortie-infectés 0.05
  set distance-from-home-pour-infectés 0.5


  ;;on se base sur who pour que ceux qui sortent soient toujours les mêmes
  ;;les nb-house sont crées en premiers
  ;;les citizens sont numerotés de nb-house à nb-house + population-size - 1
  let threshold-who (nb-house + pourcentage-confinés * population-size / 100)
  ask citizens[ifelse who > threshold-who  [
    set confined? false
    set at-home? false ]
    [set confined? true
      set at-home? true]]
  ]
  if (confiner-infectés-symptomatiques?) [ask citizens with [epidemic-state = 2] [
    set confined? true
    set at-home? true]]
end

;;MOVEMENT PROCEDURES
to move-citizens
  ask citizens[
    ifelse confined? [
      ;confined
      move-to my-house
      set at-home? true

      ifelse epidemic-state = 2 [
        ;;infectés symptomatic sortent un peu
      if random-float 1 < (frequence-sortie-infectés * nb-step-per-day) [
        ;je sors
        set at-home? false
        set heading heading + random walking-angle - random walking-angle
      avoid-walls
      fd distance-from-home-pour-infectés
      ]][
          ;;non infectés suivent scénario
      if random-float 1 < (frequence-sortie-confinés * nb-step-per-day) [
        ;je sors
        set at-home? false
        set heading heading + random walking-angle - random walking-angle
      avoid-walls
      fd distance-from-home-pour-confinés
      ]
    ]]
    [
     ;not confined
      set at-home? false
      set heading heading + random walking-angle - random walking-angle
      avoid-walls
      fd speed
    ]
  ]
end

to avoid-walls
  if abs [pxcor] of patch-ahead (1) >= max-pxcor
    [ set heading (- heading) ]
  if abs [pycor] of patch-ahead 1 = max-pycor
    [ set heading (180 - heading) ]
end

;;EPIDEMICS PROCEDURE
to update-epidemics
  ;;update the counters for the infected at this timestep
  set current-nb-new-infections-reported 0
  ;;update asymptomatic
  ask citizens with [epidemic-state = 1][
    set asymptomatic-counter (asymptomatic-counter - 1)
    if asymptomatic-counter <= 0 [ become-infected-symptomatic ]
  ]
  ;;update recovered
  ask citizens with [epidemic-state = 2][
    set recovered-counter (recovered-counter - 1)
    if recovered-counter <= 0 [ become-recovered ]
  ]
  ;;spread virus
  ask citizens with [epidemic-state = 0][
    get-virus
  ]
end

to get-virus
 ifelse not at-home?[;;il ne peut être contaminé que par des indivs infectés qui ne sont pas chez eux
  let target one-of other citizens in-radius transmission-distance with [(epidemic-state = 1 or epidemic-state = 2) and not at-home?]
  if is-agent? target[
      if (([epidemic-state] of target = 1 or [epidemic-state] of target = 2) and random-float 1 < probability-transmission)
      [become-infected-asymptomatic]
  ]][ ;; sinon il ne peuvent être contaminés que par des indivs qui sont contaminés et chez eux
    let target one-of other citizens with [my-house = [my-house] of myself and at-home?]
  if is-agent? target[
      if (([epidemic-state] of target = 1 or [epidemic-state] of target = 2) and random-float 1 < probability-transmission-at-home)
      [ become-infected-asymptomatic]
    ]]
end

;;STATE TRANSITION PROCEDURES
to become-infected-asymptomatic
  set epidemic-state 1
  set asymptomatic-counter asymptomatic-duration
  set infection-date ticks
  set color color-incubating
end

to become-infected-symptomatic
  set epidemic-state 2
  set recovered-counter recovered-duration
  set current-nb-new-infections-reported (current-nb-new-infections-reported + 1)
  set color color-infected
end

to become-recovered
  set epidemic-state 3
  set color color-recovered
  if confiner-infectés-symptomatiques? [
    set confined? false
    set at-home? false]
end

;###############################
;REPORTERS
;###############################

to-report nb-S
  report count citizens with [epidemic-state = 0 ]
end

to-report nb-IA ;asymptomatic
  report count citizens with [epidemic-state = 1 ]
end

to-report nb-I
  report count citizens with [epidemic-state = 2 ]
end

to-report nb-R
  report count citizens with [epidemic-state = 3 ]
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
1
1
1
-30
30
-20
20
0
0
1
ticks
30.0

BUTTON
623
411
748
466
Ré-initialiser
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
623
471
748
529
Partez ! / Pause
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
1000
226
Epidémie
Temps(nbjours)
Nombre total de cas
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Sains" 1.0 0 -2570826 true "" "if nb-S > 0 [set-plot-pen-color color-susceptible plot nb-S]"
"Infectés" 1.0 0 -16514302 true "" "set-plot-pen-color color-infected plot nb-I"
"Guéris" 1.0 0 -8990512 true "" "set-plot-pen-color color-recovered plot nb-R"
"Confinés" 1.0 0 -6917194 true "" "set-plot-pen-color color-houses plot count citizens with [confined?]"

TEXTBOX
12
420
584
546
Pour exécuter la simulation :\n1 - Cliquez sur le bouton \"Ré-initialiser\"\n2 - Cliquez sur le bouton \"Partez ! / Pause\" \nNB: si vous voulez mettre en Pause la simulation le temps de faire vos choix, cliquez à nouveau sur \"Partez ! / Pause\"\nPour modifier les conditions de confinement vous pouvez jouer sur :\n- l'interrupteur permettant de ne confiner que les individus symptomatiques\n- le pourcentage de confinés\n- le scénario de confinement (Très Strict, Strict, Souple)\n
11
63.0
1

SLIDER
753
448
1002
481
pourcentage-confinés
pourcentage-confinés
0
100
0.0
20
1
NIL
HORIZONTAL

CHOOSER
752
485
1002
530
scenario-confinement
scenario-confinement
"Très Strict" "Strict" "Souple"
2

PLOT
597
227
1000
406
Scénarios de confinement
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Très Strict" 1.0 1 -2674135 true "" "ifelse scenario-confinement = \"Très Strict\" [plot pourcentage-confinés][plot 0]"
"Strict" 1.0 1 -955883 true "" "ifelse scenario-confinement = \"Strict\" [plot pourcentage-confinés][plot 0]"
"Souple" 1.0 1 -987046 true "" "ifelse scenario-confinement = \"Souple\" [plot pourcentage-confinés][plot 0]"

SWITCH
753
411
1001
444
confiner-infectés-symptomatiques?
confiner-infectés-symptomatiques?
1
1
-1000

TEXTBOX
521
540
1014
558
Un mode d'emploi plus complet est disponible dans l'onglet Model Info sous la simulation
11
26.0
1

@#$#@#$#@
## DESCRIPTION DU MODELE
Dans ce modèle les individus sont soit sains (beige), soit porteurs asymptomtiques (marron) lorsqu'ils sont contaminés par contact avec un porteur, puis au bout de 8 jours (32 itérations) ils deviennent infectés (symptomatiques) (noir) et 14 jours plus tard (56 itérations) ils deviennent guéris (bleu turquoise). 
 
## COMMENT AGIR ?
Pour contrer le développement de l'épidémie, vous pouvez jouer sur deux mesures :
1. Confiner les individus infectés, dans ce cas ce sont uniquement les porteurs symptomatiques qui seront confinés (les porteurs asymptomatiques se déplacent encore et propagent donc l'épidémie).
2. Confiner une partie de la population quelquesoit son état. Vous pouvez dans ce cas sélectionner la proportion que vous souhaitez confiner (0,20%,40%,60%,80%,100%).
Dans ce cas vous pouvez choisir un régime de confinement plus ou moins strict.
a.Régime de confinement très strict : les individus confinés peuvent sortir en moyenne une fois toutes les 20 itérations et dans un rayon de 500m autour de chez eux.
b.Régime de confinement strict : les individus confinés peuvent sortir en moyenne une fois toutes les 10 itérations dans un rayon d'1km autour de chez eux.
c.Régime de confinement souple : les confinés peuvent sortir en moyenne une fois toutes les 5 itérations dans un rayon de 2km autour de chez eux.
NB: si vous confinez une partie de la population (2.) la mesure de confinement des infectés sera automatiquement enclenchée. Ces derniers sont dans tous les cas dans un régime de confinement trés strict (sortie toute les 20 itérations, 500m autour de chez eux).

## A REMARQUER
Les individus asymptomatiques sont une des difficultés principales à gérer dans ce modèle. Vous vous rendrez compte que confiner uniquement les individus symptomatiques, ne change pas grand chose au développement de l'épidémie, les individus asymptomatiques (marron) continuant de la propager.
NB: les individus asymptomatiques sont figurés en marron mais "normalement" vous ne devriez pas pouvoir les distinguer des individus sains (à moins de les tester).
En pratique, sur ce modèle, seules des mesures drastiques dès les premiers cas symptomatiques détectés permettent un peu d'endiguer l'épidémie ou du moins d'applatir la courbe d'infection. Encore faut-il ne pas lever les mesures de confinement trop tôt.
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
NetLogo 6.1.0
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
@#$#@#$#@
0
@#$#@#$#@
