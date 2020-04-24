;extensions [ vid ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; AGENTS AND THEIR VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ susceptibles a-susceptible ]
breed [ incubating an-incubating ]
breed [ infected a-infected ]
breed [ immunised a-immunised ]


turtles-own [
  state-duration
  my-travel-distance
  nb-infections
  nb-transmissions
  xadr
  yadr

]


immunised-own [ immunity-protection ]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; GLOBAL VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  headless-proportion-immunised
  headless-transmission-rate
  headless-avg-infectivity-duration
  headless-avg-immunity-duration
  headless-partial-immunity?

;  population-size
  population-density
  nb-infected-initialisation
  transmission-distance
  nb-contacts
  travel-distance
  walking-angle
  speed
  transparency

  nb-Confinenement

  new-I
  new-R
  total-nb-I
  total-nb-R
  date-all-infected

  ;; colors
  color-susceptible
  color-infected
  color-recovered
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; SCENARIO-DEPENDENT SETUP ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  random-seed 25
  reset-ticks

  setup-globals
  setup-world
  setup-population

;  (vid:start-recorder 1080 1080)
end


to setup-globals
  set headless-proportion-immunised proportion-personnes-immunisees
  set headless-transmission-rate taux-de-transmission
  set headless-avg-infectivity-duration duree-de-contagiosite
  set headless-avg-immunity-duration duree-immunite * 30 ;; transform months into days
  set headless-partial-immunity? immunite-partielle?

;  set population-size 10000
  set population-density 105 ;; average for France
  set nb-infected-initialisation 1
  set transmission-distance 1
  set travel-distance 3
  set walking-angle 50
  set speed 0.5

  set total-nb-I 0
  set total-nb-R 0
  set date-all-infected 0

  ;; colors
;  set color-susceptible [223 194 125]
;  set color-infected [128 205 193]
;  set color-recovered [166 97 26]
  set color-susceptible [0 153 255]
  set color-infected [255 0 0]
  set color-recovered [0 0 0]
  set transparency 145
end


to setup-world
  ;; resize the world to match given density and population-size
  let patch-side-size 100 ;; meters
  let width (sqrt (population-size / population-density)) * 1000 / patch-side-size
  let max-cor floor ((width - 1) / 2)
  resize-world (- max-cor) (max-cor) (- max-cor) (max-cor)

  ask patches [ set pcolor white ]
end


to setup-population
  set-default-shape turtles "circle"

  ;; susceptibles
  create-turtles population-size [
    setxy random-xcor random-ycor
    set xadr xcor
    set yadr ycor
    get-susceptible
    set nb-infections 0
    set nb-transmissions 0

  ]

  ;; immunised
  let nb-immunised-init floor (headless-proportion-immunised / 100 * population-size)
  ask up-to-n-of nb-immunised-init susceptibles [ get-immunised ]

  ;; import virus
  ask up-to-n-of nb-infected-initialisation susceptibles [ get-infected ]
end

to get-susceptible
  set breed susceptibles
  set color lput transparency color-susceptible
  set state-duration -1
  set my-travel-distance travel-distance
end

to get-immunised
  set breed immunised
  set color lput transparency color-recovered
  set state-duration gamma-law headless-avg-immunity-duration 4
  set my-travel-distance travel-distance
  set nb-transmissions 0
  if headless-partial-immunity? [ set immunity-protection ((random 51) + 50) / 100 ]

  set new-R new-R + 1
end


to get-infected
  set breed infected
  set color lput transparency color-infected
  set state-duration gamma-law headless-avg-infectivity-duration 1
  set my-travel-distance travel-distance
  set nb-infections nb-infections + 1

  set new-I new-I + 1
end


to-report gamma-law [avg var]
  let alpha avg * avg / var
  let lambda avg / var

  report floor random-gamma alpha lambda
end



;;;;;;;;;;;;;;;;;;;;;;
;;;;; PROCEDURES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;

to go
  ifelse virus-present?
  [
    set new-I 0
    set new-R 0

    ;; movement
    ask turtles [ move-randomly ]

    ;; transmission
    virus-transmission

    update-states

    tick
;    vid:record-view
  ]
  [
;    vid:save-recording (word "simu_" headless-proportion-immunised "_" headless-spatialised-world? "_" headless-first-case-west? "_FR.mp4")
    stop
  ]
end


to move-randomly ;; turtle procedure
 set xcor xadr         ;;;; Il RESTE AUTOUR DE CHEZ LUI
 set ycor yadr

 set heading random 360


 if (count infected < 0.015 * population-size) ; and (( count infected / (sum [nb-transmissions] of turtles + 1 )) < 1 )

 ; if not confined?
  [ while [my-travel-distance > 0] [
    while [patch-ahead 1 = nobody] [ right random 360 ]
    jump 1
    set my-travel-distance my-travel-distance - 1
  ]
  ]

  set my-travel-distance travel-distance
