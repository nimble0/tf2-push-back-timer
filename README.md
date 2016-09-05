# tf2-push-back-timer
Switches attacking team control point to defending (5CP only) when round timer runs out instead of stalemating

## Features

* Changes 5CP round timer to switch a control point in favour of the team with less control points instead of stalemating.
* Adds a cvar to control the length of the round timer

## Usage

* `mp_roundtimelimit` - number of seconds to set the round time limit to

## Requirements

* SourceMod

## Installation

1. Download `tf2-round-clock.smx` from releases or compile `tf2-push-back-timer.sp`

2. Place `tf2-round-clock.smx` in your `tf2/tf/addons/sourcemod/plugins` directory.
