; Q3: simulateur central
; adapted for Q17 depistage



;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; GLOBAL VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  population-size
  nb-infected-initialisation
  %unreported-infections
  transmission-distance
  distanciation-distance
  probability-transmission
  %respect-distanciation
  infected-avoidance-distance
  proba-transmission-unreported-infected
  walking-angle
  speed
  previous-nb-new-infections-reported
  previous-nb-new-infections-asymptomatic
  current-nb-new-infections-reported
  current-nb-new-infections-asymptomatic
  transparency
  wall
  SIMULATIONS ; retro-compatibility (removed choice box from interface)

  ; new globals pour dépistage
  ;number-daily-tests ; how many tests can be performed each day
  total-tests       ; total tests performed
  negative-tests    ; tests that were negative
  unreported-sick   ; sick people not tested yet
  campaign-duration ; how many days to test the target population
  campaign-start    ; day (tick) when campaign started
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; AGENTS AND THEIR VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ citizens citizen ]


citizens-own [
  epidemic-state
  infection-date
  nb-other-infected
  nb-contacts
  respect-rules?
  quarantined?

  ; new for depistage
  age
  gender
  telework?
  tested?
  positive?
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; SCENARIO-DEPENDENT SETUP ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks

  ; new depistage: forcer le scénario 3c (supprimer le choix dans l'interface)
  set SIMULATIONS "3c"

  setup-globals
  setup-population


  if member? "2c" SIMULATIONS [ set-respect-rules ]

  set-explanations
  set-epidemic-plot
end

; setup du graphique
to set-epidemic-plot
  set-current-plot "Dynamique épidémique"
  set-plot-y-range 0 Nb-s
end



to setup-globals
  ;; generic setup for all SIMULATIONS
  set population-size 100
  set nb-infected-initialisation 1
  set transmission-distance 1
  set distanciation-distance 1.5
  set probability-transmission 1
  set %respect-distanciation 90
  set infected-avoidance-distance 2
  set walking-angle 50
  set speed 0.5
  set transparency 145
  set population-size 200 ; moved out of if-else (was identical for all cases)

  ;; specific setups for some SIMULATIONS, overwriting the generic one above
  (ifelse
    member? "3b" SIMULATIONS [
      set wall 0  ; moved in case
      set nb-infected-initialisation 5
    ]

    member? "3c" SIMULATIONS [
      set %unreported-infections 50
      set proba-transmission-unreported-infected 1
      set wall 5
    ]
  )
end


; initialisation of citizen agents
to setup-population
  create-citizens population-size [
    setxy random-xcor random-ycor
    set shape "circle white"
    set size 1.5
    set epidemic-state "Susceptible"
    set respect-rules? true
    set quarantined? false

    ; new depistage
    ; setup age, gender, telework
    ; todo: use realistic stats?
    set age random 100
    set gender item random 2 ["male" "female"]
    if-else random 2 = 0 ; about 50% of people work from home
    [set telework? true]
    [set telework? false]
    set tested? false
    set positive? false

    show-epidemic-state
  ]

  set-infected-initialisation
end



; initial number of infected = parameter
; initially one asymptomatic in addition to this number of infected
; Question: are there statistically more symptomatic or asymptomatic infected people?
to set-infected-initialisation
  ask n-of nb-infected-initialisation citizens [
    set epidemic-state "Infected"
    show-epidemic-state
  ]

  if member? "3c" SIMULATIONS [
    ask one-of citizens with [epidemic-state = "Susceptible"] [
      set epidemic-state "Asymptomatic Infected"
      show-epidemic-state
    ]
  ]
end


; decide who respects distanciation or not (respect=circle, disrespect=square)
to set-respect-rules
  ; init infected citizens to all disrespect rules (so that contagion can happen before they recover...)
  ask citizens with [epidemic-state = "Infected"] [
    set respect-rules? false
    set shape "square"
    set size 1.5
  ]

  ; then set a percentage of the other (susceptible) citizens (parameter) to disrespect distanciation rules (init value = respect)
  let nb-rulebreakers-susceptible population-size - round (%respect-distanciation * population-size / 100) - nb-infected-initialisation
  ask n-of nb-rulebreakers-susceptible citizens with [epidemic-state = "Susceptible"] [
    set respect-rules? false
    set shape "square"
    set size 1.5
  ]
end




;;;;;;;;;;;;;;;;;;;;;;
;;;;; PROCEDURES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;


;; performed at each step
to go
  ;; stop criterion: no more susceptible citizens
  if nb-S = 0 [
    show-asymptomatic-cases
    stop
  ]

  ;; update case counts
  update-previous-epidemic-counts

  ;; movement
  (ifelse
    member? "2" SIMULATIONS [ move-distanciation-citizens ]

    ;; FIXME: pour le dépistage, veut-on un évitement des infectés ou un respect de la distanciation?
    member? "3" SIMULATIONS [ avoid-infected ]

    ;; default case:
    [ move-randomly-citizens ]
  )

  ;; transmission
  ask citizens with [epidemic-state = "Susceptible"] [ get-virus ]

  update-current-epidemic-counts
  update-test-stats

  tick
end


;;;;;;;;;;;;;;;;;;;;;
;;;;; MOVEMENTS ;;;;;
;;;;;;;;;;;;;;;;;;;;;

;; move according to distanciation guidelines
to move-distanciation-citizens
  ask citizens [
    ifelse respect-rules?
    [
      let target min-one-of other citizens in-radius distanciation-distance [ distance myself ]
      ifelse is-agent? target
      [
        face target
        rt 180
        avoid-walls
        fd speed
      ]
      [
        set heading heading + random walking-angle - random walking-angle
        avoid-walls
        fd speed
      ]
    ]
    [
      set heading heading + random walking-angle - random walking-angle
      avoid-walls
      fd speed
    ]
  ]
end


;; move while avoiding infected agents (scenario 2)
to avoid-infected
  ask citizens [
    let target min-one-of other citizens with [epidemic-state = "Infected"] in-radius infected-avoidance-distance [distance myself]
    ifelse epidemic-state != "Infected" and is-agent? target
    [
      face target
      rt 180
      avoid-walls
    ]
    [
      set heading heading + random walking-angle - random walking-angle
      avoid-walls
    ]

    ifelse epidemic-state != "Infected"
    [ fd speed ]
    [ ifelse  member? "3c" SIMULATIONS [ quarantine-infected ] [ fd speed / 2 ] ]
  ]
end


;; quarantine infected agents (called in avoid-infected = scenario 3)
to quarantine-infected
  if not quarantined? [
    set shape "square"
    move-to min-one-of patches with [not any? citizens-here] [ pxcor ]
    set size 1
    set quarantined? true
  ]
end


;; move randomly (scenario 1)
to move-randomly-citizens
  ask citizens [
    set heading heading + random walking-angle - random walking-angle
    avoid-walls
    fd speed
  ]
end


;; avoid the edges of the world
to avoid-walls
  if abs [pxcor] of patch-ahead (wall + 1) = max-pxcor [ set heading (- heading) ]
  if abs [pycor] of patch-ahead 1 = max-pycor [ set heading (180 - heading) ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; VIRUS PROPAGATION ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; virus transmission
;; TODO: ajouter une durée d'incubation au moment de l'infection (tirer dans une loi GAMMA la durée)
;; random-gamma moyenne = 6 jours (variance de 1j) - durée contagiosité 21 jours (variance 1j)
;; variance a la mano by LN
to get-virus
  ; choose one random agent in transmission distance radius
  let target one-of other citizens in-radius transmission-distance with [epidemic-state = "Infected" or epidemic-state = "Asymptomatic Infected"]
  if is-agent? target
  [
    ; use a different transmission probability depending on target aegnt's symptoms
    ; TODO: age should influence probability as well
    if ([epidemic-state] of target = "Infected" and random-float 1 < probability-transmission)
    or
    ([epidemic-state] of target = "Asymptomatic Infected" and random-float 1 < proba-transmission-unreported-infected) [
      ifelse member? "3c" SIMULATIONS
      [
        ; probabilistic decision if the new infected should have symptoms
        ifelse random 100 > %unreported-infections
        [ set epidemic-state "Infected" ]
        [ set epidemic-state "Asymptomatic Infected" ]
      ]
      ; else (scenarios 1 or 2)
      [
        set epidemic-state "Infected"
        ask target [ set nb-other-infected nb-other-infected + 1 ]
      ]

      show-epidemic-state
      set infection-date ticks
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; TESTING STRATEGIES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; TODO: strategies de test par symptomes (echoue sur les asymptomatiques) vs serologique (détecte les guéris)
;       ajouter un selecteur pour le type de test à utiliser

to test-pop
  ; switch based on selected strategy, to determine WHO is tested
  ; TODO: first define target population, then check if not empty
  ; if empty, end of test campaign, display time it took
  ; if not empty, keep testing

  ; 0) lancement de la campagne
  if campaign-start = -1
  [
    set campaign-start ticks
  ]

  ; 1) define target population based on strategy
  ; take all untested people
  let target-population citizens with [tested? = false]
  ( ifelse
    ;STRATEGY = "random"  [set target-population citizens]
    STRATEGY = "older"   [set target-population target-population with [age >= 60]]
    STRATEGY = "workers" [set target-population target-population with [telework? = true]]
    STRATEGY = "symptomatic" [set target-population target-population with [epidemic-state = "Symptomatic"] ]
    ; default else
    []
  )

  ; FIXME empty? ok sur list mais pas sur agentset... comment convertir?
  if-else count target-population = 0

  ; 2a) end of test campaign
  ; remise à 0
  ; afficher les résultats: temps, nombre de tests consommés, combien sont négatifs, combien de malades on a ratés
  [
    ; show results
    show "total tests = " ; FIXME: displayed where?
    show total-tests
    show negative-tests
    show unreported-sick

    ; reinitialise campaign
    set campaign-duration ticks - campaign-start
    set campaign-start -1
    ask citizens with [tested? = true] [set tested? false]
  ]

  ; 2b) tester la population cible, au max du nombre de tests possibles aujourd'hui
  [
    ask n-of number-daily-tests target-population [test-one]
  ]

    stop
end
; TODO : depending on max number of tests, part of the target population cannot be tested
; monitor the number of days needed to test the entire target?

; called on each tested citizen
; TODO: test probabiliste -
to test-one
  set tested? true ; won't be tested again in the same campaign
  ; TODO: test should not be 100% ok
  if-else epidemic-state = "Symptomatic" [set positive? true] [set positive? false]
  ;il faut que certains symptomatiques soient non COVID : nouvel état ? attribut symptomes/etat de santé/comorbidités?
  set shape "triangle"
end

;;;;;;;;;;;;;;;;;;;
;;;;; UPDATES ;;;;;
;;;;;;;;;;;;;;;;;;;

to show-epidemic-state
  (ifelse
    epidemic-state = "Susceptible" [ set color lput transparency extract-rgb  green ]

    epidemic-state = "Infected"
    [
      set color lput transparency extract-rgb red
      if member? "3c" SIMULATIONS [ set shape "square" ]
    ]

    epidemic-state = "Asymptomatic Infected"
    [
      ifelse member? "3c" SIMULATIONS
      [ set color lput transparency extract-rgb blue ]
      [ set color lput transparency extract-rgb green ]
    ]

    epidemic-state = "Recovered" [ set color lput transparency extract-rgb gray ]
  )
end


to show-asymptomatic-cases
  ask citizens with [epidemic-state = "Asymptomatic Infected"]
  [ set color lput transparency extract-rgb blue ]
end


to update-previous-epidemic-counts
  set previous-nb-new-infections-reported nb-Ir
  set previous-nb-new-infections-asymptomatic nb-Inr
end


to update-current-epidemic-counts
set current-nb-new-infections-reported nb-Ir - previous-nb-new-infections-reported
set current-nb-new-infections-asymptomatic nb-Inr - previous-nb-new-infections-asymptomatic
end

; update test statistics
to update-test-stats
  set total-tests count citizens with [tested? = true]
  set negative-tests count citizens with [tested? = true and positive? = false]
  set unreported-sick count citizens with [tested? = false and epidemic-state != "Susceptible" and epidemic-state != "Recovered" ]
end


;;;;;;;;;;;;;;;;;;;;;
;;;;; REPORTERS ;;;;;
;;;;;;;;;;;;;;;;;;;;;

to-report nb-S
  report count citizens with [epidemic-state = "Susceptible"] ;/ population-size * 100
end

to-report nb-Ir
  report count citizens with [epidemic-state = "Infected"] ;/ population-size * 100
end

to-report nb-Inr
  report count citizens with [epidemic-state = "Asymptomatic Infected"] ;/ population-size * 100
end

to-report nb-I
  report count citizens with [epidemic-state = "Infected" or epidemic-state = "Asymptomatic Infected"] ;/ population-size * 100
end

to-report nb-R
  report count citizens with [epidemic-state = "Recovered"] ;/ population-size * 100
end



;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; EXPLANATIONS ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to set-explanations
  set EXPLICATION
    ; SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
    "Scénario plus subtil cette fois : certaines personnes infectées ne sont pas identifiables (en bleu, courbe Ib). Le virus se propage alors de manière insidieuse, alors même que les cas identifiés (en rouge, courbe Ia) sont systématiquement isolés en étant placés en quarantaine sur le côté gauche. Une meilleure connaissance de cette population non répertoriée est donc nécessaire, si l'on veut comprendre et maîtriser cette épidémie. Choisissez une stratégie de dépistage pour essayer d'identifier le maximum de malades avec un minimum de tests !"
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
1
1
1
ticks
30.0

BUTTON
594
412
688
467
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
691
413
786
466
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
972
226
Dynamique épidémique
Temps
Nombre total de cas
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"S" 1.0 0 -13840069 true "" "if nb-s > 0 [plot nb-S]"
"Ia" 1.0 0 -2674135 true "" "if nb-Ir > 0 [plot nb-Ir]"
"Ib" 1.0 0 -13791810 true "" "if nb-Inr > 0 [plot nb-Inr]"
"Ic" 1.0 0 -7500403 true "" "if SIMULATIONS = \"Simulation 2c : Le maillon faible\"\n [if any? citizens with [not respect-rules? and epidemic-state = \"Infected\"]\n [plot count citizens with [not respect-rules? and epidemic-state = \"Infected\"]]]"

PLOT
593
228
972
409
Nouveaux cas identifiés
Temps
Nombre de cas
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"I" 1.0 1 -2139308 true "" "plot current-nb-new-infections-reported\n +  current-nb-new-infections-asymptomatic"

INPUTBOX
2
411
591
569
explication
Scénario plus subtil cette fois : certaines personnes infectées ne sont pas identifiables (en bleu, courbe Ib). Le virus se propage alors de manière insidieuse, alors même que les cas identifiés (en rouge, courbe Ia) sont systématiquement isolés en étant placés en quarantaine sur le côté gauche. Une meilleure connaissance de cette population non répertoriée est donc nécessaire, si l'on veut comprendre et maîtriser cette épidémie. Choisissez une stratégie de dépistage pour essayer d'identifier le maximum de malades avec un minimum de tests !
1
1
String

TEXTBOX
794
414
1013
505
Mode d'emploi en 3 étapes :\n1 - Cliquez sur le bouton \"Initialiser\"\n2 - Cliquez sur le bouton \"Simuler\"\n3 - Choisissez une stratégie\n
12
63.0
1

CHOOSER
596
473
734
518
STRATEGY
STRATEGY
"random" "symptomatic" "older" "workers"
3

BUTTON
594
522
685
567
Tester
test-pop
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
694
521
751
566
#tests
total-tests
17
1
11

MONITOR
757
521
878
566
#malades inconnus
unreported-sick
17
1
11

MONITOR
885
520
958
565
#negatifs
negative-tests
17
1
11

SLIDER
755
480
942
513
number-daily-tests
number-daily-tests
0
100
50.0
1
1
NIL
HORIZONTAL

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