end


to virus-transmission ;; turtle procedure
  ask infected [
    let potential-contacts turtles in-radius transmission-distance
    let contacts n-of random (count potential-contacts) potential-contacts

    ask contacts with [breed = susceptibles] [
      if random-float 1 < headless-transmission-rate [
        get-infected
        ask myself [ set nb-transmissions nb-transmissions + 1 ]
        stop
      ]
    ]

    if headless-partial-immunity? [
      ask contacts with [breed = immunised] [
        if random-float 1 < headless-transmission-rate * (1 - immunity-protection) [
          get-infected
          ask myself [ set nb-transmissions nb-transmissions + 1 ]
          stop
        ]
      ]
    ]
  ]
end



;;;;;;;;;;;;;;;;;;;
;;;;; UPDATES ;;;;;
;;;;;;;;;;;;;;;;;;;

to update-states
  ask infected [
    (ifelse
      state-duration > 0 [ set state-duration state-duration - 1 ]
      state-duration = 0 [ get-immunised ]
    )
  ]

  ask immunised [
    (ifelse
      state-duration > 0 [ set state-duration state-duration - 1 ]
      state-duration = 0 [ get-susceptible ]
    )
  ]

  set total-nb-I total-nb-I + new-I
  set total-nb-R total-nb-R + new-R
  if count turtles with [nb-infections > 0] = population-size and date-all-infected = 0 [ set date-all-infected ticks ]
end



;;;;;;;;;;;;;;;;;;;;;
;;;;; REPORTERS ;;;;;
;;;;;;;;;;;;;;;;;;;;;

to-report nb-S
  report count susceptibles
end

to-report nb-I
  report count infected
end

to-report nb-R
  report count immunised
end

to-report virus-present?
  report nb-I > 0
end
@#$#@#$#@
GRAPHICS-WINDOW
671
10
1336
676
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
-34
34
-34
34
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
18
456
666
719
Dynamique épidémique
Jours
% de cas
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Personnes saines" 1.0 0 -16777216 true "" "set-plot-pen-color color-susceptible plot (nb-S / population-size ) * 100"
"Personnes infectées" 1.0 0 -16777216 true "" "set-plot-pen-color color-infected plot (nb-I / population-size ) * 100"
"Personnes immunisées" 1.0 0 -16777216 true "" "set-plot-pen-color color-recovered plot (nb-R / population-size ) * 100"

SLIDER
16
10
338
43
proportion-personnes-immunisees
proportion-personnes-immunisees
0
100
0.0
5
1
%
HORIZONTAL

SLIDER
18
111
275
144
duree-de-contagiosite
duree-de-contagiosite
1
30
21.0
1
1
jours
HORIZONTAL

SLIDER
19
69
227
102
taux-de-transmission
taux-de-transmission
0
1
0.12
0.01
1
NIL
HORIZONTAL

PLOT
18
718
546
981
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
"Personnes infectées" 1.0 0 -16777216 true "" "set-plot-pen-color color-infected plot new-I"
"Personnes immunisées" 1.0 0 -7500403 true "" "set-plot-pen-color color-recovered plot new-R"

MONITOR
20
304
171
349
nb de personnes saines
nb-S
17
1
11

MONITOR
190
305
355
350
nb de personnes infectées
nb-I
17
1
11

MONITOR
378
305
533
350
nb de personnes guéries
nb-R
17
1
11

MONITOR
73
373
453
418
temps nécessaire pour infecter 100% de la population (en jours)
date-all-infected
0
1
11

INPUTBOX
368
83
529
143
population-size
5000.0
1
0
Number

SLIDER
16
154
224
187
duree-immunite
duree-immunite
0
24
24.0
1
1
mois
HORIZONTAL

SWITCH
17
198
210
231
immunite-partielle?
immunite-partielle?
1
1
-1000

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
"default" 1.0 0 -16777216 true "" "set-plot-pen-color black plot sum [nb-transmissions] of turtles "
"pen-1" 1.0 0 -7500403 true "" "set-plot-pen-color red plot count infected"

PLOT
928
734
1313
1040
Distribution de la force de l'immunité partielle
NIL
NIL
0.5
1.0
0.0
10.0
true
false
"" ""
PENS
"default" 0.01 1 -16777216 true "" "histogram [immunity-protection] of immunised"

SWITCH
536
74
655
107
Confined?
Confined?
1
1
-1000

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
