---- MODULE Mock ----
EXTENDS Naturals
VARIABLES state
Init == state = "Init"
Next == state' = state
====