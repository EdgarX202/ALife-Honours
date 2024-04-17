;-----------------------------GLOBAL VARIABLES---------------------------------
globals [
  ; Prey
  prey-death-count
  prey-birth-count
  ; Sugar
  initial-sugar
  sugar-regrowth-delay
  ; GA
  generation
  ; NN PREY
  input-layer-prey
  hidden-layer-prey
  output-layer-prey
]

;-----------------------------BREEDS---------------------------------
breed [ preys prey ]
breed [ chromosomes chromosome ]

;-----------------------------SHARED PROPERTIES---------------------------------
chromosomes-own [
  weights
]

patches-own [
  sugar
  grow-back
  sugar-last-consumed
  water-pressure
]
turtles-own [
  vision
  energy
  speed
  birth-generation
  fitness
  personal-chromo
]

;-----------------------------SETUP---------------------------------
; SETUP NEURAL NETWORK
; PREY
to setup-nn-prey [input-size hidden-size output-size]
  set input-layer-prey input-size
  set hidden-layer-prey []
  set output-layer-prey []

  ; Add 0 as initial values
  repeat hidden-size [ set hidden-layer-prey lput 0 hidden-layer-prey ]
  repeat output-size [ set output-layer-prey lput 0 output-layer-prey ]

  ; Initialise weights for every chromosome
  create-chromosomes num-chromosomes [
    set weights []

    ; Weights between input and hidden layers
    repeat (input-size * hidden-size) [
      set weights lput (random-float 2 - 1) weights ; between -1 and 1
    ]
    ; Weights between hidden and output layers
    repeat (hidden-size * output-size) [
      set weights lput (random-float 2 - 1) weights ; between -1 and 1
    ]
  ]
end

; DISTANCE TO TARGET
; Using NetLogo primitive "distance"
; calculate Euclidean distance between two agents
; distance = sqrt((x2 - x1)^2 + (y2 - y1)^2)
to-report calculate-distance [target]
  ifelse target != nobody [
    report distance target
  ] [
    report nobody ; In case targets dont exist anymore
  ]
end

; PREY NN FEEDFORWARD
to feedforward-prey [chromo]
  ask preys [
    ; Calculations for INPUT layer
    ; Create new variable for storing single patch of sugar within preys vision
    let food one-of patches with [sugar > 0] in-radius vision

    ; Get distance to sugar
    let distance-to-food ifelse-value (food != nobody) [calculate-distance food] [0]

    ; Get the list of INPUTS
    let total-inputs (list distance-to-food energy speed)

    ; Variables for the hidden layer
    let access-weights [weights] of chromo ; Get the weights of a chromosome
    let bias (random-float 2 - 1) ; Random bias -1 to 1
    let i 0 ; Index for outer hidden-layer loop
    let j 0 ; Index for inner total-inputs loop
    let total-weighted-sum 0

    ; Calculate HIDDEN layer
    foreach hidden-layer-prey [ h -> ; Loop through hidden layer
        foreach total-inputs [ input-value -> ; Calculate weighted sum for each neuron (input-hidden)
         let weight item j access-weights ; Get the weight from j index
         set total-weighted-sum total-weighted-sum + (input-value * weight) ; Calculate weighted sum
         set j j + 1 ; Increment inner loop
      ]
         set total-weighted-sum total-weighted-sum + bias ; Add bias
         let sigmoid-output sigmoid(total-weighted-sum) ; Apply sigmoid activation function
         set hidden-layer-prey replace-item i hidden-layer-prey sigmoid-output ; Replace hidden layer items with calculated values
         set i i + 1 ; Increment outer loop
    ]

    ; DEBUG START <-------
    ; print access-weights
    ; print hidden-layer
    ; DEBUG END <---------

    ; Variables for the output layer
    let access-weights-output [weights] of chromo ; Get the weights of a chromosome
    let k 0 ; Index for outer output-layer loop
    let l 0 ; Index for inner hidden-inputs loop
    let total-weighted-sum-output 0

    ; Calculate OUTPUT layer
    foreach output-layer-prey [ o -> ; Loop through output layer
     foreach hidden-layer-prey [ hidden-value -> ; Calculate weighted sum for each neuron (hidden-output)
       let weight item l access-weights-output ; Get the weight from l index
       set total-weighted-sum-output total-weighted-sum-output + (hidden-value * weight) ; Calculate weighted sum
        set l l + 1 ; Increment inner loop
      ]
      set total-weighted-sum-output total-weighted-sum-output + bias ; Add bias
      let sigmoid-output-layer sigmoid(total-weighted-sum-output) ; Apply sigmoid activation function
      set output-layer-prey replace-item k output-layer-prey sigmoid-output-layer ; Replace output layer items with calculated final values
      set k k + 1 ; Increment outer loop
    ]

    ; DEBUG START <-------
    ; print output-layer-prey
    ; DEBUG END <---------
  ]
