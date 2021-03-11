;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;DECLARATION;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Tentative naming conventions
;;;;;;;;;;;;;;;;;;;;;;;;;;;
; for reporter-like variables :
; infected : in state I or IA
; contagious : in state E, I or IA
; nb-var or var : number of var at current tick
; daily-var : number of var for the whole day
; total-var : sum/cumulation of vars since the beginning of the simulation
; var% : var / population size
; proportion-var : var / something

globals [ ;;global parameters

  walking-angle
  speed
  probability-car-travel
  population-size
  nb-house

  ;epidemic symbolic constants
  S ; Susceptible
  Ex ; Exposed - Infected and incubating, but already contagious.
  Ia ; Infected asymptomatic
  I ; Infected symptomatic
  R ; Recovered
	;V ; Vaccinated

  delay-before-test
  incubation-duration
  nb-days-before-test-tagging-contacts
  proportion-equiped
  probability-respect-lockdown
  probability-success-test-infected
  ;probability-asymptomatic-infection
  R0-a-priori
  initial-R-proportion
  size_population
  Nb_contagious_initialisation
  quarantine-time
  initial-spread
  probability-transmission
  probability-transmission-asymptomatic
  probability-hospitalized
  symptom-to-hospital-duration ; the average delay between the first onset of symptoms and hospitalisation if needed.
  probability-death
  protective-behaviour-efficiency ; masks, physical distanciation, hygiene... efficiency as an infectiousness divider

  ;current-nb-new-infections-reported
  ;current-nb-new-infections-asymptomatic
  transparency
  infection-duration
  contagion-duration-tick
  nb-ticks-per-day
  lockdown-date
  previous-lockdown-state
  lock-down-color
  nb-lockdown-episodes
  max-I
  max-conf
  max-nb-lockdown

  nb-contagious-detected
  total-nb-contagious-lockeddown
  total-nb-contagious
  total-nb-non-contagious-lockeddown
  total-nb-lockeddown
  total-lockeddown-tracked
  nb-co-infected
  mean-daily-contacts ; for 1 tick
  mean-mean-daily-contacts ; mean since the beginning of the simulation
  Estimated-mean-mean-daily-contacts
  contacts-to-warn
  contacts-to-warn-next
  list-mean-contacts

  total-contagious-lockeddown-symptom
  total-contagious-lockeddown-tracked

  tracers-this-tick
  traced-this-tick
  REACTING? ; doing anything?
  TRACING? ; contact-TRACING?
  TESTING? ; secondary testing, primary infected is always tested
  FAMILY-LOCKDOWN?
  ;fixed-seed?
	
  the-hospital
  the-graveyard
	;initial-vaccinated-proportion
	;efficacity-vaccine
]

patches-own [wall]

breed [citizens citizen]
breed [houses house]
breed [hospitals hospital]
breed [graveyards graveyard]

citizens-own
[
  epidemic-state; S, Ex, Ia, I , R ;or V
  infection-date
  infection-source
  nb-other-infected
  contagion-counter ;;counter to go from state 1 or 2 (infected) to state 3 recovered
  contagious? ; boolean
  my-contagiousness
  resistant? ; boolean - indicates in case of infection wether the citizen will express symptoms
  my-house
  lockdown? ; 0 free 1 locked
  nb-ticks-lockdown
  liste-contacts
  liste-contact-dates
  daily-contacts
  equiped?
  detected?
  list-date-test
  nb-tests
  nb-lockdown
  contact-order ;0 not contacted, 1 contacted at first order, 2 contacted at second order
  nb-contacts-ticks
  nb-contacts-total-Infectious ; total number of contacts during infectious period
  difference
  potential-co-infected
  family-infection?
  delayed-test
  to-be-tested
	vaccinated?
  mobile?
  hospitalized?
  dead?
  protectivity ; easier than a cleaner bollean protectivity? + tests all the time the altered infection probability would be needed
]

