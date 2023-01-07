# CMake Clang C++20 Modules

To date (august/2022), CMake is not currently supporting C++20 modules for Clang compiler.
As a temporary solution targeting Clang, this project exposes a single CMake
script `ClangCpp20modules.cmake` having functions to facilitate compilation of
libraries and executables from C++20 modules and Clang.
So current project will be deprecated as soon as CMake adds full support for C++20 modules.


## Requirements

### Mandatory
* cmake
* clang with C++20 modules support
* Development clang libraries

### Optional
* bear, to generate compilation commands database
* jq to concatenate compilation commands from precompiled modules

```
sudo apt install clang libc++-dev clang-libc++-abi libc++abi-dev -y
```

Tested on:

* ubuntu 22.04
* cmake 3.22.1
* clang 14 and 15
* bear 3.0.18
* jq 1.6

## API

The API consists on just two functions: `add_module` and `add_target_from_modules`.
See `CMakeLists.txt` scripts in each folder in `samples/` for usage examples.

Enabling `CMAKE_EXPORT_COMPILE_COMMANDS` will output a `compile_commands.json` with
compilation commands **for precompiled modules** only, as it is pending to be
also implemented for intermediate objects, library objects and executable targets.

### `add_module`

This function compiles sources of a module (a single interface and multiple implementations).

```cmake
add_module(
    <MODULE_NAME> # Whatever module name
    INTERFACE # single module interface source file
    <MODULE_INTERFACE_FILE>
    SOURCES # several module implementation source files
    <MODULE_IMPLEMENTATION_FILE1>
    <MODULE_IMPLEMENTATION_FILE2>
    <...>
    DEPENDS # names of modules on which <MODULE_NAME> depends
    <INPUT_MODULE_NAME1>
    <INPUT_MODULE_NAME2>
    <...>
    INCLUDES # directories holding header files needed by the module sources
    <INCLUDE_DIR1>
    <INCLUDE_DIR2>
    <...>
    FLAGS # Compilation flags for this module
    <FLAG1>
    <FLAG2>
    <...>
    )
```

### `add_target_from_modules`

This function is used to compile an executable or a shared library.

```cmake
add_target_from_modules(
    <TARGET_NAME> # Whatever target name
    TYPE
    <TARGET_TYPE> # Either "executable" or "library"
    SOURCES # Sources directly implementing the target
    <TARGET_IMPLEMENTATION_FILE1>
    <TARGET_IMPLEMENTATION_FILE2>
    <...>
    DEPENDS # names of modules on which <TARGET_NAME> depends
    <INPUT_MODULE_NAME1>
    <INPUT_MODULE_NAME2>
    <...>
    INCLUDES # directories holding header files
    <INCLUDE_DIR1>
    <INCLUDE_DIR2>
    <...>
    LIBRARY # Names of libraries to be linked
    <LIBRARY_NAME1>
    <LIBRARY_NAME2>
    <...>
    LIBRARY_DIR # Library directories of previous libraries
    <LIBRARY_DIR1>
    <LIBRARY_DIR2>
    <...>
    FLAGS # Compilation flags for this target
    <FLAG1>
    <FLAG2>
    <...>
    )
```

### `register_modules`

This function is used to register an existing externally compiled module in the form of a
precompiled module interface and (optionally) a shared library located in `LIBRARY_DIR`.

```cmake
register_module(
    <MODULE_NAME>
    INTERFACE
    <INTERFACE_FILE> # Precompiled interface file
    LIBRARY_DIR
    <LIBRARY_DIRECTORY> # Directory containing the library
    LIBRARY
    <LIBRARY_NAME> # Assumed existence of file <LIBRARY_DIRECTORY>/lib<LIBRARY_NAME>.so
    )
```

## Testing samples

Folder `samples/` holds a set of basic project samples for testing and demonstration purposes.
Each sample contains a set of source files representing modules interfaces, modules implementations, header files, and a source entry point.

Bash script `test.sh` and loops over all samples, for each one running following commands in sequence and expecting no errors:

* `cmake` to test correctness of CMakeLists.txt script
* `make` to assert correct compilation
* `main` to run the final sample executable from source entry point, expecting no errors.

Note that `bear` and `jq` programs are used to output compile commands, so that we can benefit from LSP clangd while developing.
Omit those commands from the test script (ie, just call `make` instead of `bear --append -- make`, and remove `jq` command).

After cloning and `cd` into repo, just run the test script:

```
source test.sh
```

You should see following output:

```
Testing [PATH]/cmake-clang-cpp20modules/samples/1module-impl/ 	OK
Testing [PATH]/cmake-clang-cpp20modules/samples/1module-impls/ 	OK
Testing [PATH]/cmake-clang-cpp20modules/samples/1module-impls-header/ 	OK
Testing [PATH]/cmake-clang-cpp20modules/samples/1module-impls-lib/ 	OK
Testing [PATH]/cmake-clang-cpp20modules/samples/1module-noimpl/ 	OK
Testing [PATH]/cmake-clang-cpp20modules/samples/2modules-impls/ 	OK
Testing [PATH]/cmake-clang-cpp20modules/samples/2modules-impls-lib/ 	OK
Testing [PATH]/cmake-clang-cpp20modules/samples/2modules-noimpl/ 	OK
```

## CMake-like install

Any built library or executable can be installed with a command like

```cmake
install(
    FILES
    ${PREBUILT_MODULE_LIBRARY_PATH}/lib<LibraryName>.so
    DESTINATION lib
    )
```

```cmake
install(
    FILES
    ${PREBUILT_MODULE_EXECUTABLE_PATH}/ExecutableName
    DESTINATION bin
    )
```

Library interfaces can be installed into a custom `api/` directory within the install directory by:

```cmake
install(
    FILES
    ${PREBUILT_MODULE_INTERFACE_PATH}/<SOURCE_PATH>/LibraryInterface.cppm.pcm
    DESTINATION api)
```
