;extensions [ vid ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; AGENTS AND THEIR VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ susceptibles a-susceptible ]
breed [ incubating an-incubating ]
breed [ asymptomatic an-asymptomatic ]
breed [ symptomatic a-symptomatic ]
breed [ recovered a-recovered ]


turtles-own [
  state-duration
  nb-transmissions
  moving?
;  quarantined?
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; GLOBAL VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  headless-population-size
  headless-transmission-rate
  headless-proportion-asymptomatic
  headless-targeted-lockdown-threshold
  headless-general-lockdown-threshold
  headless-general-lockdown-duration

  nb-infected-initialisation
  nb-contacts
  travel-distance
  herd-immunity-rate
  avg-incubation-duration
  var-incubation-duration
  avg-symptom-duration
  var-symptom-duration

  targeted-lockdown?
  general-lockdown?
  general-lockdown-counter
  nb-general-lockdowns

  new-I
  new-R
  total-nb-I
  total-nb-R
  total-prop-I
  date-herd-immunity

  ;; colors
  color-susceptible
  color-incubating
  color-asymptomatic
  color-symptomatic
  color-recovered
  transparency
]



;;;;;;;;;;;;;;;;;
;;;;; SETUP ;;;;;
;;;;;;;;;;;;;;;;;

to setup ;; observer procedure
  clear-all
  random-seed seed
  reset-ticks

  setup-GUI
  setup-globals
  setup-world
  setup-population

;  (vid:start-recorder 1080 1080)
end

to headless-setup ;; observer procedure
  reset-ticks

  setup-globals
  setup-world
  setup-population
end


to setup-GUI ;; observer procedure
  set headless-population-size population-size
  set headless-transmission-rate taux-de-transmission
  set headless-proportion-asymptomatic proportion-asymptomatiques
  set headless-targeted-lockdown-threshold seuil-confinement-cible
  set headless-general-lockdown-threshold seuil-confinement-general
  set headless-general-lockdown-duration duree-confinement-general * 7 ;; transform weeks into days
end


to setup-globals ;; observer procedure
  set nb-infected-initialisation 1
  set nb-contacts 10
  set travel-distance 2
  set herd-immunity-rate 0.65
  set avg-incubation-duration 6
  set var-incubation-duration 3
  set avg-symptom-duration 21
  set var-symptom-duration 1

  set targeted-lockdown? false
  set general-lockdown? false
  set general-lockdown-counter -1
  set nb-general-lockdowns 0

  set total-nb-I 0
  set total-nb-R 0
  set total-prop-I 0
  set date-herd-immunity -1

  ;; colors
  set color-susceptible [0 153 255]
  set color-incubating [254 178 76]
  set color-asymptomatic [153 153 153]
  set color-symptomatic [255 0 0]
  set color-recovered [0 0 0]
  set transparency 145
end


to setup-world ;; observer procedure
  let width sqrt (headless-population-size / (nb-contacts + 1))
  let max-cor floor ((width - 1) / 2)
  resize-world (- max-cor) (max-cor) (- max-cor) (max-cor)

  ask patches [ set pcolor white ]
end


to setup-population ;; observer procedure
  set-default-shape turtles "circle"

  ;; susceptibles
  create-turtles headless-population-size [
    setxy random-xcor random-ycor
    set size 0.3
    get-susceptible
    set nb-transmissions 0
    set moving? false
;    set quarantined? false
  ]

  ;; import virus
  ask up-to-n-of nb-infected-initialisation susceptibles [ get-incubating ]
end



;;;;;;;;;;;;;;;;;;;;;
;;;;; TIME STEP ;;;;;
;;;;;;;;;;;;;;;;;;;;;

to go ;; observer procedure
  ifelse virus-present?
  [
    headless-go
;    vid:record-view
  ]
  [
;    vid:save-recording (word "simu_" headless-proportion-immunised "_" headless-spatialised-world? "_" headless-first-case-west? "_FR.mp4")
    stop
  ]
end

to headless-go ;; observer procedure
  reset-case-counts
  move
  virus-transmission
  quarantine-decision
  update-states
  update-counters

  tick
end


to reset-case-counts ;; observer procedure
  set new-I 0
  set new-R 0
end


