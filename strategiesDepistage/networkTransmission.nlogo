extensions [nw]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; AGENTS AND THEIR VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ susceptibles a-susceptible ]
breed [ incubating a-incubating ]
breed [ asymptomatic a-asymptomatic ]
breed [ symptomatic a-symptomatic ]
breed [ recovered a-recovered ]

;undirected-link-breed [ family-members family-member ]
;undirected-link-breed [ friends friend ]
;undirected-link-breed [ colleagues colleague ]
undirected-link-breed [ edges edge ]


turtles-own [
  age
  state-duration
  tested?
  modulus ;;For the fractal network
  node-clustering-coefficient
]


globals [
  ;; variables from the interface
  headless-network
  headless-max-nb-nodes
  headless-asymptomatic-proportion
  headless-nb-nodes-initially-infected
  headless-transmission-rate
  headless-avg-incubation-duration
  headless-avg-infectivity-duration
  headless-testing-strategy
  headless-nb-tests-per-day
  headless-test-sensitivity
  headless-test-specificity

  infinity
  max-size-neighborhood
  nb-seeds-fractal
  clustering-coefficient

  ;; metrics
  new-Asymp
  new-Symp
  total-nb-I
  true-pos
  false-pos
  true-neg
  false-neg

  ;; colors
  color-susceptible
  color-incubating
  color-asymptomatic
  color-symptomatic
  color-recovered
]


;;;;;;;;;;;;;;;;;
;;;;; SETUP ;;;;;
;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks

  setup-globals
  setup-network
  setup-population
end


to setup-globals
  ;; get variables from the interface
  set headless-network NETWORK
  set headless-max-nb-nodes max-nb-nodes
  set headless-asymptomatic-proportion asymptomatic-proportion
  set headless-nb-nodes-initially-infected nb-nodes-initially-infected
  set headless-transmission-rate transmission-rate
  set headless-avg-incubation-duration avg-incubation-duration
  set headless-avg-infectivity-duration avg-infectivity-duration
  set headless-testing-strategy TESTING-STRATEGY
  set headless-nb-tests-per-day nb-tests-per-day-per-1000
  set headless-test-sensitivity test-sensitivity / 100
  set headless-test-specificity test-specificity / 100

  set infinity 1.0E+10
  set max-size-neighborhood 0.5
  set nb-seeds-fractal 3

  ;; metrics
  set total-nb-I headless-nb-nodes-initially-infected
  set true-pos 0
  set false-pos 0
  set true-neg 0
  set false-neg 0

  ;; colors
  set color-susceptible [0 153 255]
  set color-incubating [254 178 76]
  set color-asymptomatic [153 153 153]
  set color-symptomatic [255 0 0]
  set color-recovered [0 0 0]
end


to setup-network
  ask patches [ set pcolor white ]
  set-default-shape turtles "square"

  (ifelse
    Network = "Grid-4" [ setup-square 4 ]
    Network = "Grid-8" [ setup-square 8 ]
    Network = "Random" [ setup-simple-random ]
    Network = "Small World" [ setup-smallworld ]
    Network = "Scale Free" [ setup-scalefree ]
    Network = "Fractal" [ setup-serpienski ]
  )

;  nw:set-context (turtle-set susceptibles incubating symptomatic recovered) (link-set family-members friends colleagues)
  nw:set-context (turtle-set susceptibles incubating symptomatic recovered) edges
  find-clustering-coefficient
  do-plotting
end


to setup-population
  ask turtles [
    get-susceptible
    set age random 80
    set tested? false
  ]
  ask up-to-n-of headless-nb-nodes-initially-infected susceptibles [ get-symptomatic ]
end


;;;;;;;;;;;;;;;;;;;;;
;;;;; TIME STEP ;;;;;
;;;;;;;;;;;;;;;;;;;;;

to go
  ifelse virus-present?
  [
    set new-Asymp 0
    set new-Symp 0
    transmit-virus
    testing
    update-states
    tick
  ]
  [ stop ]
end


