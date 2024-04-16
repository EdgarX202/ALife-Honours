 ;-----------------------------GLOBAL VARIABLES---------------------------------
globals [
  ; Birth
  prey-death-count
  prey-birth-count
  ; Death
  predator-death-count
  predator-birth-count
  ; Sugar
  initial-sugar
  sugar-regrowth-delay
  ; GA
  generation
  ; NN
  input-layer
  hidden-layer
  output-layer
  output-values
]

;-----------------------------BREEDS---------------------------------
breed [ predators predator ]
breed [ preys prey ]
breed [ neurons neuron ]
breed [ chromosomes chromosome ]

;-----------------------------SHARED PROPERTIES---------------------------------
chromosomes-own [
  weights
]

patches-own [
  sugar
  grow-back
  sugar-last-consumed
]
turtles-own [
  vision
  energy
  speed
  birth-generation
  fitness
]

;-----------------------------SETUP---------------------------------
; SETUP NEURAL NETWORK
to setup-nn [input-size hidden-size output-size]
  set input-layer input-size
 set hidden-layer []  ; Start with an empty list
  repeat hidden-size [
    set hidden-layer lput 0 hidden-layer  ; Add 0 as initial values
  ]
  set output-layer output-size

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
to feedforward [chromo]
  ask preys [
    ; Calculations for INPUT layer
    ; Create new variable for storing single predator and single patch of sugar
    let predatorX one-of predators
    let food one-of patches with [sugar > 0]

    ; Get distance to predator/sugar
    let distance-to-predator calculate-distance predatorX
    let distance-to-food ifelse-value (food != nobody) [calculate-distance food] [0]

    ; Get the list of INPUTS
    let total-inputs (list distance-to-predator distance-to-food energy speed)

    ; DEBUG START <-----
    ; print total-inputs
    ; DEBUG END <-------

    ; Variables for the hidden layer
    let bias (random-float 2 - 1) ; Random bias -1 to 1
    let current-weight-index 0 ; Tracking which weight we are calculating
    let total-hidden-neurons length hidden-layer ; Get the number of hidden neurons
    let i 0 ; Variable for counter
    let current-hidden-neuron 0 ; Store calculated neuron value

    ; Variables for the output layer
    let j 0
    set output-values []

    ; Calculate HIDDEN layer
    ask neurons [
      foreach total-hidden-neurons [ ; Loop through neurons
        ; Calculate weighted sum for a hidden neuron using weight and input value
        let updated-neuron (item i total-inputs * weights) + bias
        set current-hidden-neuron updated-neuron ; Storing values
        set i i + 1 ; Increment iteration

        set weights item current-weight-index chromo ; Get the weight from the chromosome
        set current-weight-index current-weight-index + 1 ; Increment index counter

        ; Activation function
        set hidden-layer replace-item i hidden-layer sigmoid(current-hidden-neuron)
      ]
    ]

    ; Calculate OUTPUT layer

    foreach hidden-layer [ ; Loop through outputs
      let curr-weight-out-index 0
      ; Calculate weighted sum using weights and hidden layer values
      let updated-neuron (item j hidden-layer * weights) + bias
      let current-output-neuron updated-neuron ; Storing values
      set j j + 1 ; Increment iteration

      set weights item curr-weight-out-index chromo ; Get the weight from the chromosome
      set curr-weight-out-index curr-weight-out-index + 1 ; Increment index counter

      ; Activation function
      set current-output-neuron sigmoid(current-output-neuron) ; Apply sigmoid

      ; Append result to output list
      set output-values lput current-output-neuron output-values
    ]


    ; DEBUG START <-------
      print output-values ; Should be a list of numbers between 0 and 1 ?
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

  ; Setup neural network(4 Inputs, 4 Hidden neurons, 4 Outputs)
    setup-nn 4 4 4

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
    setxy random-xcor random-ycor ; Spawn at random locations
  ]

  ; Predator setup
  set-default-shape predators "square" ; The shape of a predator
  create-predators initial-predator-number [
    set color green
    set size 1.5
    set vision 50
    set speed 1.2 ; 0.2 faster than prey
    set energy random 50 + 30 ; Starting amount of energy
    setxy random-xcor random-ycor ; Spawn at random locations
  ]

  set generation 0 ; Starting generation
  reset-ticks
end

;-----------------------------SIMULATION GO---------------------------------
to go
  if not any? turtles [ stop ] ; Stop the simulation if no turtles are alive
