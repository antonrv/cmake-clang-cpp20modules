
set(PREBUILT_MODULE_INTERFACE_PATH 
    ${CMAKE_BINARY_DIR}/modules/intf 
    CACHE INTERNAL
    "PREBUILT_MODULE_INTERFACE_PATH")

set(PREBUILT_MODULE_IMPLEMENTATION_PATH 
    ${CMAKE_BINARY_DIR}/modules/impl
    CACHE INTERNAL
    "PREBUILT_MODULE_IMPLEMENTATION_PATH")

set(PREBUILT_MODULE_LIBRARY_PATH 
    ${CMAKE_BINARY_DIR}/modules/lib
    CACHE INTERNAL
    "PREBUILT_MODULE_LIBRARY_PATH")

set(PREBUILT_MODULE_EXECUTABLE_PATH 
    ${CMAKE_BINARY_DIR}/modules/bin
    CACHE INTERNAL
    "PREBUILT_MODULE_EXECUTABLE_PATH")

function(get_modules_flags imp_modules_flags modules)

    set(flags "")
    foreach(INPUT_MOD ${modules})
        list(APPEND flags "-fmodule-file=${PREBUILT_MODULE_INTERFACE_PATH}/${module2interface_${INPUT_MOD}}")
    endforeach()

    string(REPLACE ";" " " space_flags ${flags})

    set(${imp_modules_flags} ${space_flags} PARENT_SCOPE)

endfunction()

function(add_implementations out_objects)

    file(MAKE_DIRECTORY ${PREBUILT_MODULE_IMPLEMENTATION_PATH})

    set(multiValueArgs IMPLEMENTATIONS MODULES INCLUDE_DIRS)
    cmake_parse_arguments(OBJ "${options}" "${oneValueArgs}"
                          "${multiValueArgs}" ${ARGV})

    # ---- Add flags to include input module interfaces
    set(import_modules_flags "")
    if ("${OBJ_MODULES}" STREQUAL "")
        # Do nothing
    else()
        get_modules_flags(import_modules_flags ${OBJ_MODULES})
    endif()

    # ---- Add flags to include dirs with headers
    set(include_flags "")
    if ("${OBJ_INCLUDE_DIRS}" STREQUAL "")
        # Do nothing
    else()
        get_include_flags(${OBJ_INCLUDE_DIRS} include_flags)
    endif()

    message(STATUS "Include FLAGS: ${include_flags}")

    # ---- Add a custom target for each module implementation
    foreach(SRC ${OBJ_IMPLEMENTATIONS})

        add_custom_target(${SRC}.o
            COMMAND
            ${CMAKE_CXX_COMPILER}
            -std=c++20
            -stdlib=libc++
            -fmodules
            "${import_modules_flags}"
            "${include_flags}"
            -c ${CMAKE_CURRENT_SOURCE_DIR}/${SRC}
            -o "${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${SRC}.o")

        list(APPEND
            "impls"
            ${SRC}.o)

        # ---- These objects depend on precompiled module interfaces
        foreach(IMPORT_MODULE ${OBJ_MODULES})
            add_dependencies(${SRC}.o "${IMPORT_MODULE}.pcm")
        endforeach()

    endforeach()

    set(${out_objects} ${impls} PARENT_SCOPE)

endfunction()

function(get_include_flags inc_dirs out)

    foreach(INPUT_DIR ${inc_dirs})
        list(APPEND inc_flags "-I${CMAKE_SOURCE_DIR}/${INPUT_DIR}")
    endforeach()

    set(${out} ${inc_flags} PARENT_SCOPE)

endfunction()