houses-own
[
  my-humans
  clean ; private. Should be only accessed through reporter clean? [house]
  unlock-time ; private. Should only be accessed through reporter unlock-time? [house]
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;SETUP;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-globals

  set transparency 145
  ;set fixed-seed? true
  if fixed-seed?[
    random-seed 30
  ]

  ;symbolic constants
  set S 0
  set Ex 1
  set Ia 2
  set I 3
  set R 4
	;set V 5
	
  ;traductions
  set delay-before-test  Temps-d'attente-pour-la-réalisation-du-test
  set nb-days-before-test-tagging-contacts Profondeur-temporelle-de-recherche-des-contacts
  set proportion-equiped Taux-de-couverture-de-l'application-de-traçage
  set probability-respect-lockdown Probabilité-de-respect-du-confinement
  set probability-success-test-infected Probabilité-que-le-test-soit-efficace
  set R0-a-priori R0-fixé
  set initial-R-proportion 0
  set size_population 2000
  set Nb_contagious_initialisation Nombre-de-cas-au-départ
  set initial-spread Repartition-initiale-des-malades
  set protective-behaviour-efficiency Efficacité-des-gestes-barrières

  set population-size  size_population
  set nb-house (population-size / 3)
	
  set walking-angle 50
  set speed 1
  set probability-car-travel 0.2

 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 ;;;;;;;;epidemics characteristics;;;;;;;;;;;
 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  set nb-ticks-per-day 4
  set incubation-duration 4
  set infection-duration 14
  set quarantine-time (infection-duration + incubation-duration) * nb-ticks-per-day ;why not?
  set contagion-duration-tick ((incubation-duration + infection-duration) * nb-ticks-per-day) ;
 ; set probability-asymptomatic-infection 0.1

  set Estimated-mean-mean-daily-contacts 0.004 * population-size + 3.462 ;calibrated from systematic experiments from 1000 to 10000 agents, on same world
  set probability-transmission R0-a-priori / ((Estimated-mean-mean-daily-contacts / nb-ticks-per-day)  * contagion-duration-tick) ; probability per tick
  set probability-transmission-asymptomatic probability-transmission / 2

  set probability-hospitalized 0.07
  set symptom-to-hospital-duration 7 * nb-ticks-per-day ; one week

  set probability-death 0.016

  ;set initial-vaccinated-proportion 75
	;set efficacity-vaccine 0.90

 ;;;;;;;;Tracing app initialisation;;;;;;;;;;;
  set contacts-to-warn-next no-turtles
  set contacts-to-warn no-turtles
  set list-mean-contacts []
  set mean-mean-daily-contacts []


	
  ifelse SCENARIO = "Laisser-faire"[
    set REACTING? false
    set TRACING? false
    set TESTING? false
    set FAMILY-LOCKDOWN? false
  ][ifelse SCENARIO = "Confinement simple"[
    set REACTING? true
    set TRACING? false
    set TESTING? false
    set FAMILY-LOCKDOWN? true
  ][ifelse SCENARIO = "Traçage et confinement systématique"[
    set REACTING? true
    set TRACING? true
    set TESTING? false
    set FAMILY-LOCKDOWN? false
  ][ifelse SCENARIO = "Traçage et confinement sélectif"[
    set REACTING? true
    set TRACING? true
    set TESTING? true
    set FAMILY-LOCKDOWN? false
  ][ifelse SCENARIO = "Vaccin"[
    set REACTING? false
    set TRACING? false
    set TESTING? false
    set FAMILY-LOCKDOWN? false
  ][
    show "error"
    stop
]]]]]


end

to setup-walls
  ask patches with [abs(pxcor) = max-pxcor or abs(pycor) = max-pycor] [set wall 1]
end

to setup-hospital
  create-hospitals 1[
    setxy max-pxcor - 2  max-pycor - 2
    set shape "building institution"
    set size 5
    set color white
    set the-hospital self
  ]
end

to setup-graveyard
  create-graveyards 1[
    setxy max-pxcor - 2  min-pycor + 2
    set shape "building institution"
    set size 5
    set color red
    set the-graveyard self
  ]
end

to setup-houses
  create-houses nb-house[
    move-to one-of patches with [wall = 0]
    set shape "house"
    fd random-float 0.5

;**set houses coordinates outside the hospital**
    setxy  random-xcor random-ycor
    while [((xcor > (max-pxcor - 5)) and (ycor > (max-pycor - 5))) or ((xcor > (max-pxcor - 5)) and (ycor < (min-pycor + 5)))][
      setxy  random-xcor random-ycor
    ]

    set size 2
    set color lput transparency extract-rgb  white
    set my-humans []
    set clean true
  ]
end

to setup-population
  create-citizens population-size
  [
    let me self
    ;move-to one-of patches with [wall = 0]
    fd random-float 0.5
    set shape "circle"
    set size 1
    set color green ; lput transparency extract-rgb  green
    set epidemic-state S
    set delayed-test delay-before-test / 6
    set to-be-tested false
    set nb-contacts-ticks 0
    set my-house one-of houses
    ask my-house[
      set my-humans lput me my-humans
    ]
    move-to my-house
    set mobile? true
    set liste-contacts []
    set liste-contact-dates []
    set list-date-test []
    set daily-contacts nobody
    set nb-other-infected 0
    set contact-order 0
    set to-be-tested false
    set potential-co-infected false
    set family-infection? false
    set equiped? false
    set detected? false
    set contagious? false
    set resistant? false ; resistance is really "defined" when the citizen is Exposed to the virus
    set hospitalized? false
    set dead? false
    set vaccinated? false
    ifelse random-float 1 < (Usage-des-gestes-barrières / 100) [
      set protectivity protective-behaviour-efficiency / 100
    ][
      set protectivity 0
    ]
  ]
    ifelse initial-spread = "Aléatoire"[
    set-infected-initialisation-random
  ][ifelse initial-spread = "Concentrés"[
    set-infected-initialisation-concentrated
  ][if initial-spread = "Bien répartis"[
    set-infected-initialisation-balanced
   ]]]

  set-R-initialisation
  set-vaccinated-initialisation-random
  set-equiped-initialisation

end


to set-infected-initialisation-concentrated ; all contagious people are initialised in a top left rectangle
  let contagious-candidates citizens with [(xcor < (min-pxcor / 2)) and (ycor < (min-pycor / 2))]
  ;show count contagious-candidates
  ask n-of Nb_contagious_initialisation contagious-candidates[
    become-exposed
  ]
end

to set-infected-initialisation-balanced
  ;let world-width max-pxcor - min-pxcor
  ;let world-height max-pycor - min-pycor
  let block-width int (world-width / nb-columns)
  let block-height int (world-height / nb-lines)
  let left-border int ((remainder world-width nb-columns) / 2) + min-pxcor
  let top-border int ((remainder world-height nb-lines) / 2) + min-pycor
  let contagious-per-block int (Nb_contagious_initialisation / (nb-columns * nb-lines))
  let contagious-random remainder Nb_contagious_initialisation (nb-columns * nb-lines)

;  show word "bw : " block-width
;  show word "bh : " block-height
;  show word "lb : " left-border
;  show word "tb : " top-border
;  show word "cpb : " contagious-per-block
;  show word "cr : " contagious-random

  let current-x left-border
  let current-y top-border
  Repeat nb-lines[
    set current-x left-border
    Repeat nb-columns[
;      show word "cx : " current-x
;      show word "cy : " current-y
      let my-patch patch current-x current-y
      let candidates no-turtles
      ask my-patch [set candidates turtles-on neighbors]
      let contagious sublist sort-on [distancexy current-x current-y] citizens 1 (contagious-per-block + 1)
      ;show length contagious
      foreach contagious[
        the-turtle -> ask the-turtle [
          become-exposed
        ]
      ]
      set current-x (current-x + block-width)
    ]
    set current-y (current-y + block-height)
  ]
  ask n-of contagious-random citizens with [not contagious?][
    become-exposed
  ]
end


to set-infected-initialisation-random
  ask n-of Nb_contagious_initialisation citizens [
    become-exposed
  ]
end

;; vacciné <=> recovered ?
;; quid si trop de Ex ? : population size --> nb-S ;  Fixed ?
to set-vaccinated-initialisation-random
  ask n-of ((initial-vaccinated-proportion / 100 * nb-S)*(vaccine-efficacy / 100)) citizens with [not contagious?][
  	become-vaccinated
  ]
end


to set-equiped-initialisation
  ask n-of (round (population-size * (Proportion-equiped / 100))) citizens[
    set equiped? true
  ]
end

to set-R-initialisation
  ask n-of (initial-R-proportion / 100 * population-size) citizens with [not (epidemic-state = Ex)][
    set epidemic-state R
  ]
end


to setup
  clear-all
  reset-ticks
  setup-globals
  setup-walls
  setup-hospital
  setup-graveyard
  setup-houses
  setup-population
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;GO;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if not any? citizens with [contagious?] [stop]

  if (ticks mod nb-ticks-per-day) = 1[
    update-vaccinated
  ]

  move-citizens
  get-in-contact

  if TRACING?[
;    set tracers-this-tick 0
;    set traced-this-tick 0
    if any? contacts-to-warn[
      warn-contacts 2
    ]
  ]
  if REACTING?[
    ask citizens with [(epidemic-state = I) and (not detected?) and (lockdown? = 0) and (to-be-tested = false)] [
      set to-be-tested true
      set contact-order 1
    ]
    ask citizens with [to-be-tested = true][
      ifelse delayed-test = 0[
        get-tested
      ][
        set delayed-test delayed-test - 1
      ]
    ]
  ]

  if TRACING?[
    set traced-this-tick count contacts-to-warn-next
    set contacts-to-warn contacts-to-warn-next
    set contacts-to-warn-next no-turtles
  ]


  update-epidemics
  update-lockdown

  update-max-I
  update-max-conf
  update-list-mean-contacts
  update-mean-daily-contacts
  update-mean-mean-daily-contacts
  update-my-contagiousness

  tick

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;MOVEMENT PROCEDURES;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move-citizens
  ask citizens[
    if mobile? [
      let nighttime? (ticks mod nb-ticks-per-day) = 0
      ifelse nighttime?[
        move-to my-house
      ][
        ifelse random-float 1 < probability-car-travel[
          move-to one-of patches with [wall = 0]
        ][
          rt random 360
          avoid-walls
          fd speed
        ]
      ]
    ]
  ]
end

to avoid-walls
  ifelse  any? neighbors with [wall = 1]
    [ face one-of neighbors with [wall = 0] ]
  [set heading heading + random walking-angle - random walking-angle
      ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;EPIDEMIC PROCEDURES;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to get-virus [contact-source]
  let real-contagiousness ( (contagiousness contact-source) * (1 - [protectivity] of contact-source) * (1 - (protectivity * 0.5)) ) ; good protection from others being careful, some protection from being careful (masks)
	ifelse ( ([contagious?] of contact-source)  and (random-float 1 < real-contagiousness) and not vaccinated?) [
    become-exposed
    if lockdown? = 1[
      set total-nb-contagious-lockeddown total-nb-contagious-lockeddown + 1
    ]
    set infection-source contact-source
    ask contact-source [set nb-other-infected nb-other-infected + 1]
    set family-infection? (my-house = [my-house] of contact-source)
    if potential-co-infected [
      set nb-co-infected nb-co-infected + 1
    ]
  ][
    set potential-co-infected false
  ]
end

to update-epidemics
  ;;update the counters for the infected at this timestep
  ;set current-nb-new-infections-reported 0
  ;set  current-nb-new-infections-asymptomatic 0
  ;;update recovered
  ask citizens with [contagious?][
    set contagion-counter (contagion-counter - 1)
    if ( (ticks - infection-date) = (incubation-duration * nb-ticks-per-day)) [
      ifelse resistant?
        [ become-asymptomatic-infected ]
        [ become-infected ]
    ]
    if ( (ticks - infection-date) = (incubation-duration * nb-ticks-per-day) + symptom-to-hospital-duration) [
      if random-float 1 < probability-hospitalized [
        hospitalize
      ]
    ]
    if contagion-counter <= 0 [
      become-recovered
      if random-float 1 < probability-death [
       become-dead ; parce que j'ai peur que "die" fausse les compteurs et autres stats, je préfère les envoyer indéfiniment au cimetière...
      ]
    ]
  ]
end


to get-in-contact
  ask citizens
  [
    ifelse lockdown? = 0[
;      if (((ticks - 1) mod nb-ticks-per-day) = 0)[
;        set daily-contacts nobody
;      ]
      let contacts (turtle-set other citizens-here) ; citizens-on neighbors
;      set nb-contacts-ticks count contacts
      set daily-contacts (turtle-set daily-contacts contacts)

;      if contagious? [set nb-contacts-total-Infectious nb-contacts-total-Infectious + nb-contacts-ticks]

      let family []
      ask my-house[
        set family my-humans
      ]
      let family-contacts contacts with [member? self family]
      set contacts contacts with [lockdown? = 0]
      set contacts (turtle-set contacts family-contacts)

      if equiped? [
        let contacts-equiped contacts with [equiped?]
        set liste-contacts lput contacts-equiped liste-contacts
        set liste-contact-dates lput ticks liste-contact-dates
      ]

      let infection-contact one-of contacts with [contagious?]
      if (epidemic-state = S and not vaccinated? and is-agent? infection-contact) [
        get-virus infection-contact
      ]
    ][
      if epidemic-state = S[
        let co-infected? false
        let infection-contact nobody
        ask my-house[
          foreach my-humans[
            [my-human] -> ask my-human [
              if contagious?[
                set co-infected? true
                set infection-contact self
              ]
            ]
          ]
        ]
        if co-infected?[
          get-virus infection-contact
          set potential-co-infected true
        ]
      ]
    ]
  ]
end

to get-tested
  set list-date-test lput ticks list-date-test
  set nb-tests nb-tests + 1
  ;set delayed-test delay-before-test / 6
  set to-be-tested false
  ;test results and consequences
  if contagious? and random-float 1 < probability-success-test-infected [
    set detected? true
    set  nb-contagious-detected nb-contagious-detected + 1
    if (random-float 1 < probability-respect-lockdown)[
      ifelse FAMILY-LOCKDOWN? [
        ask my-house[
          foreach my-humans[
            [my-human] -> ask my-human [
              if lockdown? = 0 [
                lockdown
              ]
            ]
          ]
        ]
      ][
        if lockdown? = 0 [
          lockdown
        ]
      ]
    ]
    if equiped? and TRACING?[
        detect-contacts
      ]
  ]

end

to lockdown
  set lockdown? 1
  set mobile? false
  set nb-lockdown nb-lockdown + 1 ;
  if nb-lockdown > max-nb-lockdown[
    set max-nb-lockdown nb-lockdown
  ]
  set lockdown-date ticks
  move-to my-house
  set nb-ticks-lockdown quarantine-time
  if nb-lockdown = 1 [
    set total-nb-lockeddown total-nb-lockeddown + 1 ; le nombre de personnes ayant été confinées au moins une fois
  ]
   ;les compteurs ci-dessous sont incrémentés à chaque fois que la personne est confinée
    ifelse contagious?[
      set total-nb-contagious-lockeddown total-nb-contagious-lockeddown + 1
      ifelse contact-order = 1 [
        set total-contagious-lockeddown-symptom total-contagious-lockeddown-symptom + 1
      ][
        set total-contagious-lockeddown-tracked total-contagious-lockeddown-tracked + 1
      ]
    ][
      set total-nb-non-contagious-lockeddown total-nb-non-contagious-lockeddown + 1
    ]
  if contact-order = 2[
    set total-lockeddown-tracked total-lockeddown-tracked + 1
  ]
end

to update-lockdown
  ask citizens with [lockdown? = 1][
    set nb-ticks-lockdown (nb-ticks-lockdown - 1)
    if ((clean? my-house) and (unlock-time? my-house))[
        ask my-house[
        foreach my-humans[
          [my-human] -> ask my-human [
            set lockdown? 0
            set mobile? true
          ]
        ]
      ]
      ;show ("Freedom")
    ]
  ]
end

to hospitalize
  set hospitalized? true
  set mobile? false
  move-to the-hospital
end

to update-vaccinated
  ;On vaccine les S et les R
  ask n-of ((proportion-vaccinated-per-day / 100 * (nb-S + nb-R))*(vaccine-efficacy / 100)) citizens with [epidemic-state = S or epidemic-state = R][
  	become-vaccinated
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;BACKTRACKING;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to detect-contacts
  let me self
  let my-lockdown-date lockdown-date
  let j 0
  set tracers-this-tick tracers-this-tick + 1
  repeat length liste-contacts[

    let date-j item j liste-contact-dates
    let contacts-j item j liste-contacts

    if is-agentset? contacts-j[
      if date-j >= (my-lockdown-date - (nb-days-before-test-tagging-contacts * nb-ticks-per-day))[
        set contacts-to-warn-next (turtle-set contacts-to-warn-next contacts-j) ; with [detected? = false]
      ]
    ]
    set j j + 1
  ]
  set liste-contacts []
  set liste-contact-dates []
end

to warn-contacts [order]
  ifelse TESTING?[
    ask contacts-to-warn with [detected? = false][
      set to-be-tested true
      set contact-order order
    ]
  ][
    ask contacts-to-warn [
      ifelse (lockdown? = 0)[
        if random-float 1 < probability-respect-lockdown[
          set contact-order order
          lockdown
        ]
      ][
        set nb-ticks-lockdown quarantine-time
     ]
     detect-contacts
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;STATE TRANSITION PROCEDURES;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to become-vaccinated
	 set vaccinated? true
	 set my-contagiousness 0
	 set contagious? false
end

to become-exposed
  set epidemic-state Ex
  set contagion-counter contagion-duration-tick
  set infection-date ticks
  ;set current-nb-new-infections-reported (current-nb-new-infections-reported + 1)
  set total-nb-contagious total-nb-contagious + 1
  set color brown ;
  set resistant? (random-float 1 < probability-asymptomatic-infection)
  set contagious? true
  set my-contagiousness contagiousness self
end

to become-infected
  set epidemic-state I
  set color red ;
set my-contagiousness contagiousness self
end

to become-asymptomatic-infected
  set epidemic-state Ia
  set color blue ;
set my-contagiousness contagiousness self
end

to become-recovered
  set epidemic-state R
  set contagious? false
  set color yellow ;
  set my-contagiousness 0
end

to become-dead
  set mobile? false
  move-to the-graveyard
  set dead? true
end



;###############################
;REPORTERS
;###############################

to-report contagiousness [a-citizen]
  if ([epidemic-state] of a-citizen) = Ex [
    ifelse resistant? [
      report (((ticks - infection-date) / (incubation-duration * nb-ticks-per-day)) * probability-transmission-asymptomatic) ; linear growth from 0 at infection time to full asymptomatic transmission probability at the end of incubation time
    ][
      report (((ticks - infection-date) / (incubation-duration * nb-ticks-per-day)) * probability-transmission) ; linear growth from 0 at infection time to full symptomatic transmission probability at the end of incubation time
    ]
  ]

  if ([epidemic-state] of a-citizen) = I [
      report probability-transmission
  ]

  if ([epidemic-state] of a-citizen) = Ia [
      report probability-transmission-asymptomatic
  ]

end

to-report clean? [a-house]
  let local-clean true
  ask a-house[
    foreach my-humans[
      [my-human] -> ask my-human [
        if contagious?[
          set local-clean false
        ]
      ]
    ]
    set clean local-clean
  ]
  report [clean] of a-house
end

to-report unlock-time? [a-house]
  let local-unlock-time true
  ask a-house[
    foreach my-humans[
      [my-human] -> ask my-human [
        if (nb-ticks-lockdown > 0)[
          set local-unlock-time false
        ]
      ]
    ]
    set unlock-time local-unlock-time
  ]
  report [unlock-time] of a-house
end

to-report nb-Ex
  report count citizens with [epidemic-state = Ex ]
end

to-report nb-D
  report count citizens with [dead?]
end

to-report nb-H
  report count citizens with [hospitalized?]
end

to-report nb-I
  report count citizens with [epidemic-state = I or epidemic-state = Ia ]
end

to-report nb-Inr
  report count citizens with [epidemic-state = Ia ]
end

to-report nb-Ir
  report count citizens with [epidemic-state = I ]
end

to-report nb-R
  report count citizens with [epidemic-state = R]
end

to-report nb-S
  report count citizens with [epidemic-state = S ]
end

to-report nb-V
  report count citizens with [vaccinated?]
end

to-report nb-non-S%
  report (population-size - nb-S) / population-size * 100
end


to-report nb-S%
report (nb-S) / population-size * 100
end

to-report epidemic-duration-final
  report round (ticks / nb-ticks-per-day)
end


to-report lockdowned%
  report (count citizens with [lockdown? = 1] / population-size) * 100
end

to-report total-nb-tests
  report  sum [nb-tests] of citizens
end

to-report population-tested
  report  count citizens with [nb-tests > 0]
end

to-report population-tested%
  report  count citizens with [nb-tests > 0] / population-size * 100
end

to-report total-population-locked%
  report total-nb-lockeddown / population-size * 100

end

to-report proportion-non-contagious-lockeddown%
  ifelse (total-nb-contagious-lockeddown + total-nb-non-contagious-lockeddown) > 0
  [report total-nb-non-contagious-lockeddown / (total-nb-contagious-lockeddown + total-nb-non-contagious-lockeddown) * 100]
  [report 0]

end

to-report nb-detected
  report count citizens with [detected?]
end

to-report nb-detected%
  report nb-detected / population-size * 100
end

to-report contagious-detected%
  ifelse total-nb-contagious > 0
  [report nb-contagious-detected / total-nb-contagious * 100]
  [report 0]
end

to-report contagious-lockeddown%
  ifelse total-nb-contagious > 0
  [report total-nb-contagious-lockeddown / total-nb-contagious * 100]
  [report 0]
end

to-report %detected
  report (count citizens with  [detected?] / population-size) * 100
end

to-report epidemic-duration
  report round (ticks / nb-ticks-per-day)

end

to-report MaxI%
 report max-I / population-size * 100
end

to-report Max-Conf%
  report max-conf /  population-size  * 100
end

to-report R0
  ;report mean [nb-other-infected] of citizens with [ epidemic-state != S] - To see in real time the nb of other citizens infected by people who wera affected by the infection
  ifelse nb-R > 0 [
    report mean [nb-other-infected] of citizens with [epidemic-state = R]
  ][
    report "N/A"
  ]
  ;To see once someone is cured in average how many people he infected. Converges towards 1 as time goes by as the population is finite:
  ;the sum of nb-other-infected is the population of infected, as in our model an infected has one and only one source
end

to-report family-locked-down
  report count citizens with [not detected? and lockdown? = 1]
end

to-report mean-contacts-ticks
  report mean [nb-contacts-ticks] of citizens
end

to-report symptom-detected
  report count citizens with [detected? and contact-order = 1]
end

to-report symptom-detected%
  ifelse nb-detected > 0
  [report symptom-detected /  nb-detected  * 100]
  [report 0]
end

to-report contact-detected
  report count citizens with [detected? and contact-order = 2]
end

to-report contact-detected%
  ifelse nb-detected > 0
  [report contact-detected /  nb-detected  * 100]
  [report 0]
end

to-report contagious-lockeddown-tracked
  report count citizens with [(lockdown? = 1) and (contagious?) and (contact-order = 2)]
end

to-report proportion-total-contagious-lockeddown-tracked
  ifelse (total-contagious-lockeddown-tracked + total-contagious-lockeddown-symptom) > 0[
    report total-contagious-lockeddown-tracked / (total-contagious-lockeddown-tracked + total-contagious-lockeddown-symptom) * 100
  ][
    report 0
  ]
end

to-report proportion-total-contagious-lockeddown-symptom
  ifelse (total-contagious-lockeddown-tracked + total-contagious-lockeddown-symptom) > 0[
    report total-contagious-lockeddown-symptom / (total-contagious-lockeddown-tracked + total-contagious-lockeddown-symptom) * 100
  ][
    report 0
  ]
end

to-report citizens-per-house
  report mean [length my-humans] of houses
end

to-report mean-contacts
  report mean list-mean-contacts
end

to-report mean-mean-daily-contacts-nb
  report mean mean-mean-daily-contacts
end





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;COUNTERS;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to update-max-I
  if nb-I > max-I [set max-I nb-I]
end

to update-max-conf
  let nb-conf count citizens with [lockdown? = 1]
  if nb-conf > max-conf [set max-conf nb-conf]
end

to update-list-mean-contacts
  set list-mean-contacts lput mean-contacts-ticks list-mean-contacts
end

to update-mean-daily-contacts
  if ((ticks mod 4) = 0)[
    set mean-daily-contacts mean [count daily-contacts] of citizens
  ]
end

to update-mean-mean-daily-contacts
  set mean-mean-daily-contacts lput mean-daily-contacts mean-mean-daily-contacts
end

;we update contagiousness only for Exposed citizens, as the value grows as ticks pass
to update-my-contagiousness
  ask citizens with [epidemic-state = 1 ]
  [set my-contagiousness contagiousness self]

end
@#$#@#$#@
GRAPHICS-WINDOW
8
6
626
825
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
-40
40
1
1
1
ticks
30.0

BUTTON
628
827
722
877
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
724
827
813
877
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
628
6
1401
265
EVOLUTION DE L'EPIDEMIE
Durée de l'épidémie
% de population
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Sains" 1.0 0 -13840069 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) (nb-S / population-size * 100)]"
"Exposés" 1.0 0 -6459832 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) (nb-Ex / population-size  * 100)]"
"I. Symptomatiques" 1.0 0 -2139308 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) (nb-Ir  / population-size * 100)]"
"I. Asymptomatiques" 1.0 0 -1184463 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) (nb-Inr  / population-size * 100)]"
"Contagieux" 1.0 0 -955883 true "" "\nif population-size > 0 [plotxy (ticks / nb-ticks-per-day) ((nb-Ir + nb-Inr + nb-Ex) / population-size  * 100)]"
"Guéris" 1.0 0 -13791810 true "" "\nif population-size > 0 [plotxy (ticks / nb-ticks-per-day) (nb-R / population-size  * 100)]"
"Confinés" 1.0 0 -8630108 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) lockdowned%] "
"Vaccinés" 1.0 0 -6759204 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) (nb-V / population-size * 100)]"
"Hospitalisés" 1.0 0 -7500403 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) (nb-H / population-size * 100)]"
"Morts" 1.0 0 -2674135 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) (nb-D / population-size * 100)]"