to move ;; observer procedure
  ifelse targeted-lockdown?
  ;; already in lockdown
  [
    ask turtles with [breed != symptomatic] [
      ifelse general-lockdown?
      ;; some non symptomatic agents can move
      [ if random 100 < 20 [ move-randomly travel-distance ] ]
      ;; all non symptomatic agents can move
      [ move-randomly travel-distance ]
    ]
  ]
  ;; no lockdown, everyone can move
  [ ask turtles [ move-randomly travel-distance ] ]
end


to move-randomly [my-travel-distance] ;; turtle procedure
  while [my-travel-distance > 0] [
    set heading random 360
    while [patch-ahead 1 = nobody] [ right random 360 ]
    jump 1
    set my-travel-distance my-travel-distance - 1
  ]

  set moving? true
end


to virus-transmission ;; observer procedure
  ask contagious-turtles with [moving?] [
    let contacts other turtles-here with [moving?]

    ask contacts with [breed = susceptibles] [
      if random-float 1 < headless-transmission-rate [
        get-incubating
        ask myself [ set nb-transmissions nb-transmissions + 1 ]
        stop
      ]
    ]
  ]
end


to quarantine-decision
  (ifelse
    ;; start targeted lockdown
    not (targeted-lockdown? or general-lockdown?) and prop-I > headless-targeted-lockdown-threshold [
      set targeted-lockdown? true
;      ask symptomatic [ set quarantined? true ]
    ]

    ;; start general lockdown
    targeted-lockdown? and not general-lockdown? and prop-I > headless-general-lockdown-threshold [
      set general-lockdown? true
      set nb-general-lockdowns nb-general-lockdowns + 1
      set general-lockdown-counter headless-general-lockdown-duration
    ]

    ;; continue general lockdown
    general-lockdown? and general-lockdown-counter > 0 [ set general-lockdown-counter general-lockdown-counter - 1 ]

    ;; stop general lockdown
    general-lockdown? and general-lockdown-counter = 0 [
      set general-lockdown? false
      set general-lockdown-counter -1
    ]

    ;; stop targeted lockdown
    targeted-lockdown? and not general-lockdown? and prop-I < headless-targeted-lockdown-threshold [
      set targeted-lockdown? false
;      ask symptomatic [ set quarantined? false ]
    ]
  )
end


to update-states
  ask (turtle-set asymptomatic symptomatic) [
    (ifelse
      state-duration > 0 [ set state-duration state-duration - 1 ]
      state-duration = 0 [ get-recovered ]
    )
  ]

  ask incubating [
    (ifelse
      state-duration > 0 [ set state-duration state-duration - 1 ]
      state-duration = 0 [
        ifelse random 100 < headless-proportion-asymptomatic
        [ get-asymptomatic ]
        [ get-symptomatic ]
      ]
    )
  ]

  ask turtles with [moving?] [ set moving? false ]
end