end

; SIGMOID FUNCTION
; Takes in a real number as input, squashes it into a range between 0 and 1.
; The output forms and S-shaped curve.
; It introduces non-linearity that enables NN to learn complex data that a linear function cant learn.
to-report sigmoid [x]
  report 1 / (1 + exp (-1 * x))
end

; SETUP SUGAR
to setup-sugar
  if (random 100) < sugar-density [ ; Random sugar distribution
    set pcolor 47 ; Color of a patch (yellow-ish)
    set sugar int (random 50) ; Starting amount of sugar
    set grow-back random 50 ; Random amount of sugar for re-growth
    set sugar-last-consumed 0 ; Default time when sugar was last consumed
    ]
end

; -SETUP BUTTON-
to setup
  clear-all ; Clear the world

  ; Setup neural network(Inputs, Hidden neurons, Outputs)
    setup-nn-prey 3 3 4

  ; Fire/Heat patches setup
  if selected-simulation = "Fire/Heat" [
  ask patches [
    setup-sugar
    if pxcor = min-pxcor
    [ set pcolor red ] ; Make left edge red, to simulate heat/fire
  ]
  ask patches with [ pcolor = black ] [
   set sugar 0 ; Starting black patches have 0 sugar = unusable
    ]
  ]

  ; Water/Flood patches setup
  if selected-simulation = "Flood/Water"[
    ask patches [
    setup-sugar
    if pxcor = min-pxcor
    [ set pcolor blue ] ; Make left edge blue, to simulate flood starting point
  ]
  ask patches with [ pcolor = black ] [
   set sugar 0 ; Starting black patches have 0 sugar = unusable
    ]
  ]

  ask patches [
    setup-sugar
  ]
  ask patches with [ pcolor = black ] [
   set sugar 0 ; Starting black patches have 0 sugar = unusable
    ]

  ; Prey setup
  set-default-shape preys "circle" ; Shape of a prey
  create-preys initial-prey-number [ ; Set initial number of preys
    set color orange
    set size 1.5
    set vision 50
    set speed 1
    set energy random 40 + 20 ; Starting amount of sugar
    set birth-generation 1 ; During which generation a prey was born
    set fitness energy ; Starting fitness = starting energy level
    set personal-chromo one-of chromosomes ; Assign a random chromosome from available chromosomes
    setxy random-xcor random-ycor ; Spawn at random locations
  ]

  set generation 0 ; Starting generation
  reset-ticks
end

;-----------------------------WATER PRESSURE---------------------------------
to calculate-water-pressure
  ask patches [
    set water-pressure 1.2 ; Initialize pressure
    ask neighbors4 [
      if pcolor = blue [
        ; Add pressure from neighboring flooded patches
        set water-pressure water-pressure
      ]
    ]
  ]
end