MONITOR
897
362
1120
407
Population touchée par l'épidémie (%)
nb-non-S%
1
1
11

CHOOSER
354
834
627
879
SCENARIO
SCENARIO
"Laisser-faire" "Confinement simple" "Traçage et confinement systématique" "Traçage et confinement sélectif"
0

MONITOR
1123
362
1401
407
Durée de l'épidémie (en jours)
epidemic-duration-final
17
1
11

MONITOR
628
361
895
406
Pic épidémique (%)
MaxI%
1
1
11

SLIDER
1403
64
1675
97
Probabilité-que-le-test-soit-efficace
Probabilité-que-le-test-soit-efficace
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1403
99
1676
132
Probabilité-de-respect-du-confinement
Probabilité-de-respect-du-confinement
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1409
610
1759
643
Profondeur-temporelle-de-recherche-des-contacts
Profondeur-temporelle-de-recherche-des-contacts
1
5
1.0
1
1
jours
HORIZONTAL

SLIDER
1410
580
1760
613
Taux-de-couverture-de-l'application-de-traçage
Taux-de-couverture-de-l'application-de-traçage
0
100
0.0
10
1
%
HORIZONTAL

SLIDER
1402
32
1753
65
Temps-d'attente-pour-la-réalisation-du-test
Temps-d'attente-pour-la-réalisation-du-test
0
72
0.0
6
1
heures
HORIZONTAL