to transmit-virus
  ask (turtle-set incubating asymptomatic symptomatic) [
    let me1 self
    ask link-neighbors with [breed = susceptibles] [
      let me2 self
      if random-float 1 < headless-transmission-rate [
        get-incubating
        ask edge [who] of me1 [who] of me2 [ set color color-symptomatic ] ;WE COLOR LINKS TO SHOW CONTAGION PATH
      ]
    ]
  ]
end


to testing
  (ifelse
    TESTING-STRATEGY = "random" [ ask up-to-n-of headless-nb-tests-per-day turtles [ get-tested ] ]

    TESTING-STRATEGY = "symptomatic people" [ ask up-to-n-of headless-nb-tests-per-day symptomatic [ get-tested ] ]
  )
end


to get-tested
  (ifelse
    breed = susceptibles or breed = recovered [
      ifelse random-float 1 < headless-test-specificity
      [ set true-neg true-neg + 1 ]
      [ set false-neg false-neg + 1 ]
    ]

    breed = incubating or breed = asymptomatic or breed = symptomatic [
      ifelse random-float 1 < headless-test-sensitivity
      [ set true-pos true-pos + 1 ]
      [ set false-pos false-pos + 1 ]
    ]
  )
end


to update-states
  ask (turtle-set incubating asymptomatic symptomatic) [
    (ifelse
      state-duration > 0 [ set state-duration state-duration - 1 ]
      state-duration = 0 and (breed = symptomatic or breed = asymptomatic) [ get-recovered ]
      state-duration = 0 and breed = incubating [
        ifelse random 100 < headless-asymptomatic-proportion
        [ get-asymptomatic ]
        [ get-symptomatic ]
      ]
    )
  ]

  set total-nb-I total-nb-I + new-Asymp + new-Symp
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; EPIDEMIC STATES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to get-susceptible
  set breed susceptibles
  set color color-susceptible
  set state-duration -1
end

to get-incubating
  set breed incubating
  set color color-incubating
  set state-duration gamma-law headless-avg-incubation-duration 3
end

to get-asymptomatic
  set breed asymptomatic
  set color color-asymptomatic
  set state-duration gamma-law headless-avg-infectivity-duration 1

  set new-Asymp new-Asymp + 1
end

to get-symptomatic
  set breed symptomatic
  set color color-symptomatic
  set state-duration gamma-law headless-avg-infectivity-duration 1

  set new-Symp new-Symp + 1
end

to get-recovered
  set breed recovered
  set color color-recovered
  set state-duration -1
end


;;;;;;;;;;;;;;;;;;;;;
;;;;; REPORTERS ;;;;;
;;;;;;;;;;;;;;;;;;;;;

to-report gamma-law [avg var]
  let alpha avg * avg / var
  let lambda avg / var

  report floor random-gamma alpha lambda
end

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

to-report virus-present?
  report nb-I > 0
end



;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; SETUP NETWORK ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;;; REGULAR NETWORK ;;;

to setup-square [NB-Neighbors-Regular-Grid]
  ask patches with [pxcor mod 3 = 0 and pycor mod 3 = 0] [
    sprout 1 [ set color color-susceptible ]
  ]

  ifelse NB-Neighbors-Regular-Grid = 4
  [ ask turtles [ create-edges-with turtles in-radius 3 with [self != myself] ] ]
  [ ask turtles [ create-edges-with turtles in-radius 5 with [self != myself] ] ]
end



;;; RANDOM NETWORK ;;;

to setup-simple-random
  let num-edges (1.3 * max-nb-nodes)
  create-turtles max-nb-nodes [
    set color color-susceptible
    setxy random-xcor * 0.95 random-ycor * 0.95
    if any? turtles-here [ fd 1 ]
  ]

  ask turtles [ create-edges-with other turtles in-radius max-size-neighborhood ]

  while [count edges < num-edges] [
    ask one-of turtles [
      let choice (min-one-of (other turtles with [not link-neighbor? myself]) [distance myself])
      if choice != nobody [ create-edge-with choice ]
    ]
  ]

  ;to make sure no isolated subnets < 4 connected nodes remain
  ask turtles with [count link-neighbors < 4] [
    create-edge-with min-one-of (other turtles with [not link-neighbor? myself and count link-neighbors >= 3]) [distance myself]
  ]
