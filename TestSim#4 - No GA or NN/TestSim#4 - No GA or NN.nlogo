;-----------------------------GLOBAL VARIABLES---------------------------------
globals [
  ; Birth
  prey-death-count
  prey-birth-count
  ; Death
  predator-death-count
  predator-birth-count
  ; Sugar
  initial-sugar ; Starting amount of sugar patches
  sugar-regrowth-delay
]

;-----------------------------BREEDS---------------------------------
breed [ predators predator ]
breed [ preys prey ]

;-----------------------------SHARED PROPERTIES---------------------------------
patches-own [
  sugar ; Amount of sugar patches hold
  grow-back ; Re-grow sugar patches
  sugar-last-consumed ; Holds time when the patch was last consumed and can re-grow after some time
  water-pressure
]
turtles-own [
  vision ; Using in-cone vision to see ahead
  energy ; How much sugar prey holds
  speed ; How fast turtle goes
]

;-----------------------------SETUP---------------------------------
; SETUP SUGAR
to setup-sugar
  if (random 100) < sugar-density [ ; Random sugar distribution
    set pcolor 47 ; Color of a patch (yellow-ish)
    set sugar int (random 50) ; Starting amount of sugar
    set grow-back random 50 ; Random amount of sugar for re-growth
    set sugar-last-consumed 0 ; Default time when sugar was last consumed
    ]
end

; SETUP BUTTON
to setup
  clear-all ; Clear the world

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

  ; Prey setup
  set-default-shape preys "circle" ; Shape of a prey
  create-preys initial-prey-number [ ; Set initial number of preys
    set color orange
    set size 1
    set vision 50
    set speed 1
    set energy random 50 + 20 ; Starting amount of sugar
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

  ask preys[
    if any? preys [
      move-prey
      eat-sugar-prey
      reproduce-prey
      ]
    ]

  ask predators [
    if any? predators [
    move-pred
    kill-prey
    reproduce-pred
    ]
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
      ask predators-here [ ; Kill predators if they appear on a blue patch
        set energy 0
         ]
      ]
    ]
    set pcolor blue - 1.5 ; New color for patches after flood
    set sugar 0 ; Flooded patch looses all sugar
    ]
  ]

  update-patches
  tick ; Increase the tick counter + 1
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
  let best-patch max-one-of patches in-cone vision 50 [ sugar ] ; Find a patch with most sugar within radius
  if best-patch != nobody [ ; If the patch is found
    ifelse random 100 < 45 [  ; Random movement chance
      random-movement
    ] [
      face best-patch  ; Face the patch with most sugar
      fd speed ; Move forward
      ]
      set energy energy - 4
      check-death
      ]
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

;-----------------------------REPRODUCTION---------------------------------
; PREY REPRODUCTION
to reproduce-prey
  ask preys [
    if energy > 90 and count preys < prey-carrying-capacity [  ; If collected sugar is above 89 and carrying capacity is not max
      set energy int (energy / 2) ; Divide the energy between parent and offspring
      set prey-birth-count (prey-birth-count + 1) ; Count how many are born
      ; Hatch an offspring and move it forward by 1 step, set birth generation
      hatch int (1) [
        rt random-float 360
        fd 1
      ]
    ]
  ]
end

to reproduce-pred
  if energy > 89 and count predators < predator-carrying-capacity [
 set energy int (energy / 2) ; Take half of the predators energy
 set predator-birth-count (predator-birth-count + 1)
 hatch int (1) [ ; Hatch an offspring and move it
   rt random-float 360
   fd 1
    ]
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

; TEST SIMULATION #4 - No GA or NN
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
160
38
292
71
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
171
115
279
148
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
299
39
447
72
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
34
10
137
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
275
10
326
28
Settings
13
0.0
1

SLIDER
317
116
426
149
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
222
250
373
283
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

SLIDER
159
76
293
109
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
299
76
448
109
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
222
206
372
239
flooding-probability
flooding-probability
0
100
70.0
1
1
%
HORIZONTAL

TEXTBOX
227
186
383
204
Environmental Change settings
10
0.0
1

SLIDER
239
323
355
356
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
239
287
355
320
west-wind
west-wind
-25
25
10.0
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