MONITOR
1263
409
1401
454
Population testée (%)
population-tested%
1
1
11

MONITOR
783
410
937
455
Population confinée (%)
total-population-locked%
1
1
11

MONITOR
1122
266
1401
311
Nombre d'infectés
nb-I
17
1
11

MONITOR
1123
314
1401
359
Nombre de guéris
nb-R
17
1
11

MONITOR
897
266
1120
311
Nombre d'exposés
nb-Ex
17
1
11

MONITOR
628
266
894
311
Nombre de sains
nb-S
17
1
11

MONITOR
1151
733
1402
778
Personnes contagieuses confinées (%)
contagious-lockeddown%
1
1
11

MONITOR
893
733
1149
778
Personnes contagieuses Identifiées (%)
contagious-detected%
1
1
11

PLOT
629
458
1403
733
EFFICACITE DU DISPOSITIF DE TRACAGE
Durée de l'épidémie
Nombre cumulé
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Contagieux (nombre total)" 1.0 0 -817084 true "" "\nif population-size > 0 [plotxy (ticks / nb-ticks-per-day) total-nb-contagious ]"
"Contagieux identifiés" 1.0 0 -2674135 true "" "\nif population-size > 0 [plotxy (ticks / nb-ticks-per-day) nb-contagious-detected]\n\n"
"Contagieux confinés" 1.0 0 -5825686 true "" "\nif population-size > 0 [plotxy (ticks / nb-ticks-per-day) total-nb-contagious-lockeddown]\n\n"
"Sains ou guéris confinés" 1.0 0 -13840069 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day) total-nb-non-contagious-lockeddown]"
"Population testée" 1.0 0 -12895429 true "" "if population-size > 0 [plotxy (ticks / nb-ticks-per-day)  population-tested]"

