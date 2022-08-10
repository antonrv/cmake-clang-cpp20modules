cmake_minimum_required(VERSION 3.22)
project(main)

set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(../../ClangCpp20modules.cmake)

add_module(foo
    INTERFACE
    foo.cppm
    IMPLEMENTATIONS
    foo.cpp
    )

add_module(bar
    INTERFACE
    bar.cppm
    IMPLEMENTATIONS
    bar.cpp
    MODULES
    foo)

add_target_from_modules(
    foobar
    TYPE
    library
    MODULES
    bar
    foo
)

add_target_from_modules(
    main
    TYPE
    executable
    IMPLEMENTATIONS
    main.cpp
    MODULES
    bar
    LIBRARIES
    foobar
)