;-----------------------------SIMULATION GO---------------------------------
to go
  if not any? turtles [ stop ] ; Stop the simulation if no turtles are alive

  if ticks mod gen-tick = 0 and generation > 1 and generation < max-generations [
        ;evolution ; Selection + Crossover + Mutation + Hatching
        ask preys [ calculate-fitness ticks ]
        set generation generation + 1
  ]
  ask preys[
      feedforward-prey personal-chromo ; Passing individual chromosome to neural network
      move-prey
      eat-sugar-prey
      ]

  ; If fire/heat simulation selected
  if selected-simulation = "Fire/Heat"[
   ask patches with [ pcolor = red ] [
    ask neighbors4 with [ pcolor = 47 ] [ ; Find neighbours with sugar around the red patch
      let probability fire-spread-probability ; Fire/Heat spread probability
      let direction towards myself ; Direction from sugar towards fire/heat(myself)

      ; Create a slider if you want to adjust wind directions, fire will spread in different ways
      ; If fire is on north side, south wind delays the fire spread and reduce the probability of spread
      if direction = 0 [
        set probability probability - south-wind
      ]
      ; If fire is on east side, west wind delays the fire spread and reduce the probability of spread
      if direction = 90 [
        set probability probability - west-wind
      ]
      ; If fire is on south side, south wind aids the fire spread and increase the probability of spread
      if direction = 180 [
        set probability probability + south-wind
      ]
      ; If fire is on west side, west wind aids the fire spread and increase the probability of spread
      if direction = 270 [
        set probability probability + west-wind
      ]
      if random 100 < probability [
        set pcolor red ; Spread heat/fire
      ]
    ]
    set pcolor red - 3 ; New color for patches after fire
    set sugar 0 ; Sugar patch burnt
    ]
  ]

  ; If flood/water simulation selected
  if selected-simulation = "Flood/Water"[
    calculate-water-pressure
   ask patches with [ pcolor = blue ] [
    ask neighbors4 with [ pcolor = 47 ] [ ; Find neighbours with sugar around the blue patch
      let probability flooding-probability * water-pressure; Flood/Water spread probability
      let direction towards myself ; Direction from sugar towards flood/water(myself)

      if random 100 < probability [
        set pcolor blue ; Spread flood/water

          ask preys-here [ ; Kill preys if they appear on a blue patch
        set energy 0
         ]
      ]
    ]
    set pcolor blue - 1.5 ; New color for patches after flood
    set sugar 0 ; Flooded patch looses all sugar
    ]
  ]

  update-patches
  tick ; Increase the tick counter by 1 each time
end

; UPDATE PATCHES
to update-patches
  ask patches [ update-patch ]
end

to update-patch
   if selected-simulation = "Fire/Heat"[
  ; Grow patch if sugar is < 21 and > 0, every 5 ticks after 10 ticks if its not a red patch
  if sugar < 21 and sugar > 0 and ticks mod 5 = 0 and ticks >= sugar-last-consumed + 8 and (pcolor != red - 3) [
    set sugar min (list 100 (sugar + grow-back)) ; Re-grow sugar patch
    set pcolor 47;
    ]
  ]

  if selected-simulation = "Flood/Water"[
    ; Grow patch if sugar is < 21 and > 0, every 5 ticks after 10 ticks if its not a blue patch
  if sugar < 21 and sugar > 0 and ticks mod 5 = 0 and ticks >= sugar-last-consumed + 8 and (pcolor != blue - 1.5) [
    set sugar min (list 100 (sugar + grow-back)) ; Re-grow sugar patch
    set pcolor 47;
    ]
  ]
end

;-----------------------------MOVEMENT---------------------------------
; MOVE PREY
to move-prey
  let outputs output-layer-prey ; Store all outputs

  let turn-left-output item 0 outputs
  let turn-right-output item 1 outputs
  let accelerate-output item 2 outputs
  let decelerate-output item 3 outputs

  ; DEBUG START <----------
  ; print outputs
  ; DEBUG END <------------

    ifelse turn-left-output > turn-right-output [ ; If output 0 > output 1
      rt turn-left-output * turn-sensitivity ; Right turn
      set energy energy - 2
      check-death
    ] [
      lt turn-right-output * turn-sensitivity ; Otherwise left turn
      set energy energy - 2
      check-death
    ]

    if accelerate-output > decelerate-output [ ; If output 3 > output 4
      fd speed * speed-sensitivity ; Move forward faster
      set energy energy - 2
      check-death
    ]

    if decelerate-output > 0.6 [ ; If output 4 > 0.6
      fd speed * (1 - speed-sensitivity) ; Move forward slower
      set energy energy - 2
      check-death
    ]

     let turn-difference turn-left-output - turn-right-output ; Calculate the difference between turns
    if abs turn-difference > 0.2 [ ; If absolute value > 0.2
      ifelse turn-difference > 0.1 [
        rt turn-difference * turn-sensitivity
        set energy energy - 2
        check-death
      ] [
        lt turn-difference * turn-sensitivity
        set energy energy - 2
        check-death
      ]
    ]
end