if ticks mod gen-tick = 0 and generation < max-generations [ ; gen-tick(slider) ticks = 1 generation
        ;evolution ; Selection + Crossover + Mutation + Hatching
        ;calculate-fitness
        set generation generation + 1

  ask preys[
      let my-chromo one-of chromosomes
      feedforward [weights] of my-chromo

      move-prey
      eat-sugar-prey
      ]
  ]

  ask predators [
      move-pred
      kill-prey
  ]

  update-patches
  tick ; Increase the tick counter by 1 each time
end

; UPDATE PATCHES
to update-patches
  ask patches [ update-patch ]
end

to update-patch
  if sugar < 21 and sugar > 0 and ticks mod 5 = 0 and ticks >= sugar-last-consumed + 8 [
    set sugar min (list 100 (sugar + grow-back)) ; Re-grow sugar patch
    set pcolor 47
  ]
end

;-----------------------------MOVEMENT---------------------------------
; MOVE PREY
to move-prey
  ; MAKE SURE THAT ACTIVATION FUNCTION DOESNT ACTIVATE ALL AT ONCE...
  ; CREATE IT SO IT CHOOSES ONE FROM LEFT/RIGHT AND ONE FROM ACCELERATE/DECELERATE

  ;let outputs output-values
  ;let turn-left item 0 outputs
  ;let turn-right item 1 outputs
  ;let accelerate item 2 outputs
  ;let decelerate item 3 outputs

  ; Output 0
  ;if turn-left > turn-right [
   ; rt (turn-left * turn-sensitivity * 180)
   ; set energy energy - 2
   ; check-death]
  ; Output 1
  ;if turn-right > turn-left [
   ; lt (turn-right * turn-sensitivity * 180)
   ; set energy energy - 2
   ; check-death]
  ; Output 2
  ;if accelerate > decelerate [
   ; fd (accelerate * speed-sensitivity)
   ; set energy energy - 2
   ; check-death]
  ; Output 3
  ;if decelerate > accelerate [
   ; let reverse-speed (-1 * decelerate * speed-sensitivity) ; Negative value for reverse movement
   ; fd reverse-speed
   ; set energy energy - 0.5 ; Less energy cost for deceleration
   ; check-death]
end

; MOVE PREDATOR
to move-pred
  let prey-target one-of preys in-cone vision 50 ; Find any prey within the vision cone
  if prey-target != nobody [
      face prey-target ; Face the prey and move towards it
      fd 1
    ]
  set energy energy - 2
  check-death
end

; RANDOM MOVEMENT
to random-movement
  rt random 50 ; Right turn
  lt random 50 ; Left turn
  fd 1 ; Forward

  set energy energy - 2
  check-death
end

;-----------------------------FEED/KILL---------------------------------
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