MONITOR
630
733
892
778
Nombre total de personnes contagieuses
total-nb-contagious
2
1
11

MONITOR
628
409
782
454
Pic de confinement (%)
Max-Conf%
1
1
11

SLIDER
218
834
353
867
R0-fixé
R0-fixé
0
10
3.0
0.1
1
NIL
HORIZONTAL

MONITOR
628
314
894
359
Nombre d'infectés symptomatiques
nb-Ir
17
1
11

MONITOR
897
314
1119
359
Nombre d'infectés asymptomatiques
nb-Inr
17
1
11

MONITOR
628
882
814
927
Population Totale
Population-size
0
1
11

SLIDER
3
834
218
867
Nombre-de-cas-au-départ
Nombre-de-cas-au-départ
1
100
18.0
1
1
NIL
HORIZONTAL

MONITOR
628
928
814
973
% Population Infectée au départ
Nombre-de-cas-au-départ / Population-size * 100
2
1
11

MONITOR
631
780
993
825
Proportion des personnes contagieuses confinées par traçage
proportion-total-contagious-lockeddown-tracked
1
1
11

MONITOR
994
780
1403
825
Proportion des personnes contagieuses confinées par symptômes
proportion-total-contagious-lockeddown-symptom
1
1
11

MONITOR
938
410
1264
455
Part non contagieuse de la population confinée (%) 
proportion-non-contagious-lockeddown%
2
1
11