function(add_module_interface module)

    # set(options OPT1 OPT2)
    set(oneValueArgs INTERFACE)
    set(multiValueArgs IMPLEMENTATIONS MODULES INCLUDE_DIRS)

    cmake_parse_arguments(MODULE "${options}" "${oneValueArgs}"
                          "${multiValueArgs}" ${ARGV}) 

    file(MAKE_DIRECTORY ${PREBUILT_MODULE_INTERFACE_PATH})

    # ---- For each input module Add objects to link (precompiled interface and object module implementations)
    foreach(INPUT_MOD ${MODULE_MODULES})
        list(APPEND link_pcms "-fmodule-file=${PREBUILT_MODULE_INTERFACE_PATH}/${module2interface_${INPUT_MOD}}")
    endforeach()

    foreach(IP ${link_pcms})
        message(STATUS "`${module}` module interface depends on module interface ${IP}")
    endforeach()

    # ---- Add pcm target
    add_custom_target(${module}.pcm
            COMMAND
                ${CMAKE_CXX_COMPILER}
                -std=c++20
                -stdlib=libc++
                -fmodules
                --precompile ${CMAKE_CURRENT_SOURCE_DIR}/${MODULE_INTERFACE}
                ${link_pcms}
                -o ${PREBUILT_MODULE_INTERFACE_PATH}/${MODULE_INTERFACE}.pcm
            )
    set(module2interface_${module} 
        ${MODULE_INTERFACE}.pcm
        CACHE INTERNAL
        "module2interface_${module}")


    foreach(IN_MOD ${MODULE_MODULES})
        add_dependencies(${module}.pcm "${IN_MOD}.pcm")
    endforeach()

endfunction()

function(add_module_implementations module)

    # set(options OPT1 OPT2)
    # set(oneValueArgs INTERFACE)
    set(multiValueArgs IMPLEMENTATIONS MODULES INCLUDE_DIRS)

    cmake_parse_arguments(MODULE "${options}" "${oneValueArgs}"
                          "${multiValueArgs}" ${ARGV})

    file(MAKE_DIRECTORY ${PREBUILT_MODULE_IMPLEMENTATION_PATH})

    set(out_objs "")
    add_implementations(out_objs
        IMPLEMENTATIONS
        ${MODULE_IMPLEMENTATIONS}
        MODULES
        "${module};${MODULE_MODULES}"
        INCLUDE_DIRS
        ${MODULE_INCLUDE_DIRS}
        )

    foreach(OBJ ${out_objs})
        add_dependencies(${OBJ} "${module}.pcm")
    endforeach()

    set_property(
        GLOBAL PROPERTY
        module2implementations_${module} 
        "${out_objs}")

endfunction()

function(add_module module_name)

    # set(options OPTIONAL FAST)
    set(oneValueArgs INTERFACE)
    set(multiValueArgs IMPLEMENTATIONS MODULES INCLUDE_DIRS)

    cmake_parse_arguments(MODULE "${options}" "${oneValueArgs}"
                          "${multiValueArgs}" ${ARGV})

    message(STATUS "Adding module `${module_name}` from interface `${MODULE_INTERFACE}` and implementations: `${MODULE_IMPLEMENTATIONS}`")
    foreach(IN_MOD ${MODULE_MODULES})
        message(STATUS "Module `${module_name}` depends on module `${IN_MOD}`")
    endforeach()

    add_module_interface(${module_name}
        INTERFACE
        ${MODULE_INTERFACE}
        MODULES
        ${MODULE_MODULES}
        INCLUDE_DIRS
        ${INCLUDE_DIRS})

    if ("${MODULE_IMPLEMENTATIONS}" STREQUAL "")
        #nothing
    else()
        add_module_implementations(${module_name}
            IMPLEMENTATIONS
            ${MODULE_IMPLEMENTATIONS}
            MODULES
            ${MODULE_MODULES}
            INCLUDE_DIRS
            ${MODULE_INCLUDE_DIRS})
    endif()

endfunction()

