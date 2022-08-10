# CMake Clang C++20 Modules

To date, CMake is not currently supporting C++20 modules for Clang compiler.
As a temporary solution targeting Clang, this project exposes a single CMake
script `ClangCpp20modules.cmake` having functions to facilitate compilation of
libraries and executables from C++20 modules and Clang.
So current project will be deprecated as soon as CMake adds full support for C++20 modules.


## Requirements

* clang >=11 with modules support with `-fmodules`
* Development clang libraries

```
sudo apt install clang libc++-dev clang-libc++-abi libc++abi-dev -y
```

## API

The API consists on just two functions: `add_module` and `add_target_from_modules`.

See `samples/` for usage examples.

### `add_module`

This function compiles sources of a module (a single interface and multiple implementations).

```cmake
add_module(
    <MODULE_NAME> # Whatever module name
    INTERFACE # single source file with interface
    <MODULE_INTERFACE_FILE>
    IMPLEMENTATIONS # source files implementing
    <MODULE_IMPLEMENTATION_FILE1>
    <MODULE_IMPLEMENTATION_FILE2>
    <...>
    MODULES # modules on which <MODULE_NAME> depends
    <INPUT_MODULE_NAME1>
    <INPUT_MODULE_NAME2>
    <...>
    INCLUDE_DIRS # directories holding header files
    <INCLUDE_DIR1>
    <INCLUDE_DIR2>
    <...>)
```

### `add_target_from_modules`

This function is used to compile an executable or a shared library.

```cmake
add_target_from_modules(
    <TARGET_NAME> # Whatever target name
    <TYPE> # Either "executable" or "library"
    IMPLEMENTATIONS # Sources directly implementing the target
    <TARGET_IMPLEMENTATION_FILE1>
    <TARGET_IMPLEMENTATION_FILE2>
    <...>
    MODULES # modules on which <TARGET_NAME> depends
    <INPUT_MODULE_NAME1>
    <INPUT_MODULE_NAME2>
    <...>
    INCLUDE_DIRS # directories holding header files
    <INCLUDE_DIR1>
    <INCLUDE_DIR2>
    <...>)
```


## Testing samples

Folder `samples/` holds a set of basic project samples for testing and demonstration purposes.
Each sample contains a set of source files representing modules interfaces, modules implementations, header files, and a source entry point.

Bash script `test.sh` and loops over all samples, for each one running following commands in sequence and expecting no errors:

* `cmake` to test correctness of CMakeLists.txt script
* `make` to assert correct compilation
* `main` to run the final sample executable from source entry point, expecting no errors.

After cloning, just run the test script:

```
source test.sh
```

You should see following output:

```
Testing [ROOT_PATH]/cmake-clang-cpp20modules/samples/1module-impl/ 	OK
Testing [ROOT_PATH]/cmake-clang-cpp20modules/samples/1module-impls/ 	OK
Testing [ROOT_PATH]/cmake-clang-cpp20modules/samples/1module-impls-header/ 	OK
Testing [ROOT_PATH]/cmake-clang-cpp20modules/samples/1module-impls-lib/ 	OK
Testing [ROOT_PATH]/cmake-clang-cpp20modules/samples/1module-noimpl/ 	OK
Testing [ROOT_PATH]/cmake-clang-cpp20modules/samples/2modules-impls/ 	OK
Testing [ROOT_PATH]/cmake-clang-cpp20modules/samples/2modules-impls-lib/ 	OK
Testing [ROOT_PATH]/cmake-clang-cpp20modules/samples/2modules-noimpl/ 	OK
```
