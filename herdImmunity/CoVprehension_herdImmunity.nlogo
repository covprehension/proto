;extensions [vid] ; A virer de la version finale

globals
[
  population-size
  nb-infected-initialisation
  transmission-distance
  distanciation-distance
  probability-transmission
  %respect-distanciation
  infected-avoidance-distance
  walking-angle
  speed
  transparency
  contagion-duration ;; FA : Temporal

  ;; specific 3c
  %unreported-infections
  proba-transmission-unreported-infected
  wall

  ;; specific 4
;  init-number-of-recovered

  ;; metrics
  previous-nb-new-infections-reported
  previous-nb-new-infections-asymptomatic
  current-nb-new-infections-reported
  current-nb-new-infections-asymptomatic
]


breed
[
  citizens citizen
]

patches-own
[
  obstacle? ; 0 no 1 yes
]

citizens-own
[
  epidemic-state ;; Susceptible - Infected - Asymptomatic Infected - Recovered
  infection-date
  nb-other-infected
  nb-contacts
  respect-rules? ;; true or false
  quarantined? ;; true or false
  contagion-counter ; FA
]


to setup
  clear-all
  reset-ticks

  setup-globals

  create-citizens population-size
  [
    setxy random-xcor random-ycor
    set shape "circle white"
    set size 1.5
    set epidemic-state "Susceptible"
    set respect-rules? true
    set quarantined? false
    show-epidemic-state
  ]

  set-infected-initialisation

  if SIMULATIONS = "Simulation 2c : Le maillon faible"
  [ set-respect-rules ]

  set-explications

end


to setup-globals
  ;; generic setup for all SIMULATIONS
  set population-size 100
  set nb-infected-initialisation 1
  set transmission-distance 1
  set distanciation-distance 3
  set probability-transmission 0.5
  set %respect-distanciation 90
  set infected-avoidance-distance 2
  set walking-angle 50
  set speed 0.3
  set transparency 145
  set contagion-duration 14 * 4 ;FA

  ;; specific setups for some SIMULATIONS, overwriting the generic one above
  (ifelse
    SIMULATIONS = "Simulation 1b : Plus on est de fous..."
    or
    SIMULATIONS = "Simulation 2b : Bain de foule"
    [
      set population-size 500
    ]

    SIMULATIONS = "Simulation 3b : Des malades sur la piste de danse"
    [
      set population-size 400
      set nb-infected-initialisation 20
      set walking-angle 50 ;; HA même chose que cas général !
    ]

    SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
    [
      set population-size 500
      set %unreported-infections 50
      set Proba-transmission-unreported-infected 1
      set wall 5
    ]

    SIMULATIONS = "Simulation 4"
    [
      set population-size 600
;      set init-number-of-recovered 100
    ]
  )
end


to show-epidemic-state
  (ifelse
    epidemic-state = "Susceptible" [ set color lput transparency extract-rgb  green ]

    epidemic-state = "Infected"
    [
      set color lput transparency extract-rgb red
      if SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt" [ set shape "square" ]
    ]

    epidemic-state = "Asymptomatic Infected"
    [
      ifelse SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
      [ set color lput transparency extract-rgb blue ]
      [ set color lput transparency extract-rgb green ]
    ]

    epidemic-state = "Recovered" [ set color lput transparency extract-rgb gray ]
  )
end


to set-infected-initialisation
  ask n-of nb-infected-initialisation citizens
  [
    set epidemic-state "Infected"
    set contagion-counter contagion-duration ;FA
    set current-nb-new-infections-reported (current-nb-new-infections-reported + 1) ; FA
    show-epidemic-state
  ]

  (ifelse
    SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
    [
      ask one-of citizens with [epidemic-state = "Susceptible"]
      [
        set epidemic-state "Asymptomatic Infected"
        set contagion-counter contagion-duration ;FA
        set current-nb-new-infections-asymptomatic (current-nb-new-infections-asymptomatic + 1) ; FA
        show-epidemic-state
      ]
    ]

    SIMULATIONS = "Simulation 4"
    [
      ask n-of init-number-of-recovered citizens with [epidemic-state = "Susceptible"]
      [ become-recovered ]
    ]
  )
end

to become-recovered
  set epidemic-state "Recovered"
end


to set-respect-rules
  ask citizens with [epidemic-state = "Infected"]
  [
    set respect-rules? false
    set shape "square"
    set size 1.5
  ]

  let nb-rulebreakers-susceptible population-size - round (%respect-distanciation * population-size / 100) - nb-infected-initialisation
  ask n-of nb-rulebreakers-susceptible citizens with [epidemic-state = "Susceptible"]
  [
    set respect-rules? false
    set shape "square"
    set size 1.5
  ]
end