BUTTON
813
827
889
876
Step
go
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
891
831
1020
864
fixed-seed?
fixed-seed?
0
1
-1000

SLIDER
1138
931
1408
964
probability-asymptomatic-infection
probability-asymptomatic-infection
0
1
0.0
0.1
1
NIL
HORIZONTAL

CHOOSER
815
881
1041
926
Repartition-initiale-des-malades
Repartition-initiale-des-malades
"Concentrés" "Bien répartis" "Aléatoire"
0

INPUTBOX
900
923
979
983
Nb-lines
3.0
1
0
Number

INPUTBOX
817
924
901
984
Nb-columns
3.0
1
0
Number

SLIDER
1170
822
1404
855
initial-vaccinated-proportion
initial-vaccinated-proportion
0
100
0.0
10
1
NIL
HORIZONTAL

SLIDER
1170
856
1405
889
vaccine-efficacy
vaccine-efficacy
0
100
90.0
5
1
NIL
HORIZONTAL

SLIDER
1169
888
1406
921
proportion-vaccinated-per-day
proportion-vaccinated-per-day
0
10
0.5
0.5
1
NIL
HORIZONTAL

TEXTBOX
1405
10
1555
28
Tests et confinement
13
0.0
0

TEXTBOX
1410
557
1560
575
TousAntiCovid
13
0.0
0

TEXTBOX
1405
210
1581
242
Gestes barrières (TODO)
13
0.0
0

SLIDER
1401
233
1649
266
Efficacité-des-gestes-barrières
Efficacité-des-gestes-barrières
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
1401
266
1632
299
Usage-des-gestes-barrières
Usage-des-gestes-barrières
0
100
50.0
1
1
NIL
HORIZONTAL

MONITOR
1441
719
1512
764
Hospitalisés
nb-H
17
1
11

MONITOR
1442
763
1512
808
Morts
nb-D
17
1
11

MONITOR
1510
719
1593
764
% Hospitalisés
nb-H / population-size * 100
1
1
11

MONITOR
1510
763
1594
808
% Morts
nb-D / population-size * 100
1
1
11

@#$#@#$#@
## DESCRIPTION

Ce modèle CoVprehension s'intéresse aux applications mobiles de traçage épidémiologique et à leurs possibles effet sur l’épidémie de COVID-19.
          
