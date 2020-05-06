; adapted from Q3: simulateur central
; Carole et Helene

;__includes [ "headless.nls" ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; GLOBAL VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  ;; GUI variables
  STRATEGY
  number-daily-tests
  testing-threshold

  population-size
  nb-infected-initialisation ; initial number of sick agents

  %unreported-infections ; % of sick who have no symptoms at all
  ; TODO: this % must also depend on age !
  ; proba-asymptomatic-old
  ; proba-asymptomatic-young
  ; ou facteur multiplicatif

  ; probability that an infected agent will infect a neighbour on same patch
  probability-transmission
  proba-transmission-asymptomatic
  proba-transmission-incubation ; probability that an incubating agent will infect a contact

  ;; movement
  infected-avoidance-distance
  speed

  infinity ;; default value for durations not in use

  ;; new globals pour dépistage
  on-going-testing? ;; is there a testing campaign currently
  nb-days-testing   ;; number of days elapsed since the beginning of the testing campaign
  nb-campaigns      ;; number of testing campaigns
;  total-tests       ;; total nb of tests performed so far (including people tested several times, counted several times)
  TP-tests          ;; total nb of true positive tests
  FP-tests          ;; total nb of false positive tests
  TN-tests          ;; total nb of true negative tests
  FN-tests          ;; total nb of false negative tests
;  negative-tests    ; tests that were negative
;  positive-tests    ; positive tests so far (to reconstruct epidemic curve)
  ;untested-sick     ; sick people not tested yet
;  tests-today       ; tests already performed today
  TP-today
  FP-today
  TN-today
  FN-today
;  positive-today
;  negative-today
  list-tests        ; remember %sick each day
  window-size       ; used for computing %sick over the last XXX days to smooth variations
                    ; over just today if = 1, over entire epidemic if too big, or over eg 7 days

  ; TODO : add a test validity duration
  ; ask citizens with tested? = true and when-tested < ticks - validity-duration [ set tested? false ]

  ; mean and variance for random-gamma determining incubation and infection durations
  incubation-mean
  incubation-variance
  infection-mean
  infection-variance

  ; caracteristics of test (specificity / sensitivity)
  proba-false-pos      ; 0 = high specificity (all detected are sick) / 100 = too sensitive (everybody is positive)
  proba-false-neg      ; 0 = high sensitivity (all sick are detected) / 100 = too specific (everybody is negative)

  ;; metrics
  nb-new-infections
;  nb-new-Asymp
;  nb-new-I
;  total-nb-Asymp
  total-nb-infected
;  total-nb-Inf

  ;; colors
  color-susceptible
  color-incubating
  color-asymptomatic
  color-symptomatic
  color-recovered
  transparency
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; AGENTS AND THEIR VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ citizens citizen ]