to go
  if nb-S = 0
  [
    ifelse SIMULATIONS = "Simulation 4"
    [ if nb-I = 0 [ show-asymptotic-cases stop ] ]
    [ show-asymptotic-cases stop ]
  ]

  update-previous-epidemic-counts

  (ifelse
    SIMULATIONS = "Simulation 2a : Gardons nos distances !"
    or
    SIMULATIONS = "Simulation 2b : Bain de foule"
    or
    SIMULATIONS = "Simulation 2c : Le maillon faible"
    [ move-distanciation-citizens ]

    SIMULATIONS = "Simulation 3a : Courage, fuyons !"
    or
    SIMULATIONS = "Simulation 3b : Des malades sur la piste de danse"
    or
    SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
    [ avoid-infected ]

    ;; else case:
    [ move-randomly-citizens ]
  )

  update-epidemics ; FA
;  connect
;  update-connections
  update-current-epidemic-counts

  ask citizens [ show-epidemic-state ] ;FA

  tick
end


to show-asymptotic-cases
  ask citizens with [epidemic-state = "Asymptomatic Infected"]
  [ set color lput transparency extract-rgb blue ]
end


to update-previous-epidemic-counts
  ;set previous-nb-new-infections-reported nb-Ir
  ;set previous-nb-new-infections-asymptomatic nb-Inr
  set current-nb-new-infections-reported 0 ; FA
  set current-nb-new-infections-asymptomatic 0 ; FA
end


to move-distanciation-citizens
  ask citizens
  [
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

    if epidemic-state = "Susceptible"
    [ get-virus ]
  ]
end


to avoid-walls
  if abs [pxcor] of patch-ahead (wall + 1) = max-pxcor
  [ set heading (- heading) ]
  if abs [pycor] of patch-ahead 1 = max-pycor
  [ set heading (180 - heading) ]
end


to get-virus
  let target one-of other citizens in-radius transmission-distance with [epidemic-state = "Infected" or epidemic-state = "Asymptomatic Infected"]
  if is-agent? target
  [
    if ([epidemic-state] of target = "Infected" and random-float 1 < probability-transmission)
    or
    ([epidemic-state] of target = "Asymptomatic Infected" and random-float 1 < proba-transmission-unreported-infected)
    [
      ifelse SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
      [
        ifelse random 100 > %Unreported-infections
        [
          set epidemic-state "Infected"
          set contagion-counter contagion-duration ;FA
          set current-nb-new-infections-reported (current-nb-new-infections-reported + 1);FA

        ]
        [
          set epidemic-state "Asymptomatic Infected"
          set contagion-counter contagion-duration ;FA
          set  current-nb-new-infections-asymptomatic (current-nb-new-infections-asymptomatic + 1);FA
        ]
      ]
      [
        set epidemic-state "Infected"
        set contagion-counter contagion-duration ;FA
        set current-nb-new-infections-reported (current-nb-new-infections-reported + 1) ;FA
        ask target [ set nb-other-infected nb-other-infected + 1 ]
      ]

      show-epidemic-state
      set infection-date ticks
    ]
  ]
end