to update-counters
  set total-nb-I total-nb-I + new-I
  set total-nb-R total-nb-R + new-R
  set total-prop-I nb-to-prop total-nb-I headless-population-size
  if count recovered > herd-immunity-rate * headless-population-size and date-herd-immunity < 0 [ set date-herd-immunity ticks ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; EPIDEMIC STATES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to get-susceptible
  set breed susceptibles
  set color lput transparency color-susceptible
  set state-duration -1
end

to get-incubating
  set breed incubating
  set color lput transparency color-incubating
  set state-duration gamma-law avg-incubation-duration var-incubation-duration
end

to get-asymptomatic
  set breed asymptomatic
  set color lput transparency color-asymptomatic
  set state-duration gamma-law avg-symptom-duration var-symptom-duration

  set new-I new-I + 1
end

to get-symptomatic
  set breed symptomatic
  set color lput transparency color-symptomatic
  set state-duration gamma-law avg-symptom-duration var-symptom-duration

  set new-I new-I + 1
end

to get-recovered
  set breed recovered
  set color lput transparency color-recovered
  set state-duration -1
;  set quarantined? false

  set new-R new-R + 1
end



;;;;;;;;;;;;;;;;;;;;;
;;;;; REPORTERS ;;;;;
;;;;;;;;;;;;;;;;;;;;;

;;; UTILS ;;;

to-report virus-present?
  report nb-I > 0
end

to-report contagious-turtles
  report (turtle-set incubating asymptomatic symptomatic)
end

;; gamma law for all durations
to-report gamma-law [avg var]
  let alpha avg * avg / var
  let lambda avg / var

  report floor random-gamma alpha lambda
end

;; transform count numbers into proportions
to-report nb-to-prop [number pop-totale]
  ifelse pop-totale > 0
  [ report number / pop-totale * 100 ]
  [ report 0 ]
end

;;; COUNTS ;;;

to-report nb-S
  report count susceptibles
end

to-report nb-Incub
  report count incubating
end

to-report nb-Asymp
  report count asymptomatic
end

to-report nb-Symp
  report count symptomatic
end

to-report nb-R
  report count recovered
end

to-report nb-I
  report nb-Incub + nb-Asymp + nb-Symp
end

to-report prop-I
  report nb-to-prop nb-I headless-population-size
end
@#$#@#$#@
GRAPHICS-WINDOW
671
10
1069
409
-1
-1
30.0
1
10
1
1
1
0
0
0
1
-6
6
-6
6
1
1
1
ticks
30.0

BUTTON
367
10
461
65
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
493
10
587
59
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
12
634
660
897
Dynamique épidémique
Jours
% de cas
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Personnes saines" 1.0 0 -16777216 true "" "set-plot-pen-color color-susceptible plot nb-to-prop nb-S population-size"
"Personnes en incubation" 1.0 0 -16777216 true "" "set-plot-pen-color color-incubating plot nb-to-prop nb-Incub population-size"
"Personnes asymptomatiques" 1.0 0 -16777216 true "" "set-plot-pen-color color-asymptomatic plot nb-to-prop nb-Asymp population-size"
"Personnes symptomatiques" 1.0 0 -16777216 true "" "set-plot-pen-color color-symptomatic plot nb-to-prop nb-Symp population-size"
"Personnes guéries" 1.0 0 -16777216 true "" "set-plot-pen-color color-recovered plot nb-to-prop nb-R population-size"

SLIDER
16
10
338
43
proportion-asymptomatiques
proportion-asymptomatiques
0
100
30.0
5
1
%
HORIZONTAL

SLIDER
18
111
275
144
seuil-confinement-cible
seuil-confinement-cible
0
50
5.0
5
1
%
HORIZONTAL

SLIDER
19
69
227
102
taux-de-transmission
taux-de-transmission
0
0.5
0.012
0.001
1
NIL
HORIZONTAL

PLOT
12
896
540
1159
Nombre de nouveaux cas par jour
Jours
Nombre de cas
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Personnes infectées" 1.0 0 -16777216 true "" "set-plot-pen-color color-symptomatic plot new-I"
"Personnes immunisées" 1.0 0 -7500403 true "" "set-plot-pen-color color-recovered plot new-R"

MONITOR
12
515
163
560
nb de personnes saines
nb-S
17
1
11

MONITOR
182
516
347
561
nb de personnes infectées
nb-I
17
1
11

MONITOR
370
516
525
561
nb de personnes guéries
nb-R
17
1
11

MONITOR
11
567
441
612
temps nécessaire pour infecter 65% de la population (en jours)
date-herd-immunity
0
1
11

INPUTBOX
368
83
529
143
population-size
2000.0
1
0
Number

SLIDER
16
154
268
187
seuil-confinement-general
seuil-confinement-general
0
50
15.0
5
1
%
HORIZONTAL

PLOT
556
734
931
1040
Distribution du nombre de transmissions
Nb d'infections
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [nb-transmissions] of turtles "

MONITOR
389
567
592
612
% de personnes saines infectées
total-prop-I
2
1
11

SLIDER
16
336
334
369
duree-confinement-general
duree-confinement-general
1
20
4.0
1
1
semaines
HORIZONTAL

BUTTON
516
61
667
94
temps exécution
setup\nreset-timer\nwhile [virus-present?] [ headless-go ]\nshow timer
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
366
442
535
487
Périodes de confinements
nb-general-lockdowns
17
1
11

INPUTBOX
374
165
535
225
seed
0.0
1
0
Number

@#$#@#$#@
## Qu'est-ce que c'est ?

Ce modèle propose d'explorer différents processus liés à la diffusion d'un virus dans une population d'individus sains et non immunisés. Les guérisons et décés ne sont pas pris en compte.

## Comment ça marche ?

Il suffit de choisir une simulation dans le menu déroulant, de l'initialiser (bouton "Prêt ?" et de la lancer (bouton "Partez!")


## CREDITS AND REFERENCES

Modèle développé par Arnaud Banos pour le site https://covprehension.org/
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
@#$#@#$#@
0
@#$#@#$#@
