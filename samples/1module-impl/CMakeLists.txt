cmake_minimum_required(VERSION 3.22)
project(main)

set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(../../ClangCpp20modules.cmake)

add_module(helloworld
    INTERFACE
    api/helloworld.cppm
    SOURCES
    src/helloworld.cpp
    )

add_target_from_modules(
    libhw
    TYPE
    library
    SOURCES
    DEPENDS
    helloworld
)

add_target_from_modules(
    main
    TYPE
    executable
    SOURCES
    entry/main.cpp
    DEPENDS
    helloworld
)
