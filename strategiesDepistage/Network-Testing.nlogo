extensions [nw]

globals
[

infinity
max-size-neighborhood
clustering-coefficient
nb-seeds-fractal
]

breed [nodes node]
undirected-link-breed [edges edge]




nodes-own
[

modulus ;;For the fractal network
node-clustering-coefficient
  epidemic-state ;0 --> S, 1 --> I, 2 --> R
  tested?; False / True
]

to setup-globals
set infinity 1.0E+10
set max-size-neighborhood 0.5
set nb-seeds-fractal 3
end



to setup
  ca
  reset-ticks
  setup-network
  do-calculations
  setup-SIR
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup SIR
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-SIR
  set-current-plot "EPIDEMIC"
  clear-plot
  reset-ticks
  ask nodes
  [
    set epidemic-state 0
    set color green
    set tested? false]
  setup-initial-infection
end



to setup-initial-infection

  ask n-of Nb-nodes-initially-infected nodes
  [
    set epidemic-state  1
  set color red
  ]
end


to Go
  if not any? nodes with [epidemic-state = 1] [stop]
  transmit-virus
  recover
  tick
end

;THE MAIN ADVANTAGE OF NETWORK STRUCTURE IS THE WAY TOPOLOGY IS HANDLED
;CONTACTS (NEIGHBORS) ARE DIRECTLY AVAILABLE WITH LINK-NEIGHBORS

to transmit-virus
  ask nodes with [epidemic-state = 1]
  [
    let me1 self
    ask link-neighbors with [epidemic-state  = 0]
  [
      let me2 self
    if random-float 1 < Probability-transmission
      [
        set epidemic-state 1
        set color red
        ask edge [who] of me1 [who] of me2 [set color red]] ;WE COLOR LINKS TO SHOW CONTAGION PATH
    ]
  ]
end


;Recovering based on a probability, TIME should be added

to recover
  ask nodes with [epidemic-state = 1]
  [
  if random-float 1 < probability-recovering
    [
    set epidemic-state 2
      set color blue
    ]
  ]

end



;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup network
;;nodes = nodes, edges = relations between neighbors
;;;;;;;;;;;;;;;;;;;;;;;;;;;





to setup-network
  if Network =  "Grid-4" [setup-square 4]
  if Network =  "Grid-8" [setup-square 8]
  if Network =  "Random" [setup-simple-random]
  if Network =  "Small World" [setup-smallworld]
  if Network =  "Scale Free" [setup-scalefree]
  if Network =  "Fractal" [Setup-Serpienski]
  nw:set-context nodes edges
  do-plotting
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Regular Network
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-square [NB-Neighbors-Regular-Grid]
  __clear-all-and-reset-ticks
  setup-globals

  ask patches with [pxcor mod 3 = 0 and
                    pycor mod 3 = 0]
  [
  sprout-nodes 1
  [
      set shape "square"
      set size nodes-size
      set color green
  ]
  ]
  ifelse NB-Neighbors-Regular-Grid = 4
    [ ask nodes [ create-edges-with nodes in-radius 3 with [self != myself]]]
    [ ask nodes [ create-edges-with nodes in-radius 5 with [self != myself]]]
end


;;Random network

to setup-simple-random
  __clear-all-and-reset-ticks
  setup-globals
  let num-edges (1.3 * max-number-nodes)
  create-nodes max-number-nodes
  [
  set size nodes-size
    set color green
  setxy random-xcor * 0.95 random-ycor * 0.95
  if any? nodes-here [fd 1]]
  ask nodes
     [

     create-edges-with other nodes in-radius max-size-neighborhood]

  while [count edges < num-edges ]
  [
    ask one-of nodes
    [
      let choice (min-one-of (other nodes with [not link-neighbor? myself])
                   [distance myself])
      if choice != nobody [ create-edge-with choice ]
    ]
  ]
  ask nodes with [count link-neighbors < 4]
  [create-edge-with min-one-of (other nodes with [not link-neighbor? myself and count link-neighbors >= 3]) ;to make sure no isolated subnets < 4 connected nodes remain
                   [distance myself]]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fractal network (Serpienski)
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;From Arnaud

