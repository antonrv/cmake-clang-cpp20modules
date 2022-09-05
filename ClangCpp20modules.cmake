if ("${CMAKE_BUILD_TYPE}" STREQUAL "")
    set(BUILD_FLAGS "")
    set(BUILD_DIR "")
else()
    message(STATUS "Build type: ${upper_build_type}")
    string(TOUPPER ${CMAKE_BUILD_TYPE} upper_build_type)
    string(TOLOWER ${CMAKE_BUILD_TYPE} lower_build_type)
    string(REPLACE " " ";" BUILD_FLAGS ${CMAKE_CXX_FLAGS_${upper_build_type}})
    set(BUILD_DIR "${lower_build_type}")
endif()

set(PREBUILT_MODULE_CACHE_PATH
    $ENV{HOME}/.cache/clang/ModuleCache/${BUILD_DIR}
    CACHE INTERNAL
    "PREBUILT_MODULE_CACHE_PATH")

set(PREBUILT_MODULE_INTERFACE_PATH 
    ${CMAKE_BINARY_DIR}/${BUILD_DIR}/pcm
    CACHE INTERNAL
    "PREBUILT_MODULE_INTERFACE_PATH")

set(PREBUILT_MODULE_IMPLEMENTATION_PATH 
    ${CMAKE_BINARY_DIR}/${BUILD_DIR}/obj
    CACHE INTERNAL
    "PREBUILT_MODULE_IMPLEMENTATION_PATH")

set(PREBUILT_MODULE_LIBRARY_PATH 
    ${CMAKE_BINARY_DIR}/${BUILD_DIR}/lib
    CACHE INTERNAL
    "PREBUILT_MODULE_LIBRARY_PATH")

set(PREBUILT_MODULE_EXECUTABLE_PATH 
    ${CMAKE_BINARY_DIR}/${BUILD_DIR}/bin
    CACHE INTERNAL
    "PREBUILT_MODULE_EXECUTABLE_PATH")

function(get_include_flags inc_dirs include_flags)

    foreach(INPUT_DIR ${inc_dirs})
        if (IS_ABSOLUTE ${INPUT_DIR})
            list(APPEND inc_flags "-I${INPUT_DIR}")
        else()
            list(APPEND inc_flags "-I${CMAKE_SOURCE_DIR}/${INPUT_DIR}")
        endif()
    endforeach()

    set(${include_flags} ${inc_flags} PARENT_SCOPE)

endfunction()

function(get_modules_flags import_modules_flags import_modules_interfaces modules)

    set(flags "")
    set(interfaces "")
    foreach(INPUT_MOD ${modules})
        if (IS_ABSOLUTE ${module2interface_${INPUT_MOD}})
            list(APPEND flags "-fmodule-file=${module2interface_${INPUT_MOD}}")
            list(APPEND interfaces ${module2interface_${INPUT_MOD}})
        else()
            list(APPEND flags "-fmodule-file=${PREBUILT_MODULE_INTERFACE_PATH}/${module2interface_${INPUT_MOD}}")
            list(APPEND interfaces ${PREBUILT_MODULE_INTERFACE_PATH}/${module2interface_${INPUT_MOD}})
        endif()
    endforeach()

    set(${import_modules_flags} ${flags} PARENT_SCOPE)
    set(${import_modules_interfaces} ${interfaces} PARENT_SCOPE)

endfunction()

