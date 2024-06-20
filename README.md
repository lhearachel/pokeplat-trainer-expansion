# Pokemon Platinum Trainer Expansion

This is a reimplementation of Pokemon Platinum's NPC trainer data routines
using `armips`. The aim is to optimize the original code from the vanilla game
in order to build additional functionality into the newly-freed space.

At present, this reimplementation only targets US copies of Pokemon Platinum.

## Requirements

Only `git` and `make` are required to build the modified ROM. All other
dependencies will be fetched by the `make` process.

## Installation

1. `git clone --recursive https://github.com/lhearachel/pokeplat-trainer-expansion`
2. Copy your Pokemon Platinum ROM into the cloned directory.
3. `cd pokeplat-trainer-expansion`
4. `make`
