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
  ;number-daily-tests ; how many tests can be performed each day (interface slider)
  total-tests       ; total tests performed
  negative-tests    ; tests that were negative
  untested-sick     ; sick people not tested yet
  campaign-duration ; how many days to test the target population
  campaign-start    ; day (tick) when campaign started
  tests-today       ; tests already performed today
  
  proba-transmission-incubation ; probability that an incubating agent will infect a contact
  infection-mean
  infection-variance
  incubation-mean
  incubation-variance
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; AGENTS AND THEIR VARIABLES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ citizens citizen ]


citizens-own [
  epidemic-state
  infection-date     ; ticks when got infected
  ;nb-other-infected ; was for scenarios 1-2
  nb-contacts
  respect-rules?
  quarantined?

  ; new for depistage
  age
  gender
  telework?
  tested?
  positive?
  incubation-duration
  infection-duration
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; SCENARIO-DEPENDENT SETUP ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks

  ; new depistage: forcer le scénario 3c (supprimer le choix dans l'interface)
  ;set SIMULATIONS "3c"

  setup-globals
  setup-population


  ;if member? "2c" SIMULATIONS [ set-respect-rules ]

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
  set wall 5
  set %respect-distanciation 90
  set infected-avoidance-distance 2
  set walking-angle 50
  set speed 0.5
  set transparency 145
  set population-size 200
  set %unreported-infections 50
  
  ; for now probability of transmission is the same whatever the source's status
  set probability-transmission 1
  set proba-transmission-unreported-infected 1
  set proba-transmission-incubation 1
  
  set incubation-mean 60
  set incubation-variance 30
  set infection-mean 210
  set infection-variance 10
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
    ; setup age, gender, telework : TODO: use realistic stats?
    set age random 100
    set gender item random 2 ["male" "female"]
    if-else random 2 = 0 ; about 50% of people work from home
    [set telework? true]
    [set telework? false]
    set tested? false
    set positive? false

    ; change shape based on infection status
    show-epidemic-state
  ]

  set-infected-initialisation
end


; set some agents to be initially infected to start the epidemics
; FIXME: find exact  statistically more symptomatic or asymptomatic infected people?
to set-infected-initialisation
  ; initial number of infected = parameter
  ask n-of nb-infected-initialisation citizens [
    set epidemic-state "Infected"
    set infection-duration infection-mean
    set telework? false
    show-epidemic-state
  ]

  ; initially one asymptomatic in addition to this number of infected
  ask one-of citizens with [epidemic-state = "Susceptible"] [
    set epidemic-state "Asymptomatic Infected"
    set infection-duration infection-mean
    set telework? false
    show-epidemic-state
  ]
end


; decide who respects distanciation or not (respect=circle, disrespect=square)
to set-respect-rules
  ; init infected citizens to all disrespect rules (so that contagion can happen before they recover...)
  ask citizens with [epidemic-state = "Infected"] [
    disrespect
  ]

  ; then set a percentage of the other (susceptible) citizens (parameter) to also disrespect distanciation rules (init value = respect)
  let nb-rulebreakers-susceptible population-size - round (%respect-distanciation * population-size / 100) - nb-infected-initialisation
  ask n-of nb-rulebreakers-susceptible citizens with [epidemic-state = "Susceptible"] [
    disrespect
  ]
end

to disrespect
  set respect-rules? false
  set shape "square"
  set size 1.5
end


;;;;;;;;;;;;;;;;;;;;;;
;;;;; PROCEDURES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;


;; performed at each step
to go
  ; full test capacity available again every morning
  set tests-today 0
  
  ;; stop criterion: no more susceptible citizens
  if nb-S = 0 [
    show-asymptomatic-cases
    stop
  ]

  ;; update previous case counts
  update-previous-epidemic-counts

  ;; movement
  ;; FIXME: pour le dépistage, veut-on un évitement des infectés ou un respect de la distanciation?
  ;; movement options: move-distanciation-citizens, avoid-infected, move-randomly-citizens
  avoid-infected
  
  ;; transmission - TODO multiple phases
  ;;ask citizens with [epidemic-state = "Susceptible"] [ get-virus ]
  propagate-epidemics
  
  ; update new counters and monitors
  update-current-epidemic-counts
  update-test-stats

  tick
end


;;;;;;;;;;;;;;;;;;;;;
;;;;; MOVEMENTS ;;;;;
;;;;;;;;;;;;;;;;;;;;;

;; move according to distanciation guidelines = avoid all (scenario 3, not used here)
to move-distanciation-citizens
  ask citizens [
    ifelse respect-rules?
    [
      ; find the closest agent in distanciation radius (1.5)
      let target min-one-of other citizens in-radius distanciation-distance [ distance myself ]
      ifelse is-agent? target [ avoid-target target speed ]
      ; elif no agent to avoid
      [ random-walk-one speed ]
    ]
    ; elif disrespect distanciation rules
    [ random-walk-one speed ]
  ]
end


; move away from given target
to avoid-target [toto spd]
  face toto
  rt 180
  avoid-walls
  fd spd
end


;; move while avoiding infected agents (scenario 2 + this simulation)
to avoid-infected
  ; people in telework do not move at all
  ; TODO: add a proba to go out for shopping every now and then
  ask citizens with [telework? = false] [
    ; movement speed based on infection status (infected people move slower)
    let my-speed speed
    if epidemic-state = "Infected" [set my-speed speed / 2 ]
    
    ; closest infected agent around me in avoidance radius (=2)
    let target min-one-of other citizens with [epidemic-state = "Infected"] in-radius infected-avoidance-distance [distance myself]
    ; if I am not infected myself, turn around to avoid it
    ifelse epidemic-state != "Infected" and is-agent? target
    [ avoid-target target my-speed ]
    ; if nothing to avoid or I am also infected: walk randomly
    [ random-walk-one my-speed ]
  ]
end

;; move randomly (scenario 1)
to move-randomly-citizens
  ask citizens [
    random-walk-one speed 
  ]
end

; random walk for one citizen
to random-walk-one [ spd ]
  set heading heading + random walking-angle - random walking-angle
  avoid-walls
  fd spd
end

;; avoid the edges of the world
to avoid-walls
  if abs [pxcor] of patch-ahead (wall + 1) = max-pxcor [ set heading (- heading) ]
  if abs [pycor] of patch-ahead 1 = max-pycor [ set heading (180 - heading) ]
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PUT AGENTS IN QUARANTINE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; quarantine an infected agent (was called in avoid-infected = scenario 3c)
to quarantine-infected
  if not quarantined? [
    set shape "square"
    move-to min-one-of patches with [not any? citizens-here] [ pxcor ]
    set size 1
    set quarantined? true
  ]
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; VIRUS PROPAGATION ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; virus transmission to susceptibles only
;; TODO: ajouter une durée d'incubation au moment de l'infection (tirer dans une loi GAMMA la durée)
;; random-gamma moyenne = 6 jours (variance de 3j) - durée contagiosité 21 jours (variance 1j)
;; variance a la mano by LN
to get-virus
  ; choose one random agent in transmission distance radius
  let target one-of other citizens in-radius transmission-distance with [epidemic-state = "Infected" or epidemic-state = "Asymptomatic Infected"]
  if is-agent? target
  [
    ; use a different transmission probability depending on target agent's symptoms
    ; TODO: age should influence probability as well
    if ([epidemic-state] of target = "Infected" and random-float 1 < probability-transmission)
    or
    ([epidemic-state] of target = "Asymptomatic Infected" and random-float 1 < proba-transmission-unreported-infected) [
        ; probabilistic decision if the new infected should have symptoms
        ifelse random 100 > %unreported-infections
        [ set epidemic-state "Infected" ]
        [ set epidemic-state "Asymptomatic Infected" ]
      show-epidemic-state
      set infection-date ticks
    ]
  ]
end


; called at each step ( instead of get-virus ) in go
to propagate-epidemics
  ask citizens with [epidemic-state = "Susceptible"] [become-incubation]
  ask citizens with [epidemic-state = "Incubation" ] [become-symptomatic]
  ask citizens with [member? "Infected" epidemic-state] [become-recovered]
  
  ; TODO reinfection
  ; an immunity-duration decided when becoming recovered. After this, citizen becomes susceptible again
  ; immunity duration probably 1 or 2 years, but unknown so far
  
  ; change shape accordingly
  ask citizens [ show-epidemic-state ]
end

; called on susceptibles to start incubation period
to become-incubation
  ; find a target = incubating or infected agent around me
  let around-me other citizens in-radius transmission-distance with 
        [epidemic-state = "Infected" or epidemic-state = "Asymptomatic Infected" or epidemic-state = "Incubation"]
  let target one-of around-me
  
  if is-agent? target
  [
    ; probability to start incubation, to be set based on various parameters
    let proba-incub 0

    ; use a different transmission probability depending on target agent's symptoms    
    (ifelse 
      [epidemic-state] of target = "Infected" [ set proba-incub probability-transmission ]
      [epidemic-state] of target = "Asymptomatic Infected" [set proba-incub proba-transmission-unreported-infected ]
      [epidemic-state] of target = "Incubation" [set proba-incub proba-transmission-incubation]
    )
    ; TODO: also based on number of infected people around?
    ; TODO: also based on age (older are more exposed?)
    
    ; actual infection
    if random-float 1 < proba-incub 
    [
      ; start incubation
      set epidemic-state "Incubation"
      ; store infection date
      set infection-date ticks
    
      ; decide length of incubation and infection (gamma distribution)
      ; 10 ticks per day ?
      set incubation-duration random-gamma-mv incubation-mean incubation-variance
      set infection-duration random-gamma-mv infection-mean infection-variance
    
    ];end if proba
  ];end if target found
end

; random gamma from mean and variance (instead of alpha and lambda)
; cf doc netlogo random-gamma
to-report random-gamma-mv [ gamma-mean gamma-variance ]
  ;let gamma_mean 6
  ;let gamma_variance 3
  let alpha gamma-mean * gamma-mean / gamma-variance
  let lambda 1 / (gamma-variance / gamma-mean)
  report random-gamma alpha lambda
end

; called on incubating to determine if they become symptomatic or not
to become-symptomatic
  ; if incubation over
  if ticks > infection-date + incubation-duration 
  [
     ; probability to be (a)symptomatic
     ifelse random 100 > %unreported-infections
        [ set epidemic-state "Infected" ]
        [ set epidemic-state "Asymptomatic Infected" ]
  ]
end

; called on infected (whether symptomatic or not) to make them recover
to become-recovered
  if ticks > infection-date + infection-duration [
     set epidemic-state "Recovered"
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; TESTING STRATEGIES ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; TODO: strategies de test par symptomes (echoue sur les asymptomatiques) vs serologique (détecte les guéris)
;       ajouter un selecteur pour le type de test à utiliser

; TODO: ne pas confiner les malades !! (ou alors uniquement ceux qui sont testés ! - ajouter un switch)

; TODO : depending on max number of tests, part of the target population cannot be tested
; monitor the number of days needed to test the entire target?

; TODO: supprimer le bouton test, faire du test auto selon la stratégie choisie à l'init


to test-pop
  ; switch based on selected strategy, to determine WHO is tested
  ; TODO: first define target population, then check if not empty
  ; if empty, end of test campaign, display time it took
  ; if not empty, keep testing

  ; TODO attention n-of plante si n>len(set)...
  
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
    STRATEGY = "workers" [set target-population target-population with [telework? = false]]
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
    show untested-sick

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


; called on each tested citizen
; TODO: test probabiliste -
to test-one
  set tested? true ; won't be tested again in the same campaign
  ; TODO: test should not be 100% ok
  ; TODO: incubation might be missed?
  ; TODO: type of test: PCR detects symptoms, serological detects even recovered
  if-else epidemic-state != "Susceptible" and epidemic-state != "Recovered"  [set positive? true] [set positive? false]
  ;il faut que certains symptomatiques soient non COVID : nouvel état ? attribut symptomes/etat de santé/comorbidités?
  set shape "triangle"
end

;;;;;;;;;;;;;;;;;;;
;;;;; UPDATES ;;;;;
;;;;;;;;;;;;;;;;;;;

; FIXME: check colors
to show-epidemic-state
  (ifelse
    epidemic-state = "Susceptible" [ set color lput transparency extract-rgb  green ]

    epidemic-state = "Incubation" [ set color lput transparency extract-rgb orange ]
    
    epidemic-state = "Infected"
    [
      set color lput transparency extract-rgb red
      set shape "square" 
    ]

    epidemic-state = "Asymptomatic Infected"
    [
      set color lput transparency extract-rgb blue
      ;set color lput transparency extract-rgb green
    ]

    epidemic-state = "Recovered" [ set color lput transparency extract-rgb gray ]
  )
end


to show-asymptomatic-cases
  ask citizens with [epidemic-state = "Asymptomatic Infected"]
  [ set color lput transparency extract-rgb blue ]
end


;; TODO: attention à compter aussi les incubateurs !!
;; sinon on a des comptes négatifs sur le graphe !
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
  set total-tests nb-Tests
  set negative-tests nb-NegTests
  set untested-sick nb-UI
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

to-report nb-Tests
  report count citizens with [tested? = true]
end

to-report nb-NegTests
  report count citizens with [tested? = true and positive? = false]
end

to-report nb-UI
  report count citizens with [tested? = false and epidemic-state != "Susceptible" and epidemic-state != "Recovered" ]
end


;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; EXPLANATIONS ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to set-explanations
  set EXPLICATION
    ; SIMULATIONS = "Simulation 3c : L’arbre qui cache la forêt"
    "Scénario plus subtil cette fois : certaines personnes infectées ne sont pas identifiables (en bleu, courbe Ib). Le virus se propage alors de manière insidieuse, alors même que les cas identifiés (en rouge, courbe Ia) sont systématiquement isolés en étant placés en quarantaine sur le côté gauche. Une meilleure connaissance de cette population non répertoriée est donc nécessaire, si l'on veut comprendre et maîtriser cette épidémie. Choisissez une stratégie de dépistage pour essayer d'identifier le maximum de malades avec un minimum de tests !"
end