function(add_implementations out_objects)

    file(MAKE_DIRECTORY ${PREBUILT_MODULE_IMPLEMENTATION_PATH})

    set(multiValueArgs SOURCES DEPENDS INCLUDES FLAGS)
    cmake_parse_arguments(OBJ "${options}" "${oneValueArgs}"
                          "${multiValueArgs}" ${ARGV})

    # ---- Add flags to include input module interfaces
    set(import_modules_flags "")
    if ("${OBJ_DEPENDS}" STREQUAL "")
        # Do nothing
    else()
        get_modules_flags(import_modules_flags import_modules_interfaces "${OBJ_DEPENDS}")
    endif()

    # ---- Add flags to include dirs with headers
    set(include_flags "")
    if ("${OBJ_INCLUDES}" STREQUAL "")
        # Do nothing
    else()
        get_include_flags(${OBJ_INCLUDES} include_flags)
    endif()

    # ---- Add a custom target for each module implementation
    foreach(SRC ${OBJ_SOURCES})

        set(target_name ${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${SRC}.o)
        message(STATUS "Adding target implementation ${target_name}")

        get_filename_component(
            this_dir
            ${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${SRC}.o
            DIRECTORY)

        file(MAKE_DIRECTORY ${this_dir})

        add_custom_command(
            OUTPUT
            ${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${SRC}.o
            COMMAND
            ${CMAKE_CXX_COMPILER}
            ${BUILD_FLAGS}
            -fmodules-cache-path=${PREBUILT_MODULE_CACHE_PATH}
            -std=c++20
            -stdlib=libc++
            -fmodules
            -fPIC
            ${OBJ_FLAGS}
            ${import_modules_flags}
            ${include_flags}
            -c ${CMAKE_SOURCE_DIR}/${SRC}
            -o "${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${SRC}.o"
            DEPENDS
            ${module2interface_${IMPORT_MODULE}}
            ${CMAKE_SOURCE_DIR}/${SRC}
            ${import_modules_interfaces}
            )

        list(APPEND
            "impls"
            ${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${SRC}.o)

    endforeach()

    set(${out_objects} ${impls} PARENT_SCOPE)

endfunction()

function(add_module_interface module_name)

    # set(options OPT1 OPT2)
    set(oneValueArgs INTERFACE)
    set(multiValueArgs SOURCES DEPENDS INCLUDES)

    cmake_parse_arguments(MODULE "${options}" "${oneValueArgs}"
                          "${multiValueArgs}" ${ARGV}) 

    set(include_flags "")
    if ("${MODULE_INCLUDES}" STREQUAL "")
        # do nothing
    else()
        get_include_flags("${MODULE_INCLUDES}" include_flags)
    endif()

    file(MAKE_DIRECTORY ${PREBUILT_MODULE_INTERFACE_PATH})

    # ---- For each input module Add objects to link (precompiled interface and object module implementations)
    foreach(INPUT_MOD ${MODULE_DEPENDS})
        if (IS_ABSOLUTE ${module2interface_${INPUT_MOD}})
            set(ROOT_PATH "")
        else()
            set(ROOT_PATH ${PREBUILT_MODULE_INTERFACE_PATH}/)
        endif()
        list(APPEND link_pcms "-fmodule-file=${ROOT_PATH}${module2interface_${INPUT_MOD}}")
        list(APPEND list_pcms ${ROOT_PATH}${module2interface_${INPUT_MOD}})
    endforeach()

    foreach(IP ${link_pcms})
        message(STATUS "Module `${module_name}` depends on module interface ${IP}")
    endforeach()

    get_filename_component(
        this_dir
        ${PREBUILT_MODULE_INTERFACE_PATH}/${MODULE_INTERFACE}.pcm
        DIRECTORY)

    file(MAKE_DIRECTORY ${this_dir})

    # ---- Add pcm target
    add_custom_command(
        OUTPUT
        ${PREBUILT_MODULE_INTERFACE_PATH}/${MODULE_INTERFACE}.pcm
        COMMAND
        ${CMAKE_CXX_COMPILER}
        ${BUILD_FLAGS}
        -fmodules-cache-path=${PREBUILT_MODULE_CACHE_PATH}
        -std=c++20
        -stdlib=libc++
        -fmodules
        -fPIC
        --precompile ${CMAKE_SOURCE_DIR}/${MODULE_INTERFACE}
        ${include_flags}
        ${link_pcms}
        -o ${PREBUILT_MODULE_INTERFACE_PATH}/${MODULE_INTERFACE}.pcm
        DEPENDS
        ${CMAKE_SOURCE_DIR}/${MODULE_INTERFACE}
        ${list_pcms}
        )
    message(STATUS "Module `${module_name}` depends on module interface ${CMAKE_SOURCE_DIR}/${MODULE_INTERFACE}")

    if ("${CMAKE_EXPORT_COMPILE_COMMANDS}" STREQUAL "ON")

        file(WRITE
            ${PREBUILT_MODULE_INTERFACE_PATH}/${MODULE_INTERFACE}.cmd
            "[\n"
            "    {\n"
            "        \"arguments\": [\n"
            "            \"${CMAKE_CXX_COMPILER}\",\n"
            "            \"-std=c++20\",\n"
            "            \"-stdlib=libc++\",\n"
            "            \"-fmodules\",\n"
            "            \"-fPIC\",\n"
            "            \"--precompile\",\n"
            "            \"${CMAKE_SOURCE_DIR}/${MODULE_INTERFACE}\",\n"
            "            \"${link_pcms}\",\n"
            "            \"-o\",\n"
            "            \"${PREBUILT_MODULE_INTERFACE_PATH}/${MODULE_INTERFACE}.pcm\"\n"
            "        ],\n"
            "        \"directory\": \"${CMAKE_BINARY_DIR}\",\n"
            "        \"file\": \"${CMAKE_SOURCE_DIR}/${MODULE_INTERFACE}\",\n"
            "        \"output\": \"${PREBUILT_MODULE_INTERFACE_PATH}/${MODULE_INTERFACE}.pcm\"\n"
            "    }\n"
            "]\n")

    endif()

    set(module2interface_${module_name}
        ${MODULE_INTERFACE}.pcm
        CACHE INTERNAL
        "module2interface_${module_name}")

endfunction()

function(add_module_implementations module_name)

    # set(options OPT1 OPT2)
    # set(oneValueArgs INTERFACE)
    set(multiValueArgs SOURCES DEPENDS INCLUDES FLAGS)

    cmake_parse_arguments(MODULE "${options}" "${oneValueArgs}"
                          "${multiValueArgs}" ${ARGV})

    file(MAKE_DIRECTORY ${PREBUILT_MODULE_IMPLEMENTATION_PATH})

    set(out_objs "")
    add_implementations(out_objs
        SOURCES
        ${MODULE_SOURCES}
        DEPENDS
        "${module_name};${MODULE_DEPENDS}"
        INCLUDES
        ${MODULE_INCLUDES}
        FLAGS
        ${MODULE_FLAGS}
        )

    set_property(
        GLOBAL PROPERTY
        module2implementations_${module_name}
        "${out_objs}")

endfunction()

function(add_module module_name)

    # set(options OPTIONAL FAST)
    set(oneValueArgs INTERFACE TYPE)
    set(multiValueArgs SOURCES DEPENDS INCLUDES FLAGS)

    cmake_parse_arguments(MODULE "${options}" "${oneValueArgs}"
                          "${multiValueArgs}" ${ARGV})

    message(STATUS "Adding module `${module_name}` from interface `${MODULE_INTERFACE}` and implementations: `${MODULE_SOURCES}`")
    foreach(IN_MOD ${MODULE_DEPENDS})
        message(STATUS "Module `${module_name}` depends on module `${IN_MOD}`")
    endforeach()

    add_module_interface(${module_name}
        INTERFACE
        ${MODULE_INTERFACE}
        DEPENDS
        ${MODULE_DEPENDS}
        INCLUDES
        ${MODULE_INCLUDES}
        FLAGS
        ${MODULE_FLAGS}
        )

    if ("${MODULE_SOURCES}" STREQUAL "")
        #nothing
    else()
        add_module_implementations(${module_name}
            SOURCES
            ${MODULE_SOURCES}
            DEPENDS
            ${MODULE_DEPENDS}
            INCLUDES
            ${MODULE_INCLUDES}
            FLAGS
            ${MODULE_FLAGS}
            )
    endif()

    get_property(impls
        GLOBAL PROPERTY
        module2implementations_${module_name})

    if ("${MODULE_TYPE}" STREQUAL "PUBLIC")
        set(asAll "ALL")
    elseif ("${MODULE_TYPE}" STREQUAL "PRIVATE")
        set(asAll "")
    elseif ("${MODULE_TYPE}" STREQUAL "")
        set(asAll "")
    endif()

    add_custom_target(${module_name} ${asAll}
        DEPENDS
        ${PREBUILT_MODULE_INTERFACE_PATH}/${module2interface_${module_name}}
        ${impls}
        ${MODULE_DEPENDS}
        )

endfunction()

# ---- Register an already installed module
function(register_module module_name)

    set(multiValueArgs INTERFACE LIBRARY LIBRARY_DIR)

    cmake_parse_arguments(MODULE
        "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    if (EXISTS "${MODULE_INTERFACE}")
        # OK
    else()
        message(FATAL_ERROR "Not existing module interface ${MODULE_INTERFACE}")
    endif()

    set(module2interface_${module_name}
        ${MODULE_INTERFACE}
        CACHE INTERNAL
        "module2interface_${module_name}")

    if ("${MODULE_LIBRARY}" STREQUAL "")
        # nothing
    else()
        set(library2linkflag_${MODULE_LIBRARY}
            "-l${MODULE_LIBRARY}"
            CACHE INTERNAL
            "library2linkflag_${MODULE_LIBRARY}")
        add_custom_target(${MODULE_LIBRARY} ${asAll})
        set(LIBRARY_FULL_PATH "${MODULE_LIBRARY_DIR}/lib${MODULE_LIBRARY}.so")
    endif()

    if ("${MODULE_LIBRARY_DIR}" STREQUAL "")
        # nothing
    else()
        set(library2directory_${MODULE_LIBRARY}
            "-L${MODULE_LIBRARY_DIR}"
            CACHE INTERNAL
            "library2directory_${MODULE_LIBRARY}")
    endif()

    message(STATUS
        "Registering installed module `${module_name}`
        with interface ${MODULE_INTERFACE},
        library `${MODULE_LIBRARY}`,
        within directory: `${MODULE_LIBRARY_DIR}`")

    add_custom_target(${module_name} ${asAll}
        DEPENDS
        ${MODULE_INTERFACE}
        ${LIBRARY_FULL_PATH}
        )

endfunction()

function(add_target_from_modules target_name)

    # set(options OPTIONAL FAST)
    set(oneValueArgs TYPE)
    set(multiValueArgs SOURCES DEPENDS INCLUDES LIBRARY FLAGS)

    cmake_parse_arguments(TARGET
        "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    message(STATUS "Adding `${TARGET_TYPE}` target")

    # ---- For each input module, add objects to link
    # (precompiled interface and object module implementations)
    foreach(INPUT_MOD ${TARGET_DEPENDS})
        get_property(module_objects
            GLOBAL PROPERTY
            module2implementations_${INPUT_MOD})
        list(APPEND list_link_pcms "${module2interface_${INPUT_MOD}}")
        foreach(INPUT_OBJ ${module_objects})
            list(APPEND list_link_objects "${INPUT_OBJ}")
        endforeach()
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

    # ---- For each source, add objects to the list of linkable objects
    set(in_objs "")
    add_implementations(in_objs
        SOURCES
        ${TARGET_SOURCES}
        DEPENDS
        ${TARGET_DEPENDS}
        INCLUDES
        ${TARGET_INCLUDES}
        FLAGS
        ${TARGET_FLAGS}
        )

    foreach(in_obj ${in_objs})
        list(APPEND list_link_objects "${in_obj}")
    endforeach()

    # ---- Create list of precompiled modules
    foreach(PCM ${list_link_pcms})
        message(STATUS "Target ${target_name} associated to PCM: ${PCM}")
        list(APPEND link_pcms ${PREBUILT_MODULE_INTERFACE_PATH}/${PCM})
    endforeach()

    # ---- Create list of link objects
    foreach(LO ${list_link_objects})
        # list(APPEND true_link_objects ${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${LO})
        list(APPEND true_link_objects ${LO})
    endforeach()

    # ---- Previous list of objects belongs to library. Store them to prevent double link
    if ("${TARGET_TYPE}" STREQUAL "library")
        set_property(
            GLOBAL PROPERTY
            library2implementations_${target_name}
            "${list_link_objects}")

        set(library2directory_${target_name}
            "-L${PREBUILT_MODULE_LIBRARY_PATH}"
            CACHE INTERNAL
            "library2directory_${MODULE_LIBRARY}")
    endif()

    # ---- Create list of link libraries
    foreach(TLIB ${TARGET_LIBRARY})
        list(APPEND link_libraries ${library2linkflag_${TLIB}})
        # ---- remove from true_link_objects those objects in this library
        get_property(lib_impls
            GLOBAL PROPERTY
            library2implementations_${TLIB})

        list(APPEND link_dirs ${library2directory_${TARGET_LIBRARY}})

        foreach(LO ${lib_impls})
            list(REMOVE_ITEM true_link_objects ${PREBUILT_MODULE_IMPLEMENTATION_PATH}/${LO})
        endforeach()
    endforeach()

    # ---- Log messages for feedback
    foreach(LP ${link_pcms})
        message(STATUS "`${target_name} ${TARGET_TYPE}` target depends on module interface ${LP}")
    endforeach()

    foreach(LO ${true_link_objects})
        message(STATUS "`${target_name} ${TARGET_TYPE}` target depends on object ${LO}")
    endforeach()

    foreach(LL ${link_libraries})
        message(STATUS "`${target_name} ${TARGET_TYPE}` target depends on library ${LL}")
    endforeach()

    # ---- Add custom target
    add_custom_command(
        OUTPUT
        ${target_binary}
        COMMAND
        ${CMAKE_CXX_COMPILER}
        ${BUILD_FLAGS}
        ${type_flag}
        -stdlib=libc++
        ${link_dirs}
        ${link_pcms}
        ${true_link_objects}
        ${link_libraries}
        -o ${target_binary}
        DEPENDS
        ${link_pcms}
        ${true_link_objects}
        )

    add_custom_target(
        ${target_name} ALL
        DEPENDS
        ${TARGET_DEPENDS}
        ${TARGET_LIBRARY}
        ${target_binary}
        )

    set(target2binary_${target_name}
        ${target_binary}
        CACHE INTERNAL
        "target2binary_${target_name}")

endfunction()