Il reprend les éléments de base du modèle de confinement de la [Q6](https://covprehension.org/2020/03/30/q6.html) en les enrichissant un peu.
 
Les journées sont ainsi découpées en quatre tranches de 6 heures. Les trois premières tranches sont occupées par des déplacements et des rencontres (en moyenne 10 par jours). La plupart des déplacements se font à proximité du domicile mais 20% d’entre eux se font à plus longue distance. La dernière tranche de la journée s’effectue au domicile, partagé par trois personnes en moyenne. Au total, 2000 personnes occupent ce petit territoire virtuel.

Par ailleurs, nous introduisons également une phase d’incubation (E pour Exposé) et deux catégories d’infection possibles : les symptomatiques et les asymptomatiques, ces dernières étant plus difficiles à identifier par simple diagnostic médical en raison de l’absence de symptômes. Il s’agit donc maintenant d’un modèle SEIR.

A l’initialisation, tous les individus sont sains. On injecte alors un petit nombre d’individus infectés (paramètre *Nombre-de-cas-au-départ*) dans cette population initiale et on simule la propagation du virus à partir des comportements des individus modélisés.

Les changements d’état s’opèrent de la manière suivante : 

- *Sain → Exposé* : un individu sain deviendra exposé, au contact d’un individu infecté, selon une probabilité qui dépend de la valeur du R0 choisie et de la catégorie à laquelle appartient cet individu infecté (cf point suivant). La formule retenue pour calculer cette probabilité est la suivante : P(S→ E) = 1/R0 x c x d avec c le nombre de contacts moyens par jours ([fixé à 10 environ](https://covprehension.org/2020/04/02/q10.html)) et d la durée de la période contagieuse. 

- *Exposé → Infecté* : un individu restera dans l’état exposé pendant sa période d’incubation (fixée ici à 4 jours), au cours de laquelle il deviendra progressivement contagieux, jusqu’à devenir Infecté  asymptomatique avec une probabilité de 0.3 et Infecté  symptomatique avec une probabilité de 0.7 (ce qui correspond à une proportion d’infectés asymptomatiques dans la population de l’ordre de 30%). La contagiosité d’un individu symptomatique est estimée à partir du R0 (cf point précédent) et est considérée comme étant deux fois supérieure à celle d’un individu asymptomatique.

- *Infecté → Guéri* : au bout de 14 jours, un individu infecté est considéré comme guéri et non contagieux dans le modèle.

Sur cette base, quatre scénarios distincts sont proposés (paramètre *SCENARIO*), dans une perspective comparative :

- *S1 : Laisser-faire* : on ne fait rien, l’épidémie suit son cours sans aucune interférence
- *S2 : Confinement simple* : on identifie les porteurs symptomatiques (test) et on les confine avec leur famille 
- *S3 : Traçage et confinement systématique* : les infecté symptomatiques sont systématiquement testés et ceux qui sont positifs sont confinés avec leur famille, tandis que leurs contacts (et leur famille) sont confinés sans être testés
- *S4 : Traçage et confinement sélectif* : els infecté symptomatiques sont systématiquement testés et ceux qui sont positifs sont confinés avec leur famille, tandis que leurs contacts (et leur famille) sont testés et confinés s'ils sont positifs, ainsi que leurs contacts et les contacts de leurs contacts...



## MARCHE A SUIVRE

Choisissez un scénario et fixez des conditions initiales (curseurs en bas à gauche de l'écran). Cliquez sur le bouton "Initialiser" puis lancez la simulation.


## PRECISIONS SUR LE R0

Le R0, ou nombre de reproduction de base, est un indicateur global de la dynamique épidémique. De manière intuitive on peut le voir comme un indicateur du nombre de personnes saines qu’une personne infectée infectera, en moyenne, pendant la durée de l’épidémie. 

Si R0 est inférieur à 1, l'épidémie va s'éteindre d'elle même, sans passer par une phase de flambée épidémique.
Si R0 est supérieur à 1, alors l'épidémie pourra se développer. 

Vous pouvez tester ce point en fixant les paramètres suivants :
- *SCENARIO* : "Laisser faire"
- *Nombre-de-cas-au-départ* : 1 
- *R0-fixé* : faites varier la valeur autour de 1, cliquez sur le bouton "Initialiser" puis lancez la simulation. 

NB : vous pouvez éventuellement obtenir des départs d'épidémie pour des valeurs inférieures à 1, en raison du caractère discret et stochastique du modèle.

Attention, cet indicateur est une composition de processus couplés : le taux de contacts dans la population, la probabilité de transmission du virus à chaque contact et la durée de la phase contagieuse de la maladie développée. Par ailleurs, comme tout indicateur global,il ne rend pas compte des situations locales, qui peuvent être très différenciées. Il doit donc être manipulé avec précaution.

Son utilisation dans ce modèle permet de caractériser des dynamiques épidémiques types. A titre d'exemple, le R0 en France au moment de la mise en place de la période de confinement (17 mars 2020) était estimé à une valeur comprise entre 2,5 et 3. Après plusieurs semaines de confinement, il était estimé à 0,6.  


## AUTEURS

Modèle développé par Arnaud Banos & Pierrick Tranouez pour CoVprehension (https://covprehension.org/)
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

building institution
false
0
Rectangle -7500403 true true 0 60 300 270
Rectangle -16777216 true false 130 196 168 256
Rectangle -16777216 false false 0 255 300 270
Polygon -7500403 true true 0 60 150 15 300 60
Polygon -16777216 false false 0 60 150 15 300 60
Circle -1 true false 135 26 30
Circle -16777216 false false 135 25 30
Rectangle -16777216 false false 0 60 300 75
Rectangle -16777216 false false 218 75 255 90
Rectangle -16777216 false false 218 240 255 255
Rectangle -16777216 false false 224 90 249 240
Rectangle -16777216 false false 45 75 82 90
Rectangle -16777216 false false 45 240 82 255
Rectangle -16777216 false false 51 90 76 240
Rectangle -16777216 false false 90 240 127 255
Rectangle -16777216 false false 90 75 127 90
Rectangle -16777216 false false 96 90 121 240
Rectangle -16777216 false false 179 90 204 240
Rectangle -16777216 false false 173 75 210 90
Rectangle -16777216 false false 173 240 210 255
Rectangle -16777216 false false 269 90 294 240
Rectangle -16777216 false false 263 75 300 90
Rectangle -16777216 false false 263 240 300 255
Rectangle -16777216 false false 0 240 37 255
Rectangle -16777216 false false 6 90 31 240
Rectangle -16777216 false false 0 75 37 90
Line -16777216 false 112 260 184 260
Line -16777216 false 105 265 196 265

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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Explo_V9_Scenarios3-4" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>nb-non-S%</metric>
    <metric>epidemic-duration-final</metric>
    <metric>Max-Conf%</metric>
    <metric>total-population-locked%</metric>
    <metric>population-tested%</metric>
    <metric>total-nb-tests</metric>
    <metric>total-nb-contagious</metric>
    <metric>contagious-detected%</metric>
    <metric>contagious-lockeddown%</metric>
    <metric>proportion-non-contagious-lockeddown%</metric>
    <metric>proportion-total-contagious-lockeddown-tracked</metric>
    <metric>proportion-total-contagious-lockeddown-symptom</metric>
    <enumeratedValueSet variable="Nombre-de-cas-au-départ">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Taux-de-couverture-de-l'application-de-traçage" first="10" step="10" last="100"/>
    <enumeratedValueSet variable="Temps-d'attente-pour-la-réalisation-du-test">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Profondeur-temporelle-de-recherche-des-contacts">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-que-le-test-soit-efficace">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-de-respect-du-confinement">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Traçage et confinement systématique&quot;"/>
      <value value="&quot;Traçage et confinement sélectif&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V9_Scenario2-R0inf1" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>nb-non-S%</metric>
    <metric>epidemic-duration-final</metric>
    <metric>Max-Conf%</metric>
    <metric>total-population-locked%</metric>
    <metric>population-tested%</metric>
    <metric>total-nb-tests</metric>
    <metric>total-nb-contagious</metric>
    <metric>contagious-detected%</metric>
    <metric>contagious-lockeddown%</metric>
    <metric>proportion-non-contagious-lockeddown%</metric>
    <metric>proportion-total-contagious-lockeddown-tracked</metric>
    <metric>proportion-total-contagious-lockeddown-symptom</metric>
    <enumeratedValueSet variable="Nombre-de-cas-au-départ">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Temps-d'attente-pour-la-réalisation-du-test">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-que-le-test-soit-efficace">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-de-respect-du-confinement">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Confinement simple&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V9_Scenario1" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>nb-non-S%</metric>
    <metric>epidemic-duration-final</metric>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Laisser-faire&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Nombre-de-cas-au-départ">
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V9_Scenarios3-4-R0inf1" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>nb-non-S%</metric>
    <metric>epidemic-duration-final</metric>
    <metric>Max-Conf%</metric>
    <metric>total-population-locked%</metric>
    <metric>population-tested%</metric>
    <metric>total-nb-tests</metric>
    <metric>total-nb-contagious</metric>
    <metric>contagious-detected%</metric>
    <metric>contagious-lockeddown%</metric>
    <metric>proportion-non-contagious-lockeddown%</metric>
    <metric>proportion-total-contagious-lockeddown-tracked</metric>
    <metric>proportion-total-contagious-lockeddown-symptom</metric>
    <enumeratedValueSet variable="Nombre-de-cas-au-départ">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Taux-de-couverture-de-l'application-de-traçage" first="10" step="10" last="100"/>
    <enumeratedValueSet variable="Temps-d'attente-pour-la-réalisation-du-test">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Profondeur-temporelle-de-recherche-des-contacts">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-que-le-test-soit-efficace">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-de-respect-du-confinement">
      <value value="0.7"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Traçage et confinement systématique&quot;"/>
      <value value="&quot;Traçage et confinement sélectif&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V9_Scenario1-R0inf1" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>nb-non-S%</metric>
    <metric>epidemic-duration-final</metric>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Laisser-faire&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Nombre-de-cas-au-départ">
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V10_Scenario1" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>nb-non-S%</metric>
    <metric>epidemic-duration-final</metric>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Laisser-faire&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Nombre-de-cas-au-départ">
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-asymptomatic-infection">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V10_Scenario2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>nb-non-S%</metric>
    <metric>epidemic-duration-final</metric>
    <metric>Max-Conf%</metric>
    <metric>total-population-locked%</metric>
    <metric>population-tested%</metric>
    <metric>total-nb-tests</metric>
    <metric>total-nb-contagious</metric>
    <metric>contagious-detected%</metric>
    <metric>contagious-lockeddown%</metric>
    <metric>proportion-non-contagious-lockeddown%</metric>
    <metric>proportion-total-contagious-lockeddown-tracked</metric>
    <metric>proportion-total-contagious-lockeddown-symptom</metric>
    <enumeratedValueSet variable="Nombre-de-cas-au-départ">
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-asymptomatic-infection">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Temps-d'attente-pour-la-réalisation-du-test">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-que-le-test-soit-efficace">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-de-respect-du-confinement">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Confinement simple&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Explo_V10_Scenarios3-4" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>not any? citizens with [contagious?]</exitCondition>
    <metric>MaxI%</metric>
    <metric>nb-non-S%</metric>
    <metric>epidemic-duration-final</metric>
    <metric>Max-Conf%</metric>
    <metric>total-population-locked%</metric>
    <metric>population-tested%</metric>
    <metric>total-nb-tests</metric>
    <metric>total-nb-contagious</metric>
    <metric>contagious-detected%</metric>
    <metric>contagious-lockeddown%</metric>
    <metric>proportion-non-contagious-lockeddown%</metric>
    <metric>proportion-total-contagious-lockeddown-tracked</metric>
    <metric>proportion-total-contagious-lockeddown-symptom</metric>
    <enumeratedValueSet variable="Nombre-de-cas-au-départ">
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="R0-fixé">
      <value value="0.5"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-asymptomatic-infection">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Temps-d'attente-pour-la-réalisation-du-test">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-que-le-test-soit-efficace">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Probabilité-de-respect-du-confinement">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Taux-de-couverture-de-l'application-de-traçage" first="10" step="10" last="100"/>
    <enumeratedValueSet variable="Temps-d'attente-pour-la-réalisation-du-test">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Profondeur-temporelle-de-recherche-des-contacts">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SCENARIO">
      <value value="&quot;Traçage et confinement systématique&quot;"/>
      <value value="&quot;Traçage et confinement sélectif&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixed-seed?">
      <value value="false"/>
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

link-arn
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Polygon -7500403 true true 150 150 105 210 195 210
@#$#@#$#@
0
@#$#@#$#@
