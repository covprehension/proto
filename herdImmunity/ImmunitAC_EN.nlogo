patches-own [
  state
  infectivity-counter
]

globals [
  headless-proportion-immunised
  headless-spatialised-world?
  headless-first-case-west?
  headless-infectivity-duration
  headless-transmission-rate
  headless-nb-new-infections

  population-size
  new-I
  total-nb-I

  ;; colors
  color-susceptible
  color-infected
  color-recovered
]

to setup
  clear-all
;  random-seed 42

  setup-globals
  setup-patches

  reset-ticks
end

to setup-globals
  set headless-proportion-immunised proportion-immunised
  set headless-spatialised-world? spatialised-world?
  set headless-first-case-west? first-case-west?
  set headless-infectivity-duration infectivity-duration
  set headless-transmission-rate transmission-rate
  set headless-nb-new-infections nb-new-infections

  set population-size count patches
  set new-I 0
  set total-nb-I 0

  set color-susceptible [223 194 125]
  set color-infected [128 205 193]
  set color-recovered [166 97 26]
end

to setup-patches
  ;; susceptibles
  ask patches [
    set state "S"
    set pcolor color-susceptible
    set infectivity-counter -1
  ]

  ;; immunised
  let nb-immunised-init floor (headless-proportion-immunised / 100 * population-size)
  ifelse headless-spatialised-world?
  [ ask up-to-n-of nb-immunised-init patches with [pxcor > 0] [ get-immunised ] ]
  [ ask up-to-n-of nb-immunised-init patches [ get-immunised ] ]

  ;; import virus
  random-infection
end

to get-immunised
  set state "R"
  set pcolor color-recovered
  set infectivity-counter -1
end

to get-infected
  set state "I"
  set pcolor color-infected
  set infectivity-counter headless-infectivity-duration
  set new-I new-I + 1
end

to random-infection
  let target (ifelse-value
    headless-spatialised-world? and headless-first-case-west? [ patch (- max-pxcor + 20) 0 ]
    headless-spatialised-world? [ patch (max-pxcor - 20) 0 ]
    ;; else
    [ one-of patches with [state = "S"] ]
;    [ patch 0 0 ]
  )

  if is-agent? target [ ask target [ get-infected ] ]
end

to go
  ifelse virus-present?
  [
    set new-I 0
    diffusion
    update-states
    tick
  ]
  [ stop ]
end

to diffusion
  ask patches with [state = "S"] [
    let contacts n-of (random count neighbors) neighbors
    let infected-contacts contacts with [state = "I"]
    if any? infected-contacts [
      repeat count infected-contacts [
        if random-float 1 < headless-transmission-rate [ get-infected stop ]
      ]
    ]
  ]
end

to update-states
  ask patches with [state = "I"] [
    (ifelse
      infectivity-counter > 0 [ set infectivity-counter infectivity-counter - 1 ]
      infectivity-counter = 0 [ get-immunised ]
    )
  ]

  set total-nb-I total-nb-I + new-I
end

to new-infections
  ask up-to-n-of headless-nb-new-infections patches with [state = "S"] [ get-infected ]
end


;;;;; Reporters ;;;;;

to-report nb-S
  report count patches with [state = "S"]
end

to-report nb-I
  report count patches with [state = "I"]
end

to-report nb-R
  report count patches with [state = "R"]
end

to-report virus-present?
  report nb-I > 0
end
@#$#@#$#@
GRAPHICS-WINDOW
379
10
1024
656
-1
-1
4.28
1
10
1
1
1
0
0
0
1
-74
74
-74
74
0
0
1
ticks
30.0

BUTTON
202
425
307
458
Simulate
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

SLIDER
16
294
229
327
infectivity-duration
infectivity-duration
1
30
21.0
1
1
days
HORIZONTAL

PLOT
16
741
408
995
Prevalence
Days
% of cases
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Susceptible" 1.0 0 -16777216 true "" "set-plot-pen-color color-susceptible plot (nb-S / population-size ) * 100"
"Infected" 1.0 0 -16777216 true "" "set-plot-pen-color color-infected plot (nb-I / population-size ) * 100"
"Recovered" 1.0 0 -16777216 true "" "set-plot-pen-color color-recovered plot (nb-R  / population-size ) * 100"

BUTTON
17
424
122
457
Initialise
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

SLIDER
16
326
229
359
transmission-rate
transmission-rate
0
1
0.12
0.01
1
NIL
HORIZONTAL

SLIDER
12
37
287
70
proportion-immunised
proportion-immunised
0
100
20.0
5
1
%
HORIZONTAL

BUTTON
203
561
362
594
infect new people
new-infections
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
14
177
181
210
spatialised-world?
spatialised-world?
1
1
-1000

SLIDER
19
561
185
594
nb-new-infections
nb-new-infections
1
10
5.0
1
1
NIL
HORIZONTAL

TEXTBOX
14
11
317
29
1 - Choose the proportion of immunised people
12
105.0
1

TEXTBOX
14
90
296
165
2 - Do you want the world to be spatialised? All immunised individuals will then be located on the east side of the world.\nWhere should the first infection occur, east or west? 
12
105.0
1

TEXTBOX
190
172
381
247
Be careful: if you choose a spatialised world, the proportion of immunised individuals must be under 50%.
12
15.0
1

TEXTBOX
17
265
262
283
3 - Choose values for the parameters
12
105.0
1

TEXTBOX
19
383
142
413
4 - Click to initialise the simulation
12
105.0
1

MONITOR
16
671
168
716
nb of susceptible people
nb-S
0
1
11

MONITOR
221
671
352
716
nb of infected people
nb-I
17
1
11

MONITOR
407
671
551
716
nb of recovered people
Nb-R
0
1
11

TEXTBOX
180
688
217
706
----->
12
0.0
1

TEXTBOX
364
688
399
706
----->
12
0.0
1

TEXTBOX
204
383
306
413
5 - Click to start the simulation
12
105.0
1

TEXTBOX
20
487
325
547
6 - Optional: Choose a number and then click to infect new individuals with the virus.\n\nDoes the epidemic start again or does it die off?
12
105.0
1

MONITOR
601
671
714
716
final % of infected
total-nb-I / population-size * 100
2
1
11

MONITOR
713
671
925
716
% of susceptibles who got infected
total-nb-I / ((1 - (proportion-immunised / 100)) * population-size) * 100
2
1
11

SWITCH
14
209
181
242
first-case-west?
first-case-west?
1
1
-1000

PLOT
415
741
807
995
Number of new cases per day
Days
Number of cases
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "set-plot-pen-color color-infected plot new-I"

@#$#@#$#@
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

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

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
  <experiment name="experiment" repetitions="50" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>nba - 0</exitCondition>
    <metric>count nba</metric>
    <enumeratedValueSet variable="r">
      <value value="10"/>
      <value value="5"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duree_de_vie">
      <value value="1"/>
      <value value="1"/>
      <value value="10"/>
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
@#$#@#$#@
0
@#$#@#$#@