;-----------------------------FEED---------------------------------
; PREY EAT SUGAR
to eat-sugar-prey
  ask preys [
    if energy < maxEnergy [ ; If prey holds less sugar than maximum allowed
      if pcolor = 47 [
        set pcolor black
        let sugar-consumed min (list [sugar] of patch-here (maxEnergy - energy)) ; Calculate how much sugar was consumed
        set energy (energy + [sugar] of patch-here) ; Take sugar from patch and add it to prey

        ask patch-here [
          set sugar sugar - sugar-consumed ; Subtract the consumed amount of sugar from patch
          set sugar-last-consumed ticks ; Update timer
        ]
      ]
    ]
  if energy > maxEnergy [ set energy maxEnergy ] ; If the energy goes above maxEnergy, set it to maxEnergy
  ]
end

;-----------------------------CHECK-DEATH---------------------------------
to check-death
  ask preys [
    if energy <= 0 [
      set prey-death-count (prey-death-count + 1)
      die
    ]
  ]
end

;-----------------------------GENETIC ALGORITHM---------------------------------
; FITNESS CALCULATION
to calculate-fitness [ current-tick ]
  ; If tick is 0 (which will be at start), set fitness to only current energy
  ifelse current-tick = 0 [
    set fitness energy
  ] [
    let fitness-calc energy / current-tick ; Fitness = current energy / ticks (time survived)
    set fitness fitness-calc ; Set fitness
  ]
end

; TOURNAMENT SELECTION
to-report selection [ turtle-pool ]
  let parents [] ; Empty list

  ; Repeat a number of times (slider settings)
  ; Select randomly 2 candidates
  repeat repeat-tournament-num [
    let candidateA one-of turtle-pool
    let candidateB one-of turtle-pool
  ; If the candidate is the same turtle, select a new candidateB
    while [candidateA = candidateB] [
      set candidateB one-of turtle-pool
    ]
  ; Compare fitness of both candidates and select the winner (one with higher fitness)
    let winner ifelse-value [fitness] of candidateA > [fitness] of candidateB [candidateA] [candidateB]
    set parents lput winner parents
  ]

  report parents
end

; UNIFORM CROSSOVER
to-report crossover [parent1 parent2]
  ; Getting parent chromosomes
  let parent1-chromo [personal-chromo] of parent1
  let parent2-chromo [personal-chromo] of parent2

  ; Access weights
  let access-weights-parent1 [weights] of parent1-chromo
  let access-weights-parent2 [weights] of parent2-chromo

  ; Empty child list for chromosomes
  let child-chromo1 []
  let child-chromo2 []

  ; Uniform crossover
  let p 0
  foreach access-weights-parent1 [ gene ->
    ifelse random-float 1 < 0.5 [ ; 50% chance to swap
      set child-chromo1 lput gene child-chromo1
      set child-chromo2 lput item p access-weights-parent2 child-chromo2
    ] [
      set child-chromo1 lput item p access-weights-parent2 child-chromo1
      set child-chromo2 lput gene child-chromo2
    ]
    set p p + 1
  ]

  report (list child-chromo1 child-chromo2)
end

; MUTATION
to mutate

end

; HATCHING
to hatch-offspring [mut-chromo]

end

; EVOLUTION <---------
to evolution
  ; Create old generation, do not include new offsprings
  let old-generation-prey (turtle-set preys)

  let prey-parents selection preys

  ; Crossover and mutation
  ; PREY
  foreach prey-parents [

    ; Separate both parents into parent1 and parent2
    let parent-pair prey-parents
    let parent1 item 0 parent-pair
    let parent2 item 1 parent-pair

    let crossed-children crossover parent1 parent2
  ]

  ask old-generation-prey [die]
end

; TEST SIMULATION #3 - ONLY PREY
; Copyright 2024 Edgar Park.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
451
14
882
446
-1
-1
3.0
1
10
1
1
1
0
1
1
1
-70
70
-70
70
0
0
1
ticks
30.0

BUTTON
41
161
109
195
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
38
198
113
234
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
315
37
444
70
initial-prey-number
initial-prey-number
0
100
10.0
1
1
NIL
HORIZONTAL

PLOT
892
15
1285
190
Prey Stats
Ticks
Total
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Preys" 1.0 0 -817084 true "" "plot count preys"
"Prey Birth" 1.0 0 -204336 true "" "plot prey-birth-count"
"Prey Death" 1.0 0 -10146808 true "" "plot prey-death-count"

