#!/bin/bash

test()
{
    echo ./neparsy -c "src/$1.d" "src_np/$1.np"
    ./neparsy -c "src/$1.d" "src_np/$1.np" > /dev/null
    echo ./neparsy -c "src_np/$1.np" "src_np/$1_.np"
    ./neparsy -c "src_np/$1.np" "src_np/$1_.np" > /dev/null
    echo ./neparsy -c "src_np/$1.np" "src_recreated/$1.d"
    ./neparsy -c "src_np/$1.np" "src_recreated/$1.d" > /dev/null

    diff -q "src_np/$1.np" "src_np/$1_.np" &&
    diff -q "src_np/$1.inp" "src_np/$1_.inp" &&
    diff -q "src/$1.d" "src_recreated/$1.d"
}

test2()
{
    rm "src_np/$1.inp"
    echo "[WITHOUT .inp]" ./neparsy -c "src_np/$1.np" "src_np/$1_.np"
    ./neparsy -c "src_np/$1.np" "src_np/$1_.np" > /dev/null
    echo "[WITHOUT .inp]" ./neparsy -c "src_np/$1.np" "src_recreated/$1.d"
    ./neparsy -c "src_np/$1.np" "src_recreated/$1.d" > /dev/null

    diff -q "src_np/$1.np" "src_np/$1_.np"
}

swap_dirs()
{
    mv "$1" "$1_" &&
    mv "$2" "$1" &&
    mv "$1_" "$2"
}

mkdir -p src_np src_recreated
 
test parser && 
    test main && 
    test lexer && 
    test iface && 
    test expression &&
    echo "1. Test success" || { echo "1. Test failed" && exit 1; }

test2 parser &&
    test2 main &&
    test2 lexer &&
    test2 iface &&
    test2 expression &&
    echo "2. Test success" || { echo "2. Test failed" && exit 1; }

swap_dirs src src_recreated && dub build &&
    swap_dirs src src_recreated &&
    test parser &&
    test main &&
    test lexer &&
    test iface &&
    test expression &&
    { echo "3. Test success"; dub build; } ||
    { echo "3. Test failed"; dub build; exit 1; }

echo ./neparsy -b test_code/c2d.np test_code/c/hello.c test_code/c/hello.d
./neparsy -b test_code/c2d.np test_code/c/hello.c test_code/c/hello.d > /dev/null
dmd -of=test_code/c/hello test_code/c/hello.d
test_code/c/hello | grep -q "Hello, world!" &&
    echo "4. Test success" || { echo "4. Test failed" && exit 1; }
