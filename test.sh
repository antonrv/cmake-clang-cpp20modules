#!/bin/sh

mkdir -p build

MAIN_PWD=${PWD}


err_print() {
    # echo -e "Testing $1: $2 \tFAILED:
    echo -e "Testing $1: $2:
====Log START====

\033[1m
$2
\033[0m

====Log END===="
}

MAIN_PWD=${PWD}


for sample_dir in samples/*/ ; do

    SAMPLE_DIR_FULL=${MAIN_PWD}/$sample_dir

    SAMPLE_BUILD_DIR_FULL=${MAIN_PWD}/build/$sample_dir
    SAMPLE_BUILD_LIB_DIR_FULL=${MAIN_PWD}/build/$sample_dir/lib

    # ---- Make build dir for sample
    mkdir -p $SAMPLE_BUILD_DIR_FULL
    cd $SAMPLE_BUILD_DIR_FULL

    out_cmake=$(cmake ${SAMPLE_DIR_FULL} -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_COMPILER=clang++-15)
    if [ "$?" -ne 0 ]; then
        err_print ${sample_dir} "cmake" "$out_cmake"
        break
    else
        :
        # echo "cmake OK"
    fi

    out_jq=$(jq -n '[ inputs | add ]' ${SAMPLE_BUILD_DIR_FULL}/pcm/api/*.cmd > ${SAMPLE_BUILD_DIR_FULL}/compile_commands.json)
    if [ "$?" -ne 0 ]; then
        err_print "jq" "$out_jq"
        break
    else
        :
        # echo "jq OK"
    fi

    out_ln=$(ln -s ${SAMPLE_BUILD_DIR_FULL}/compile_commands.json ${SAMPLE_DIR_FULL}/compile_commands.json)
    if [ "$?" -ne 0 ]; then
        :
        # err_print "ln" "$out_ln"  # Dont report it, usually symlink already exists in this case
        # break
    else
        :
        # echo "make OK"
    fi

    out_make=$(bear --append --output ${SAMPLE_BUILD_DIR_FULL}/compile_commands.json -- make VERBOSE=1)
    if [ "$?" -ne 0 ]; then
        err_print "make" "$out_make"
        break
    else
        :
        # echo "make OK"
    fi

    out_main=$(LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SAMPLE_BUILD_LIB_DIR_FULL ${SAMPLE_BUILD_DIR_FULL}/bin/main)
    if [ "$?" -ne 0 ]; then
        err_print "main" "$out_main"
        break
    else
        :
        # echo "main OK"
    fi

    echo -e "Testing ${SAMPLE_DIR_FULL} \tOK"

    cd $MAIN_PWD
done

cd $MAIN_PWD