end


;;; FRACTAL NETWORK ;;;
;;From Arnaud

; create a node and set its initial location and modulus
to setup-serpienski
  create-turtles 1 [
    set heading 0
    set color color-susceptible
    setxy 0 -1
    set modulus 0.5 * max-pycor
  ]
  while [count turtles < max-nb-nodes] [ create-serpienski nb-seeds-fractal ]
end

; draw the sierpinski tree
to create-serpienski [nb]
  ask turtles with [count edge-neighbors < 2] [
    repeat nb [
      grow-serpienski
      right  360 / nb  ; turn counter-clockwise to draw more legs
    ]
  ]
  tick
end

; ask the nodes to go forward by modulus, create a new node to
; draw the next iteration of sierpinski's tree, and return to its place
to grow-serpienski
  hatch 1 [
    fd modulus
    create-edge-with myself
    ifelse nb-seeds-fractal = 3
    [ set modulus (0.5 * modulus) ]  ; new node's modulus is half its parent's
    [
      ifelse nb-seeds-fractal = 5
      [ set modulus (0.4 * modulus) ]
      [ set modulus (0.3 * modulus) ]
    ]
  ]
end


;;; SMALL WORLD NETWORK ;;;
;Generates a Watts-Strogatz small-world networ using NW extension

to setup-smallworld
  nw:generate-watts-strogatz turtles edges max-nb-nodes 2 0.1 [
    set color color-susceptible
    fd 15
  ]
end


;;; SCALE FREE NETWORK ;;;
;;From NetLogo Library

to setup-scalefree
  ;; make the initial network of two nodes and an edge
  make-node nobody        ;; first node, unattached
  make-node turtle 0      ;; second node, attached to first node
  create-scalefree
end


to create-scalefree
  while [count turtles < max-nb-nodes] [
    ;; new edge is green, old edges are gray
    ask edges [ set color gray ]
    make-node find-partner         ;; find partner & use it as attachment
                                   ;; point for new node

    layout
  ]
end

;; used for creating a new node
to make-node [old-node]
  create-turtles 1 [
    set color color-susceptible
    set size nodes-size
    if old-node != nobody [
      create-edge-with old-node [ set color green ]
      ;; position the new node near its partner
      move-to old-node
      fd 1
    ]
  ]
end

to-report find-partner
  let total random-float sum [count edge-neighbors] of turtles
  let partner nobody
  ask turtles [
    let nc count edge-neighbors
    ;; if there's no winner yet...
    if partner = nobody [
      ifelse nc > total
      [ set partner self ]
      [ set total total - nc ]
    ]
  ]
  report partner
end

;; resize-nodes, change back and forth from size based on degree to a size of 1
to resize-nodes
  ifelse all? turtles [size <= 1]
  [
    ;; a node is a circle with diameter determined by
    ;; the SIZE variable; using SQRT makes the circle's
    ;; area proportional to its degree
    ask turtles [ set size sqrt count edge-neighbors ]
  ]
  [ ask turtles [ set size 1 ] ]
end