MONITOR
892
201
982
246
Total Preys
count preys
17
1
11

BUTTON
19
93
133
127
Setup Sim
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

MONITOR
994
257
1086
302
Total Sugar
count patches with [pcolor = 47]
17
1
11

MONITOR
993
202
1086
247
Prey Deaths
prey-death-count
17
1
11

MONITOR
1096
202
1183
247
Preys Born
prey-birth-count
17
1
11

SLIDER
198
37
306
70
maxEnergy
maxEnergy
0
150
100.0
1
1
NIL
HORIZONTAL

SLIDER
316
73
444
106
prey-carrying-capacity
prey-carrying-capacity
0
1000
90.0
1
1
NIL
HORIZONTAL

TEXTBOX
30
10
133
28
Simulation Setup
13
0.0
1

TEXTBOX
32
140
133
158
Start Simulation
13
0.0
1

TEXTBOX
288
10
339
28
Settings
13
0.0
1

SLIDER
197
73
307
106
sugar-density
sugar-density
0
100
75.0
1
1
NIL
HORIZONTAL

SLIDER
0
382
156
415
fire-spread-probability
fire-spread-probability
0
100
70.0
1
1
%
HORIZONTAL

PLOT
892
310
1285
446
Sugar/Fire/Flood Stats
Ticks
Total Patches
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Sugar" 1.0 0 -1184463 true "" "plot count patches with [pcolor = 47]"
"Flood/Water" 1.0 0 -13345367 true "" "plot count patches with [pcolor = blue - 1.5]"
"Fire/Heat" 1.0 0 -5298144 true "" "plot count patches with [pcolor = red - 3]"

CHOOSER
9
38
147
83
selected-simulation
selected-simulation
"Fire/Heat" "Flood/Water"
1

SLIDER
0
343
155
376
flooding-probability
flooding-probability
0
100
31.0
1
1
%
HORIZONTAL

TEXTBOX
7
323
163
341
Environmental Change settings
10
0.0
1

SLIDER
20
455
136
488
south-wind
south-wind
-25
25
-9.0
1
1
NIL
HORIZONTAL

SLIDER
20
419
136
452
west-wind
west-wind
-25
25
10.0
1
1
NIL
HORIZONTAL

SLIDER
315
240
445
273
mutation-rate
mutation-rate
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
315
202
444
235
crossover-rate
crossover-rate
0
1
0.74
0.01
1
NIL
HORIZONTAL

TEXTBOX
321
141
438
159
Genetic Algorith settings
10
0.0
1

SLIDER
598
458
690
491
gen-tick
gen-tick
0
100
15.0
1
1
NIL
HORIZONTAL

MONITOR
695
452
816
497
Current Generation
generation
17
1
11

SLIDER
314
163
444
196
max-generations
max-generations
0
500
100.0
1
1
NIL
HORIZONTAL

SLIDER
314
339
445
372
efficiency-weight
efficiency-weight
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
314
377
446
410
distance-weight
distance-weight
0
1
0.4
0.1
1
NIL
HORIZONTAL

TEXTBOX
474
461
598
487
After how many ticks new generation occurs->
10
0.0
1

SLIDER
315
279
446
312
mutation-magnitude
mutation-magnitude
0
1
0.2
0.01
1
NIL
HORIZONTAL

TEXTBOX
344
319
426
337
Fitness settings
10
0.0
1

TEXTBOX
206
345
317
371
Sugar to energy conversion-> Reward
10
0.0
1

TEXTBOX
201
381
322
406
Distance to predator-> Penalty
10
0.0
1

TEXTBOX
354
431
398
449
Selection
10
0.0
1

SLIDER
308
451
458
484
repeat-tournament-num
repeat-tournament-num
0
100
2.0
1
1
NIL
HORIZONTAL

TEXTBOX
165
146
278
164
Neural Network settings
10
0.0
1

SLIDER
165
165
274
198
turn-sensitivity
turn-sensitivity
0
1
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
166
202
274
235
speed-sensitivity
speed-sensitivity
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
166
240
293
273
num-chromosomes
num-chromosomes
0
500
50.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

A predator-prey simulation

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
NetLogo 6.4.0
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