; create a node and set its initial location and modulus
to setup-Serpienski
  __clear-all-and-reset-ticks
  setup-globals
  create-nodes 1
  [
    set heading 0
    set size nodes-size
    set color green
    setxy 0 -1
    set modulus 0.5 * max-pycor
  ]
  while [count nodes < max-number-nodes] [Create-Serpienski nb-seeds-fractal]
end

; ask the nodes to go forward by modulus, create a new node to
; draw the next iteration of sierpinski's tree, and return to its place
to grow-Serpienski
  hatch 1
    [ fd modulus
     create-edge-with myself
      ifelse nb-seeds-fractal = 3 [set modulus (0.5 * modulus) ]  ; new node's modulus is half its parent's
                                  [ifelse nb-seeds-fractal = 5 [set modulus (0.4 * modulus) ]
                                                               [set modulus (0.3 * modulus) ] ]
    ]


end

; draw the sierpinski tree
to Create-Serpienski [nb]
  ask nodes with [count edge-neighbors < 2]
  [
    repeat nb
    [
      grow-Serpienski
      right  360 / nb  ; turn counter-clockwise to draw more legs
    ]
  ]
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Small World network ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

;Generates a Watts-Strogatz small-world networ using NW extension

to setup-smallworld

 nw:generate-watts-strogatz nodes edges max-number-nodes 2 0.1 [set color green set size nodes-size  fd 15 ]

  end





;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Scale free network ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

;;From NetLogo Library

to setup-scalefree
  __clear-all-and-reset-ticks
  setup-globals
  set-default-shape nodes "square"
  ;; make the initial network of two nodes and an edge
  make-node nobody        ;; first node, unattached
  make-node node 0      ;; second node, attached to first node
  create-scalefree
end


to create-scalefree
  while [count nodes < max-number-nodes]
  [
  ;; new edge is green, old edges are gray
  ask edges [ set color gray ]
  make-node find-partner         ;; find partner & use it as attachment
                                 ;; point for new node
  tick

  layout
  ]
end

;; used for creating a new node
to make-node [old-node]
  create-nodes 1
  [
    set color green
    set size nodes-size
    if old-node != nobody
      [ create-edge-with old-node [ set color green ]
        ;; position the new node near its partner
        move-to old-node
        fd 1
      ]
  ]
end

to-report find-partner
  let total random-float sum [count edge-neighbors] of nodes
  let partner nobody
  ask nodes
  [
    let nc count edge-neighbors
    ;; if there's no winner yet...
    if partner = nobody
    [
      ifelse nc > total
        [ set partner self ]
        [ set total total - nc ]
    ]
  ]
  report partner
end


;; resize-nodes, change back and forth from size based on degree to a size of 1
to resize-nodes
  ifelse all? nodes [size <= 1]
  [
    ;; a node is a circle with diameter determined by
    ;; the SIZE variable; using SQRT makes the circle's
    ;; area proportional to its degree
    ask nodes [ set size sqrt count edge-neighbors ]
  ]
  [
    ask nodes [ set size 1 ]
  ]
end