to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 20 [
    ;; the more nodes we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor count turtles
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles edges (1 / factor) (7 / factor) (1 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end


;;;;;;;;;;;;;;;;;;;;
;;;;; PLOTTING ;;;;;
;;;;;;;;;;;;;;;;;;;;

to do-plotting
  let max-degree max [count link-neighbors] of turtles
  set-current-plot "Degree Distribution"
  plot-pen-reset
  set-plot-x-range 0 (max-degree + 1)
  histogram [count link-neighbors] of turtles
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Clustering computations ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Inspired for Models Library ==> Networks ==> Small-World

to-report in-neighborhood? [ hood ]
  report ( member? end1 hood and member? end2 hood )
end


;; find the clustering coefficient and add to the aggregate for all iterations
to find-clustering-coefficient
  ifelse all? turtles [count link-neighbors <= 1]
  [
    ;; it is undefined
    ;; what should this be?
    set clustering-coefficient 0
  ]
  [
    let total 0
    ask turtles with [ count link-neighbors <= 1] [ set node-clustering-coefficient "undefined" ]
    ask turtles with [ count link-neighbors > 1] [
      let hood link-neighbors
      set node-clustering-coefficient (2 * count edges with [ in-neighborhood? hood ] /
        ((count hood) * (count hood - 1)) )
      ;; find the sum for the value at turtles
      set total total + node-clustering-coefficient
    ]
    ;; take the average
    set clustering-coefficient total / count turtles with [count link-neighbors > 1]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
462
10
1080
629
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
-30
30
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
35
196
405
413
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
54
106
259
139
max-nb-nodes
max-nb-nodes
10
1000
1000.0
10
1
NIL
HORIZONTAL

MONITOR
133
418
198
463
#Nodes
count turtles
17
1
11

MONITOR
62
417
127
462
#Edges
count edges
17
1
11

MONITOR
209
417
289
462
Density
(count edges * 2) / count turtles
2
1
11

SLIDER
55
147
260
180
nodes-size
nodes-size
0.3
1
1.0
0.1
1
NIL
HORIZONTAL

CHOOSER
13
50
258
95
NETWORK
NETWORK
"Grid-4" "Grid-8" "Random" "Small World" "Scale Free" "Fractal"
2

MONITOR
295
418
363
463
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
41
504
149
526
SIR MODEL
20
0.0
1

SLIDER
18
542
259
575
nb-nodes-initially-infected
nb-nodes-initially-infected
1
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
19
581
236
614
transmission-rate
transmission-rate
0
1
0.12
0.01
1
NIL
HORIZONTAL

BUTTON
317
540
381
574
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
486
645
865
962
Epidemic
Time
Number of cases
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Susceptible" 1.0 0 -16777216 true "" "set-plot-pen-color color-susceptible plot nb-S"
"Incubating" 1.0 0 -16777216 true "" "set-plot-pen-color color-incubating plot nb-Incub"
"Asymptomatic" 1.0 0 -16777216 true "" "set-plot-pen-color color-asymptomatic plot nb-Asymp"
"Symptomatic" 1.0 0 -16777216 true "" "set-plot-pen-color color-symptomatic plot nb-Symp"
"Recovered" 1.0 0 -16777216 true "" "set-plot-pen-color color-recovered plot nb-R"

SLIDER
18
666
275
699
avg-infectivity-duration
avg-infectivity-duration
0
30
21.0
1
1
days
HORIZONTAL

MONITOR
296
648
475
693
final % of infected people
total-nb-I / count turtles * 100
2
1
11

SLIDER
18
623
284
656
avg-incubation-duration
avg-incubation-duration
0
30
6.0
1
1
days
HORIZONTAL

PLOT
1121
218
1450
490
Age distribution
Age
NIL
0.0
81.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [age] of turtles"

CHOOSER
18
720
294
765
TESTING-STRATEGY
TESTING-STRATEGY
"random" "infected people"
0

SLIDER
18
773
300
806
nb-tests-per-day-per-1000
nb-tests-per-day-per-1000
0
20
7.5
0.5
1
NIL
HORIZONTAL

SLIDER
21
860
199
893
test-specificity
test-specificity
0
100
75.0
5
1
%
HORIZONTAL

SLIDER
19
818
197
851
test-sensitivity
test-sensitivity
0
100
90.0
5
1
%
HORIZONTAL

MONITOR
314
715
388
760
NIL
true-pos
17
1
11

MONITOR
387
715
461
760
NIL
false-pos
17
1
11

MONITOR
314
759
388
804
NIL
false-neg
17
1
11

MONITOR
387
759
461
804
NIL
true-neg
17
1
11

SLIDER
52
966
307
999
asymptomatic-proportion
asymptomatic-proportion
0
100
30.0
5
1
%
HORIZONTAL

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
