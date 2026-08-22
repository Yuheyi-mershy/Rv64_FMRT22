#!/bin/bash

vcs +v2k \
    -full64 \
    -f ../cfg/verify.vfl \
    -sverilog \
    +vcs+loopreport \
    -debug_all \
    -debug_access+all \
    +notimingcheck \
    +nospecify \
    -R \
    -top top_tb \
    -l vcs.log \