citizens-own [
  epidemic-state
  ; ticks when got infected
  infection-date
  ; to trigger switch of epidemic-status (not probabilistic but after duration is over)
  incubation-duration
  infection-duration
  ; shortcut for incubating / symptomatic / asymptomatic
  infected?
  ; quarantined agents are isolated and cannot infect neighbours
  quarantined?

  ; demographics for specific tests
  age
  gender
  telework?
  ; test results
  tested?       ; was already tested
  when-tested   ; date of last test (if test expires)
  positive?     ; result of test (can be wrong)
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; SCENARIO-DEPENDENT SETUP ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all

  random-seed 2020

  setup-globals
  setup-GUI
  setup-world
  reset-ticks
  setup-population

  set-explanations
end


;; generic setup
to setup-globals
  set infinity 99999
  set population-size 3000

  ; TODO: scenarios with a high value here to show difficulty of testing when it's too late
  ;; no need now there is a slider for starting the campaign
  set nb-infected-initialisation 1

  ; probabilities of transmission wrt epidemic-state of transmitter
  set probability-transmission 0.03
  set proba-transmission-asymptomatic 0.03
  set proba-transmission-incubation 0.03
  ; proba to (not) have symptoms once infected - TODO: should depend on age
  ; FIXME: find exact statistics about proportions of symptomatic / asymptomatic (by age if possible)
  set %unreported-infections 30

  ; duration of incubation and infection (random-gamma init)
  set incubation-mean 6
  set incubation-variance 3
  set infection-mean 21
  set infection-variance 1

  ;; movement
  set speed 1
  set infected-avoidance-distance 1

  ; tests counters
  set on-going-testing? false
  set nb-days-testing 0    ; number of days for which testing occured
  set nb-campaigns 0
;  set total-tests 0        ; total over the entire simulation / epidemics
  set TP-tests 0
  set FP-tests 0
  set TN-tests 0
  set FN-tests 0
;  set negative-tests 0
;  set positive-tests 0
  set list-tests []        ; list of %sick (% of positive tests daily)
  set window-size 7        ; size of sliding window for mean of %sick (smoothing factor)

  ;; features of test: specificity/sensitivity
  set proba-false-pos 0.1
  set proba-false-neg 0.1

  ;; metrics
;  set total-nb-Asymp 0
  set total-nb-infected 0
;  set total-nb-Inf 0

  ;; colors
  set color-susceptible [0 153 255]
  set color-incubating [254 178 76]
  set color-asymptomatic [153 153 153]
  set color-symptomatic [255 0 0]
  set color-recovered [0 0 0]
  set transparency 145
end


;; setup the GUI variables as global variables
;; useful for headless mode and for translation of the interface
to setup-GUI
  set STRATEGY TESTING-STRATEGY
  set number-daily-tests number-daily-tests-per-10000-persons * population-size / 10000
  set testing-threshold start-testing-threshold
end


;; resize the world to have (nb-contacts + 1) agents on a patch, on average
to setup-world
  let nb-contacts 10
  let width sqrt (population-size / (nb-contacts + 1))
  let max-cor floor ((width - 1) / 2)
  resize-world (- max-cor) (max-cor) (- max-cor) (max-cor)
  ask patches [ set pcolor white ]
end


; initialisation of citizen agents
to setup-population
  set-default-shape citizens "circle"

  create-citizens population-size [
    setxy random-xcor random-ycor
    set size 0.3
    get-susceptible

    ; TODO: add proba to respect self-quarantine when tested positive?
    ; this respect could depend on trust, itself depending on number of wrong quarantines
    set quarantined? false
    set tested? false
    set positive? false

    ; setup age, gender, telework at random ( TODO: use realistic stats? )
    set age random 100                           ; FIXME integer age, or string category school / work / retired ?
    set gender item random 2 ["male" "female"]
    ifelse age < 20 or age > 65 or random 2 = 0
    [ set telework? true ]   ; about 50% of people work from home + kids + retired
    [ set telework? false ]  ; the rest has to work outside
  ]

  ; set some agents to be initially infected (incubation phase) to start the epidemics
  ask n-of nb-infected-initialisation citizens with [not telework?] [ get-incubating ]
end




;;;;;;;;;;;;;;;;;;;;;;
;;;;; PROCEDURES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;

;; performed at each step
to go
  ;; stop criterion
  ;; virus-present? is a reporter testing whether there are still some infected people
  ifelse virus-present?
  [
    reset-counters

    ;; movement (options: move-distanciation-citizens, avoid-infected, move-randomly-citizens)
    avoid-infected

    ;; transmission
    virus-transmission

    test-pop

    ; update new counters and monitors
    update-states             ;; update epidemic states all at once
    update-counters

    ; next step
    tick
  ]
  ; once virus is extinct, stop
  [ stop ]
end



;;;;;;;;;;;;;;;;;;;;;
;;;;; MOVEMENTS ;;;;;
;;;;;;;;;;;;;;;;;;;;;

to move-randomly [my-speed]
  set heading random 360
  forward my-speed
end

;; move while avoiding infected agents (scenario 2 + this simulation)
to avoid-infected
  ; people in telework do not move at all
  ; TODO: add a proba to go out for shopping every now and then
  ask citizens with [not telework? and not quarantined?] [
    ; movement speed based on infection status
    ; infected people move slower and randomly
    ifelse epidemic-state = "Symptomatic"
    [ move-randomly speed / 2 ]
    ; non-infected people avoid infected people
    [
      ; closest infected neighbour in radius
      let target min-one-of other citizens with [epidemic-state = "Symptomatic"] in-radius infected-avoidance-distance [distance myself]
      ; if there is someone infected around: avoid
      ifelse is-agent? target
      [
        face target
        right 180
        forward speed
      ]
      ; otherwise move randomly
      [ move-randomly speed ]
    ]
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PUT AGENTS IN QUARANTINE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; quarantine an infected agent (was called in avoid-infected = scenario 3c)
;; new: quarantined on the spot (not moved to the side) but other agents will avoid it
to quarantine-infected
  if not quarantined? [
    set shape "square"
    set quarantined? true
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; VIRUS PROPAGATION ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; virus transmission to susceptibles only
to virus-transmission
  ask citizens with [infected? and not quarantined?] [
    ; use a different transmission probability depending on agent's symptoms
    let proba-trans (ifelse-value
      epidemic-state = "Symptomatic"  [ probability-transmission ]
      epidemic-state = "Asymptomatic" [ proba-transmission-asymptomatic ]
      ;; progressively more contagious with time
      epidemic-state = "Incubating"   [ probability-transmission * (ticks - infection-date) / incubation-duration ]
    )

    ;; my contacts are the other turtles on the same patch as me
    ask other turtles-here with [epidemic-state = "Susceptible"] [
      ; also based on age of receiver of virus (older are more exposed)
;      set proba-trans proba-trans * (1 + age / 300)  ; totally empirical multiplying factor

      ;; each contact can be infecting
      if random-float 1 < proba-trans [ get-incubating ]
    ]
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; TESTING STRATEGIES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; TODO: ajouter un selecteur du type de test: symptomes (echoue sur les asymptomatiques) vs serologique (détecte les guéris)
; TODO: expiry date of previous test

to test-pop
  (ifelse
    ;; if not testing currently and proportion of infected above the threshold and there are people to test
    not on-going-testing? and
    (nb-to-prop nb-I population-size) > testing-threshold and
    any? target-population [
      ;; start a testing campaign
      set on-going-testing? true
      set nb-campaigns nb-campaigns + 1
      ;; test the target population
      ask up-to-n-of number-daily-tests target-population [ test-one ]
    ]

    ;; if testing is on-going
    on-going-testing? [
      set nb-days-testing nb-days-testing + 1

      ;; are there people to test?
      ;; TODO find a better stopping criterion, not working well for neighbours
      ifelse any? target-population
      ;; continue the campaign
      [ ask up-to-n-of number-daily-tests target-population [ test-one ] ]
      ;; stop the campaign
      [
        set on-going-testing? false
        set nb-days-testing 0
        stop-campaign
      ]
    ]
  )
end


;; choose target population based on selected strategy: WHO exactly is tested
to-report target-population
  let target citizens with [not tested? and epidemic-state != "Recovered"]
  (ifelse
    ; test randomly among the untested population
    STRATEGY = "random"      [ report target ]
    ; test only "at risk" / older people (some are still working, most are retired)
    STRATEGY = "older"       [ report target with [age >= 60] ]
    ; test only people who work outside of home
    STRATEGY = "workers"     [ report target with [not telework?] ]
    ; test only people with symptoms: symptomatic infected state (+ TODO a random number of susceptible people with symptoms but just a flu)
    STRATEGY = "symptomatic" [ report target with [epidemic-state = "Symptomatic"] ]
    ; test neighbours (same patch) of agents already tested positive
    STRATEGY = "neighbours"  [
      ifelse not any? citizens with [tested?]
      ;; if no one was tested yet test randomly
      [ report target ]
      ;; otherwise test the neighbours
      [ report target with [any? other citizens-here with [positive?]] ]
    ]
  )
end


to stop-campaign
  ; Here people can be retested again, once a campaign is finished
  ; TODO: parameter for expiry duration of previous test -> retest when previous test is too old
  ask citizens with [tested?] [
    if not quarantined? [ set shape "circle" ]
    set tested? false
    set positive? false
  ]
end


; called on each tested citizen
; TODO: probabilities of detection should depend on infection status? (could add a weight, or a viral charge)
to test-one
  ;; update agent
  set tested? true ; won't be tested again in the same campaign
  set shape "triangle"
  set when-tested ticks

  ;; test result
  ifelse infected?
  ; if agent is infected
  [
    ifelse random-float 1 < proba-false-neg
    ; false negative
    [
      set positive? false
      set FN-today FN-today + 1
    ]
    ; true positive
    [
      set positive? true
      set TP-today TP-today + 1
    ]
  ]
  ; if agent is NOT infected / is recovered
  [
    ifelse random-float 1 < proba-false-pos
    ; false positive
    [
      set positive? true
      set FP-today FP-today + 1
    ]
    ; true negative
    [
      set positive? false
      set TN-today TN-today + 1
    ]
  ]

  ;; consequences of positive testing (previously selected by switches in interface)
  if positive? [
    quarantine-infected
    set telework? true
  ]

  ; update counters
;  set total-tests total-tests + 1
;  set tests-today tests-today + 1
;  ifelse positive?
;  [
;;    set positive-tests positive-tests + 1
;    set positive-today positive-today + 1
;  ]
;  [
;;    set negative-tests negative-tests + 1
;    set negative-today negative-today + 1
;  ]
end



;;;;;;;;;;;;;;;;;;;
;;;;; UPDATES ;;;;;
;;;;;;;;;;;;;;;;;;;

to update-states
  ;; go from incubation to either symptomatic or asymptomatic
  ask citizens with [epidemic-state = "Incubating" and
                     ticks > infection-date + incubation-duration] [
    ; probability to be (a)symptomatic
    ifelse random 100 < %unreported-infections
    [ get-asymptomatic ]
    [ get-symptomatic ]
  ]

  ;; go from (a)symptomatic to recovered
  ;; FIXME: better proba to recover when asymptomatic?
  ;; FIXME: add new states: hospital, icu, dead? only useful if changes the proba to recover when tested early enough
  ask citizens with [(epidemic-state = "Asymptomatic" or epidemic-state = "Symptomatic") and
                     ticks > infection-date + infection-duration] [
    get-recovered
  ]
end

; called in go at start of turn
to reset-counters
  set TP-today 0
  set FP-today 0
  set TN-today 0
  set FN-today 0
;  set positive-today 0
;  set negative-today 0
;  set tests-today 0

  set nb-new-infections 0
;  set nb-new-Asymp 0
;  set nb-new-I 0
end


; called in go after movement, transmission, testing
to update-counters
  set TP-tests TP-tests + TP-today
  set FP-tests FP-tests + FP-today
  set TN-tests TN-tests + TN-today
  set FN-tests FN-tests + FN-today
;  set positive-tests positive-tests + positive-today
;  set negative-tests negative-tests + negative-today
;  set total-tests total-tests + tests-today

  ; end of ONE DAY of tests, store % of positive tests
  let %positive-tests-today nb-to-prop positive-today tests-today
  ; put at end of list
  set list-tests lput %positive-tests-today list-tests
  ; if list over window size, pop start
  if length list-tests > window-size [ set list-tests but-first list-tests ]

  set total-nb-infected total-nb-infected + nb-new-infections
;set total-nb-Asymp total-nb-Asymp + nb-new-Asymp
;set total-nb-I total-nb-I + nb-new-I
;set total-nb-Inf total-nb-Asymp + total-nb-I
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; EPIDEMIC STATES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; récapitule tous les états épidémiques et les variables agent associées
to get-susceptible
  set epidemic-state "Susceptible"
  set color lput transparency color-susceptible
  set infection-date infinity
  set incubation-duration infinity
  set infection-duration infinity
  set infected? false
end

to get-incubating
  set epidemic-state "Incubating"
  set color lput transparency color-incubating
  set infection-date ticks
  set incubation-duration gamma-law incubation-mean incubation-variance
  set infection-duration infinity
  set infected? true

  set nb-new-infections nb-new-infections + 1
end

to get-asymptomatic
  set epidemic-state "Asymptomatic"
  set color lput transparency color-asymptomatic
  set infection-date ticks
  set incubation-duration infinity
  set infection-duration gamma-law infection-mean infection-variance
  set infected? true

;  set nb-new-Asymp nb-new-Asymp + 1
end

to get-symptomatic
  set epidemic-state "Symptomatic"
  set color lput transparency color-symptomatic
  set infection-date ticks
  set incubation-duration infinity
  set infection-duration gamma-law infection-mean infection-variance
  set infected? true

;  set nb-new-I nb-new-I + 1
end

to get-recovered
  set epidemic-state "Recovered"
  set color lput transparency color-recovered
  set infection-date infinity
  set incubation-duration infinity
  set infection-duration infinity
  set infected? false
  set quarantined? false
  if not tested? [ set shape "circle" ]
end



;;;;;;;;;;;;;;;;;;;;;
;;;;; REPORTERS ;;;;;
;;;;;;;;;;;;;;;;;;;;;

;;; UTILS ;;;

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


;;; TRUE VALUES ;;;

to-report nb-S
  report count citizens with [epidemic-state = "Susceptible"]
end

to-report nb-Incub
  report count citizens with [epidemic-state = "Incubating"]
end

to-report nb-Symp
  report count citizens with [epidemic-state = "Symptomatic"]
end

to-report nb-Asymp
  report count citizens with [epidemic-state = "Asymptomatic"]
end

to-report nb-R
  report count citizens with [epidemic-state = "Recovered"]
end

; exact nb of people sick in population, to compare with reconstructed value from tests
to-report nb-I
  report nb-Symp + nb-Asymp + nb-Incub
end

; boolean reporter
to-report virus-present?
  report nb-I > 0
end


;;; TEST RESULTS ;;;

;; new tests
to-report positive-today
  report TP-today + FP-today
end

to-report negative-today
  report TN-today + FN-today
end

to-report tests-today
  report positive-today + negative-today
end


;; total nb of tests
to-report positive-tests
  report TP-tests + FP-tests
end

to-report negative-tests
  report TN-tests + FN-tests
end

to-report total-tests
  report positive-tests + negative-tests
end

;; number of tests needed to test the whole target population
to-report missing-tests
  report count target-population - number-daily-tests
end


;;; ESTIMATING NB OF CASES ;;;

; TODO new reporter for bar chart with moving window size, mean from list of daily %sick
to-report sliding-mean
  report mean list-tests
end

; untested infected = "missed" tests
to-report nb-untested-infected
  report count citizens with [infected? and not tested?]
end

to-report undetected-sick
  report count citizens with [infected? and (not tested? or not positive?)]
end


;; equivalent to nb-to-prop positive-tests total-tests
; supposed % of people sick in total population based on tests
;to-report estim-%sick  ; to reconstruct epidemic curve
;  ;let nb-pos count citizens with [tested? and positive?]
;  ;show (word "nb pos = " nb-pos)
;  ;let %test 100 * nb-pos / nb-Tests  ; % de tests positifs
;  ;show (word "% tested = " %test)
;  ; rapporter au total
;  ;let supposed-pos nb-pos * 100 / %test
;  ;show (word "estim = " supposed-pos)
;  ;report supposed-pos
;
;  ;show (word "nb pos = " positive-tests)
;  ;show (word "nb tot = " total-tests)
;  ;show "*****"
;  ifelse total-tests = 0
;  [ report 0 ]
;  [ report 100 * positive-tests / total-tests ]
;end

;; equivalent to nb-to-prop nb-I population-size
; real % of people sick in population
;to-report real-%sick
;  ifelse population-size = 0 [ report 0 ] [ report nb-I * 100 / population-size ]
;end





;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; EXPLANATIONS ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to set-explanations
  set EXPLICATION ""
    ; SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
;    "Scénario plus subtil cette fois : certaines personnes infectées ne sont pas identifiables (en bleu, courbe Ib). Le virus se propage alors de manière insidieuse, alors même que les cas identifiés (en rouge, courbe Ia) sont systématiquement isolés en étant placés en quarantaine sur le côté gauche. Une meilleure connaissance de cette population non répertoriée est donc nécessaire, si l'on veut comprendre et maîtriser cette épidémie. Choisissez une stratégie de dépistage pour essayer d'identifier le maximum de malades avec un minimum de tests !"
end
@#$#@#$#@
GRAPHICS-WINDOW
702
10
1310
619
-1
-1
40.0
1
10
1
1
1
0
0
0
1
-7
7
-7
7
1
1
1
ticks
30.0

BUTTON
21
10
87
49
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
90
11
158
48
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
19
384
390
577
Dynamique épidémique
Jours
% cas
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Personnes en incubation" 1.0 0 -16777216 true "" "set-plot-pen-color color-incubating plot nb-to-prop nb-Incub population-size"
"Personnes asymptomatiques" 1.0 0 -16777216 true "" "set-plot-pen-color color-asymptomatic plot nb-to-prop nb-Asymp population-size"
"Personnes symptomatiques" 1.0 0 -16777216 true "" "set-plot-pen-color color-symptomatic plot nb-to-prop nb-Symp population-size"

PLOT
18
582
236
798
Nouvelles infections
Jours
Nombre de cas
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"Personnes asymptomatiques" 1.0 1 -16777216 true "" "set-plot-pen-color color-incubating plot nb-new-infections"

INPUTBOX
415
109
557
191
explication
NIL
1
1
String

TEXTBOX
194
10
413
101
Mode d'emploi en 3 étapes :\n1 - Choisissez une stratégie\n2 - Cliquez sur le bouton \"Initialiser\"\n3 - Cliquez sur le bouton \"Simuler\"\n\n
12
25.0
1

CHOOSER
22
53
181
98
TESTING-STRATEGY
TESTING-STRATEGY
"random" "symptomatic" "older" "workers" "neighbours"
0

MONITOR
21
181
78
226
#tests
total-tests
0
1
11

MONITOR
165
179
246
224
#undetected
nb-untested-infected
17
1
11

MONITOR
83
182
159
227
#negative
negative-tests
0
1
11

SLIDER
22
101
396
134
number-daily-tests-per-10000-persons
number-daily-tests-per-10000-persons
0
30
15.0
1
1
tests
HORIZONTAL

SLIDER
20
140
258
173
start-testing-threshold
start-testing-threshold
0
50
2.0
1
1
%
HORIZONTAL

BUTTON
383
10
521
43
execution time
setup\nreset-timer\nwhile [virus-present?] [ go ]\nshow timer
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
393
384
694
576
Reconstructed epidemic curve
Days
% cases
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Estimated % infected" 1.0 0 -8630108 true "plot 0" "plot nb-to-prop positive-tests total-tests"
"Real % infected" 1.0 0 -2674135 true "plot 0" "plot nb-to-prop nb-I population-size"
"sliding7" 1.0 0 -13840069 true "" "if ticks > window-size [ plot sliding-mean ]"

PLOT
241
582
694
798
Estimated nb of infected
Days
%
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Untested and infected" 1.0 0 -5825686 true "" "plot nb-to-prop nb-untested-infected nb-I"
"Unnecessary quarantines" 1.0 0 -7500403 true "" "plot nb-to-prop FP-tests positive-tests"

MONITOR
410
281
524
326
NIL
nb-days-testing
0
1
11

PLOT
18
804
349
1004
Tests results
Days
% tests
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"True positive" 1.0 0 -16777216 true "" "plot nb-to-prop TP-tests total-tests"
"False positive" 1.0 0 -7500403 true "" "plot nb-to-prop FP-tests total-tests"
"True negative" 1.0 0 -2674135 true "" "plot nb-to-prop TN-tests total-tests"
"False negative" 1.0 0 -955883 true "" "plot nb-to-prop FN-tests total-tests"

MONITOR
21
238
130
283
NIL
TP-tests
0
1
11

MONITOR
130
238
239
283
NIL
FP-tests
17
1
11

MONITOR
21
283
130
328
NIL
FN-tests
0
1
11

MONITOR
130
283
239
328
NIL
TN-tests
0
1
11

MONITOR
21
328
130
373
sensitivity
TP-tests / (TP-tests + FN-tests) * 100
2
1
11

MONITOR
130
328
239
373
specificity
TN-tests / (FP-tests + TN-tests) * 100
2
1
11

MONITOR
239
238
391
283
positive predictive value
TP-tests / positive-tests * 100
2
1
11

MONITOR
239
283
391
328
negative predictive value
TN-tests / negative-tests * 100
2
1
11

MONITOR
260
180
403
225
% recovered people
nb-to-prop nb-R population-size
2
1
11

MONITOR
417
237
522
282
NIL
nb-campaigns
1
1
11

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

computer workstation
false
0
Rectangle -7500403 true true 60 45 240 180
Polygon -7500403 true true 90 180 105 195 135 195 135 210 165 210 165 195 195 195 210 180
Rectangle -16777216 true false 75 60 225 165
Rectangle -7500403 true true 45 210 255 255
Rectangle -10899396 true false 249 223 237 217
Line -16777216 false 60 225 120 225

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