function(add_target_from_modules target_name)

    # set(options OPTIONAL FAST)
    set(oneValueArgs TYPE)
    set(multiValueArgs IMPLEMENTATIONS MODULES INCLUDE_DIRS LIBRARIES)

    cmake_parse_arguments(TARGET
        "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    message(STATUS "Adding `${TARGET_TYPE}` target")

    # ---- For each input module, add objects to link
    # (precompiled interface and object module implementations)
    foreach(INPUT_MOD ${TARGET_MODULES})
        get_property(module_objects
            GLOBAL PROPERTY
            module2implementations_${INPUT_MOD})
        list(APPEND list_link_pcms "${module2interface_${INPUT_MOD}}")
        foreach(INPUT_OBJ ${module_objects})
            list(APPEND list_link_objects "${INPUT_OBJ}")
        endforeach()
    endforeach()

    # ---- For each source, add objects to the list of linkable objects
    set(in_objs "")
    add_implementations(in_objs
        IMPLEMENTATIONS
        ${TARGET_IMPLEMENTATIONS}
        MODULES
        ${TARGET_MODULES}
        INCLUDE_DIRS
        ${TARGET_INCLUDE_DIRS})

    foreach(in_obj ${in_objs})
        list(APPEND list_link_objects "${in_obj}")
    endforeach()

    # ---- Specific info depending on TARGET_TYPE
    if ("${TARGET_TYPE}" STREQUAL "library")
        set(target_binary "${PREBUILT_MODULE_LIBRARY_PATH}/lib${target_name}.so")
        set(type_flag "-shared")
        set(library2linkflag_${target_name}
            "-l${target_name}"
            CACHE INTERNAL
            "library2linkflag_${target_name}")

        file(MAKE_DIRECTORY ${PREBUILT_MODULE_LIBRARY_PATH})

    elseif ("${TARGET_TYPE}" STREQUAL "executable")
        set(target_binary "${PREBUILT_MODULE_EXECUTABLE_PATH}/${target_name}")
        set(type_flag "")

        file(MAKE_DIRECTORY ${PREBUILT_MODULE_EXECUTABLE_PATH})
    else()
        message(FATAL_ERROR "Unknown type ${TARGET_TYPE}")
    endif()

    # ---- Create list of precompiled modules
    foreach(PCM ${list_link_pcms})
        list(APPEND link_pcms ${PREBUILT_MODULE_INTERFACE_PATH}/${PCM})
    endforeach()

    # ---- Create list of link objects
    foreach(LO ${list_link_objects})
        list(APPEND link_objects ${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${LO})
    endforeach()

    # ---- Previous list of objects belongs to library. Store them to prevent double link
    if ("${TARGET_TYPE}" STREQUAL "library")
        set_property(
            GLOBAL PROPERTY
            library2implementations_${target_name}
            "${list_link_objects}")
    endif()

    # ---- Create list of link libraries
    foreach(TLIB ${TARGET_LIBRARIES})
        list(APPEND link_libraries ${library2linkflag_${TLIB}})
        # ---- remove from link_objects those objects in this library
        get_property(lib_impls
            GLOBAL PROPERTY
            library2implementations_${TLIB})

        foreach(LO ${lib_impls})
            list(REMOVE_ITEM link_objects ${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${LO})
        endforeach()
    endforeach()

    # ---- Log messages for feedback
    foreach(LP ${link_pcms})
        message(STATUS "`${target_name} ${TARGET_TYPE}` target depends on module interface ${LP}")
    endforeach()

    foreach(LO ${link_objects})
        message(STATUS "`${target_name} ${TARGET_TYPE}` target depends on object ${LO}")
    endforeach()

    foreach(LL ${link_libraries})
        message(STATUS "`${target_name} ${TARGET_TYPE}` target depends on library ${LL}")
    endforeach()

    # ---- Add custom target
    add_custom_target("${target_name}" ALL
        COMMAND
        ${CMAKE_CXX_COMPILER}
        ${type_flag}
        -stdlib=libc++
        -L${PREBUILT_MODULE_LIBRARY_PATH}
        ${link_pcms}
        ${link_objects}
        ${link_libraries}
        -o ${target_binary})

    # ---- Bind dependencies
    foreach(INPUT_OBJ ${list_link_objects})
        add_dependencies(${target_name} ${INPUT_OBJ})
    endforeach()

    set(target2binary_${target_name}
        ${target_binary}
        CACHE INTERNAL
        "target2binary_${target_name}")

endfunction()
