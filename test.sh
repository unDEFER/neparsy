#!/bin/bash

test()
{
    ./neparsy -c "src/$1.d" "$1.np" > /dev/null
    ./neparsy -c "$1.np" "$1_.np" > /dev/null
    ./neparsy -c "$1.np" "$1.d" > /dev/null

    diff -q "$1.np" "$1_.np" &&
    diff -q "$1.inp" "$1_.inp" &&
    diff -wq "src/$1.d" "$1.d"
}

test parser && test main && test lexer && echo "Test success" || echo "Test failed"