; PREDATOR KILL PREY
to kill-prey
 ask predators [
    let prey-target one-of preys-here ; Find a prey on the same patch
    if prey-target != nobody [
      let prey-energy [energy] of prey-target ; Get the energy of the prey
      ask prey-target [ die ] ; Kill prey
      set prey-death-count (prey-death-count + 1)

      if energy < maxEnergy [
        set energy energy + prey-energy ; Collect energy from prey
      ]
    ]
    if energy > maxEnergy [ set energy maxEnergy ]
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
  ask predators [
    if energy <= 0 [
      set predator-death-count (predator-death-count + 1)
      die
    ]
  ]
end

;-----------------------------GENETIC ALGORITHM---------------------------------
; FITNESS
; (1 / (distance-from-predator + 1) - inverts value and adds 1. If distance increases, the value gets smaller
; Add 1 to ensure expression doesnt become undefined when 0
; "efficiency-weight": Higher weight to indicate that converting sugar to energy (efficiency) is a significant factor
; "distance-weight": Lower weight to indicate that prey should keep more distance from presdators
to calculate-fitness
  ask preys [
    ; Get the chromosome
    let chromo one-of chromosomes

    let efficiency ifelse-value any? chromo [energy / sum chromo] [0] ; <--- CHANGE THIS TO JUST ENERGY??
    let distance-from-predator ifelse-value any? predators [min [distance myself] of predators] [0] ; Minimum distance to any predator, 0 if no predators alive
    let fitness-calc efficiency-weight * efficiency + distance-weight * (1 / (distance-from-predator + 1)) ; Calculate fitness

    set fitness round fitness-calc ; Set fitness (round the number)
  ]
end

; TOURNAMENT SELECTION
to-report selection
  let parents [] ; Empty list

  ; Repeat a number of times (slider settings)
  ; Select randomly 2 candidates
  repeat parents-num [
    let candidateA one-of preys
    let candidateB one-of preys
  ; If the candidates are the same prey, select a new candidateB
    while [candidateA = candidateB] [
      set candidateB one-of preys
    ]
  ; Compare fitness of both candidates and select the winner (one with higher fitness)
    let winner ifelse-value [fitness] of candidateA > [fitness] of candidateB [candidateA] [candidateB]
    set parents lput winner parents
  ]

  report parents
end

; CROSSOVER + MUTATION
to-report crossover-mutate [parent1 parent2]
  ; Get parent chromosomes
  let parent1-chromo [chromosomes] of parent1
  let parent2-chromo [chromosomes] of parent2

  ; Perform one point crossover **

end



to hatch-offspring [mut-chromo]
  hatch 1 [
    set energy random 60 + 20 ; Give random energy 60-80
    set weights mut-chromo ; Give mutated chromosome
    set birth-generation generation
    set color red
    rt random-float 360
    fd 1
  ]
end

; EVOLUTION <---------
to evolution
  ; Create old generation, do not include new offsprings
  let old-generation (turtle-set preys)

  let selected-parents selection

  ; Crossover and mutation
  foreach selected-parents [

    ; Separate both parents into parent1 and parent2
    let parent-pair selected-parents
    let parent1 item 0 parent-pair
    let parent2 item 1 parent-pair

    let crossed-children crossover-mutate parent1 parent2
   ; let child1 item 0 crossed-children

    ;mutate child1
    ;hatch-offspring child1
  ]

  ask old-generation [die]
end

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
42
100
110
134
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
39
137
114
173
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
176
31
308
64
initial-prey-number
initial-prey-number
0
100
50.0
1
1
NIL
HORIZONTAL

PLOT
892
15
1285
190
Prey-Predator Stats
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
"Predators" 1.0 0 -15040220 true "" "plot count predators"
"Prey Birth" 1.0 0 -204336 true "" "plot prey-birth-count"
"Predator Birth" 1.0 0 -2754856 true "" "plot predator-birth-count"
"Prey Death" 1.0 0 -10146808 true "" "plot prey-death-count"
"Predator Death" 1.0 0 -16110067 true "" "plot predator-death-count"

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
20
32
134
66
Setup
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
1195
226
1287
271
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
328
106
436
139
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
317
32
447
65
prey-carrying-capacity
prey-carrying-capacity
0
1000
200.0
1
1
NIL
HORIZONTAL

TEXTBOX
33
79
134
97
Start Simulation
13
0.0
1

TEXTBOX
290
11
341
29
Settings
13
0.0
1

SLIDER
191
106
296
139
sugar-density
sugar-density
0
100
50.0
1
1
NIL
HORIZONTAL

PLOT
892
310
1285
446
Sugar Stats
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

SLIDER
175
69
309
102
initial-predator-number
initial-predator-number
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
317
69
448
102
predator-carrying-capacity
predator-carrying-capacity
0
1000
200.0
1
1
NIL
HORIZONTAL

MONITOR
892
252
983
297
Total Predators
count predators
17
1
11

MONITOR
993
253
1086
298
Predator Deaths
predator-death-count
17
1
11

MONITOR
1097
253
1183
298
Predators Born
predator-birth-count
17
1
11

SLIDER
320
181
444
214
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
318
261
445
294
mutation-rate
mutation-rate
0
1
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
319
221
444
254
crossover-rate
crossover-rate
0
1
0.7
0.1
1
NIL
HORIZONTAL

TEXTBOX
318
161
447
179
Genetic Algortithm settings
10
0.0
1

MONITOR
239
180
312
225
NIL
generation
17
1
11

SLIDER
222
230
314
263
gen-tick
gen-tick
0
100
15.0
1
1
NIL
HORIZONTAL

TEXTBOX
96
232
218
258
After how many ticks new generation occurs->
10
0.0
1

SLIDER
318
371
445
404
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
318
407
446
440
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
351
356
426
374
Fitness settings
10
0.0
1

TEXTBOX
209
414
319
440
Distance to predator-> Penalty
10
0.0
1

TEXTBOX
215
377
321
403
Sugar to energy conversion-> Reward
10
0.0
1

SLIDER
321
472
448
505
parents-num
parents-num
0
100
2.0
1
1
NIL
HORIZONTAL

TEXTBOX
364
452
411
470
Selection
10
0.0
1

SLIDER
23
311
139
344
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
23
353
140
386
speed-sensitivity
speed-sensitivity
0
1
0.5
0.1
1
NIL
HORIZONTAL

TEXTBOX
28
289
143
307
Neural Network settings
10
0.0
1

SLIDER
73
478
206
511
num-chromosomes
num-chromosomes
0
500
50.0
1
1
NIL
HORIZONTAL

SLIDER
317
300
445
333
mutation-magnitude
mutation-magnitude
0
1
0.2
0.1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

An environmental change simulator with predator-prey agents acting as organisms that try to survive extreme conditions. This project was created as part of Edinburgh Napier University honours project for BSc Games Development course.

The purpose of this simulation is to research predator-prey behaviour and improve its behaviour with the use of neural networks and genetic algorithm. The ultimate goal is to create agents that can learn fast to changing environments and become smarter with each generation while trying to survive extreme environmental conditions.

There are two environmental change scenarios implemented:

1. Wildfire, where sugar(food) patches get burnt and become inedible. The agents can still walk on these patches; however, they will not any food, and therefore die from starvation.

2. Flood/Tsunami event. In this simulation, sugar patches become soaked and inedible. Furthermore, assuming that its deep water, agents cannot walk on it and so they instantly die(drown in water).

Finally, the research conducted in the honours project was about evolutionary algorithms and NEAT, rtNEAT; therefore, an attempt was made to create a simulation in NetLogo that would have a similar behaviour to rtNEAT.

## HOW IT WORKS

Patches: There are few types of patches - water/fire/sugar/inedible.

1. Water - spreads on sugar patches, making them inedible. Flood pressure is added from neighbouring already flooded patches. Any agent in its path will die.

2. Fire - similar behaviour. No pressure, but wind is added that pushes fire to spread across other sugar patches. Wind direction depends on user input.

3. Sugar - this patch only holds random amount of sugar.

4. Inedible - this patch is either damaged by fire/water or it was initialised at the start like this. It holds 0 sugar.

Prey agents: It uses neural network to learn its environment and genetic algorithm to evolve and reproduce. Prey organisms main objective is to gather sugar while evading predators and using energy efficiently. Furthermore, prey should learn the changing environment in a fast manner and with each new generation, adapt new behaviour that would contribute towards a better fitness score.

Predator agents: It works in a similar way and uses a neural network and genetic algorithm hybrid. The only difference is that predator agents don't eat sugar, instead they hunt prey and are more aggressive by nature.

Both predator-prey should avoid water and adapt to changing environment.

## HOW TO USE IT

Right hand side: use monitors and plots to observe predator-prey level change (birth, death, total) and follow sugar levels.

Left hand side: 

1. Settings - adjust sliders to create the environment with more/less predator/preys, adjust their carrying capacity. In addition, use maxEnergy to make sure that agents dont have too much energy (otherwise they would probably start reproduce infinitely). Lastly, sugar-density slider adjusts the distribution of sugar in the simulation.

2. GA settings - adjust maxGeneration for the maximum number of generations that will occur in the simulation. The number of current generation can be seen in the monitor. Also, gen-tick specifies after how many "ticks" a new generation will occur.

Next, crossover-rate is the probability that two selected parent chromosomes will exchange parts of their genetic material to create new offsprings. Mutation-rate is the probability that a single gene within a chromosome will randomly change its value. By adjusting these sliders, we can increase the variation of chromosomes that new offsprings will have.

3. Fitness settings - efficiency-weight, adjust this slider to increase the "reward" for an agent. Better efficiency weight indicates that the agent is efficiently using its sugar/energy. Positive impact.
Distance-weight on the other hand is a negative impact and the lower slider value indicates that an agent is close to a hazard/enemy, and it should learn to keep more distance.

4. Selection settings - adjust the slider to increase/decrease the amount of parents should be selected in "selection" phase. (Tournament selection)

## THINGS TO NOTICE

The behaviour of both prey and predator agents.....MORE TO FOLLOW

## THINGS TO TRY

Feel free to experiment with the simulation by adjusting various sliders.

## EXTENDING THE MODEL

This simulation could be further extended by improving current neural network and genetic algorithm hybrid behaviour. It should eventually replicate NEAT/rtNEAT, also possibly creating a bridge and connecting NetLogo with a 3rd party machine learning framework (using JAVA) that could majorly improve the simulation.

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES
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