to avoid-infected
  ask citizens
  [
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
    [ ifelse  SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt" [ quarantine-infected ] [ fd speed / 2 ] ]

    if epidemic-state = "Susceptible" [ get-virus ]
  ]
end


to move-randomly-citizens
  ask citizens
  [
    set heading heading + random walking-angle - random walking-angle
    avoid-walls
    fd speed
    if epidemic-state = "Susceptible" [ get-virus ]
  ]
end


to update-epidemics ;FA
  ask citizens with [ epidemic-state = "Infected" or epidemic-state = "Asymptomatic Infected" ][
    set contagion-counter (contagion-counter - 1)
    if contagion-counter <= 0 [ become-recovered ]
  ]
end


to connect
  ask citizens
  [ create-links-with other citizens in-radius transmission-distance ]
end


to update-connections
  ask links with [link-length > transmission-distance] [ die ]
end


to update-current-epidemic-counts
  ;FA set current-nb-new-infections-reported nb-Ir - previous-nb-new-infections-reported
  ;FA set  current-nb-new-infections-asymptomatic nb-Inr - previous-nb-new-infections-asymptomatic
end


to quarantine-infected
  if not quarantined?
  [
    set shape "square"
    move-to min-one-of patches with [not any? citizens-here] [ pxcor ]
    set size 1
    set quarantined? true
  ]
end



;###############################
;PATCHES
;###############################
to draw-obstacles
  if mouse-down?
  [
    ask patch mouse-xcor mouse-ycor
    [
      ask patches in-radius 1
      [
        set obstacle? 1
        set pcolor grey
      ]
    ]
  ]
end


;###############################
;REPORTERS
;###############################

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




;===============

;TECHNICAL ADDS

;===============


to fix-seed
  random-seed 47822
end

;to capture [title]
;vid:start-recorder
;vid:record-view
;  while [nb-S != 0]
;[ go
;  vid:record-view ]
;vid:save-recording title
;
;end
;
;
;to capture-duration [title duration]
;vid:start-recorder
;vid:record-view
;repeat duration
;[ go
;  vid:record-view ]
;vid:save-recording title
;
;end


;+++++++++++++++
;EXPLICATIONS
;+++++++++++++++

; A COMPLETER



to set-explications
  set explication (ifelse-value
    SIMULATIONS = "Simulation 1a : Le virus et nous"
    [ "Une personne infectée (en rouge) par le virus pourra le transmettre à d’autres personnes saines (en vert) avec qui elle entrera en contact au cours de son déplacement aléatoire. Les deux courbes de l'épidemie se croisent lorsque la moitié de la population est infectée." ]

    SIMULATIONS = "Simulation 1b : Plus on est de fous..."
    [ "Plus la densité de population et surtout de contacts entre individus est importante, plus le virus pourra se propager rapidement. La population étant plus nombreuse, le pic épidémique est plus visible (graphique du bas)." ]

    SIMULATIONS = "Simulation 2a : Gardons nos distances !"
    [ "Maintenir une distance minimale entre les individus (distanciation sociale) permet de bloquer la chaîne de transmission du virus. A condition que rien ne vienne perturber l'application de cette règle bien sûr." ]

    SIMULATIONS = "Simulation 2b : Bain de foule"
    [ "En situation de forte densité, l'application stricte de cette règle de distanciation devient plus difficile à mettre en oeuvre. Une fois les premières infections réalisées, le virus se propage inexorablement. D'où l'importance d'éviter les regroupements de population en situation de flambée épidémique." ]

    SIMULATIONS = "Simulation 2c : Le maillon faible"
    [ "La règle de distancation ne fonctionne que si tout le monde la respecte. Il suffit qu'une petite minorité ne joue pas le jeu (ici 10% des gens, représentés par des carrés) pour que le virus reprenne ses droits."]

    SIMULATIONS = "Simulation 3a : Courage, fuyons !"
    [ "Un exercice de pensée un brin dystopique ici : les personnes saines cherchent à éviter les personnes infectées, identifiables à leurs symptômes et dont les capacités physiques (vitesse de marche ici) sont réduites (NB : non, les rouges ne poursuivent pas les verts ! Chaque déplacement reste aléatoire, mais les verts cherchent en plus à éviter les rouges)."]

    SIMULATIONS = "Simulation 3b : Des malades sur la piste de danse"
    [ "Juste pour le plaisir, imaginons la situation suivante : des personnes malades surgissent dans un endroit bondé ! Si vous lancez plusieurs simulation, vous trouverez des configurations dans lesquelles la situation peut rapidement dégénérer (NB : non, les rouges ne poursuivent pas les verts ! Chaque déplacement reste aléatoire, mais les verts cherchent en plus à éviter les rouges)." ]

    SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
    [ "Scénario plus subtil cette fois : certaines personnes infectées ne sont pas identifiables (en bleu). Le virus se propage alors de manière insidieuse, alors même que les cas identifiés (en rouge) sont systématiquement isolés en étant placés en quarantaine sur le côté gauche. Une meilleure connaissance de cette population non répertoriée est donc nécessaire, si l'on veut comprendre et maîtriser cette épidémie." ]

    SIMULATIONS = "Simulation 4"
    [ "A FAIRE" ]
  )
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
461
672
516
Prêt  ?
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
593
520
672
569
Partez !
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
Epidémie
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
"S" 1.0 0 -13840069 true "" "if nb-S > 0 [plot nb-S]"
"Ia" 1.0 0 -2674135 true "" "if nb-Ir > 1 [plot nb-Ir]"
"Ib" 1.0 0 -13791810 true "" "if nb-Inr > 0 [plot nb-Inr]"
"R" 1.0 0 -7500403 true "" "if nb-R > 0 [plot nb-R]"

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

CHOOSER
593
411
972
456
SIMULATIONS
SIMULATIONS
"Simulation 1a : Le virus et nous" "Simulation 1b : Plus on est de fous..." "Simulation 2a : Gardons nos distances !" "Simulation 2b : Bain de foule" "Simulation 2c : Le maillon faible" "Simulation 3a : Courage, fuyons !" "Simulation 3b : Des malades sur la piste de danse" "Simulation 3c : L’arbre qui cache la forêt" "Simulation 4"
8

INPUTBOX
2
411
591
569
EXPLICATION
A FAIRE
1
1
String

TEXTBOX
682
469
975
563
Mode d'emploi en 3 étapes :\n1 - Choisissez votre scénario dans le menu déroulant\n2 - Cliquez sur le bouton \"Prêt\"\n3 - Cliquez sur le bouton \"Partez !\" \nVous n'avez plus qu'à observer la simulation et la relancer autant de fois que vous le souhaitez.
11
63.0
1

SLIDER
637
640
854
673
init-number-of-recovered
init-number-of-recovered
0
600
100.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