to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 20 [
    ;; the more nodes we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor count nodes
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring nodes edges (1 / factor) (7 / factor) (1 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of nodes + min [xcor] of nodes
  let y-offset max [ycor] of nodes + min [ycor] of nodes
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask nodes [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Plotting
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;






to do-plotting
  let max-degree max [count link-neighbors] of nodes
  set-current-plot "Degree Distribution"
  plot-pen-reset
  set-plot-x-range 0 (max-degree + 1)
  histogram [count link-neighbors] of nodes
  end







;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Clustering computations ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;Inspired for Models Library ==> Networks ==> Small-World

to do-calculations

  ;; find the clustering coefficient and add to the aggregate for all iterations
  find-clustering-coefficient


end

to-report in-neighborhood? [ hood ]
  report ( member? end1 hood and member? end2 hood )
end


to find-clustering-coefficient

  ifelse all? nodes [count link-neighbors <= 1]
  [
    ;; it is undefined
    ;; what should this be?
    set clustering-coefficient 0
  ]
  [
    let total 0
    ask nodes with [ count link-neighbors <= 1]
      [ set node-clustering-coefficient "undefined" ]
    ask nodes with [ count link-neighbors > 1]
    [
      let hood link-neighbors
      set node-clustering-coefficient (2 * count edges with [ in-neighborhood? hood ] /
                                         ((count hood) * (count hood - 1)) )
      ;; find the sum for the value at turtles
      set total total + node-clustering-coefficient
    ]
    ;; take the average
    set clustering-coefficient total / count nodes with [count link-neighbors > 1]
  ]
end



@#$#@#$#@
GRAPHICS-WINDOW
436
10
1125
700
-1
-1
23.32
1
10
1
1
1
0
0
0
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
279
50
429
84
SETUP NETWORK
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
56
264
426
481
Degree Distribution
Degree
# Nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

SLIDER
227
154
432
188
max-number-nodes
max-number-nodes
10
1000
240.0
10
1
NIL
HORIZONTAL

MONITOR
154
486
219
531
#Nodes
count nodes
17
1
11

MONITOR
83
485
148
530
#Edges
count edges
17
1
11

MONITOR
230
485
310
530
Density
(count edges * 2) / count nodes
2
1
11

SLIDER
228
195
433
229
nodes-size
nodes-size
0.3
1
0.6
0.1
1
NIL
HORIZONTAL

CHOOSER
186
98
431
143
NETWORK
NETWORK
"Grid-4" "Grid-8" "Random" "Small World" "Scale Free" "Fractal"
2

MONITOR
316
486
384
531
Clustering
clustering-coefficient
2
1
11

TEXTBOX
332
16
440
38
NETWORK
20
0.0
1

TEXTBOX
1147
17
1255
39
SIR MODEL
20
0.0
1

SLIDER
1134
108
1350
142
Nb-nodes-initially-infected
Nb-nodes-initially-infected
1
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
1134
155
1351
189
Probability-transmission
Probability-transmission
0
0.3
0.005
0.001
1
NIL
HORIZONTAL

BUTTON
1240
58
1304
92
NIL
Go
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
1137
256
1516
573
Epidemic
Time
Number of cases
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"S" 1.0 0 -13840069 true "" "if any? nodes [plot count nodes with [epidemic-state = 0]]"
"I" 1.0 0 -2674135 true "" "if any? nodes [plot count nodes with [epidemic-state = 1]]"
"pen-2" 1.0 0 -13345367 true "" "if any? nodes [plot count nodes with [epidemic-state = 2]]"

SLIDER
1135
197
1353
231
probability-recovering
probability-recovering
0
0.3
0.001
0.001
1
NIL
HORIZONTAL

BUTTON
1133
58
1238
92
SETUP SIR
setup-SIR
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

Network generator, taking and adapting pieces of code from almost everywhere.

Arnaud Banos, 15/10/2015
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
setup-square
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Epidermiques" repetitions="500" runMetricsEveryStep="false">
    <setup>initialise-nodes
identify-neighbors</setup>
    <go>run-schelling-agents</go>
    <timeLimit steps="500"/>
    <metric>mean [proportion-neighbors-different] of nodes with [current-state &lt; 3]</metric>
    <enumeratedValueSet variable="Tolerance">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
      <value value="70"/>
      <value value="80"/>
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="opportunistes" repetitions="500" runMetricsEveryStep="false">
    <setup>initialise-nodes
identify-neighbors</setup>
    <go>run-schelling-agents-utility</go>
    <timeLimit steps="100"/>
    <metric>mean [proportion-neighbors-different] of nodes with [current-state &lt; 3]</metric>
    <enumeratedValueSet variable="Tolerance">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
      <value value="70"/>
      <value value="80"/>
      <value value="90"/>
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
