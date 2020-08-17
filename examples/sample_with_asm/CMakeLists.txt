cmake_minimum_required(VERSION 3.16)

enable_language( C CXX ASM )

include (bootstrap.cmake)

project(sample_with_asm)

# Library
add_library(mylib STATIC)
#aux_source_directory(src mylib_SRC)
file(GLOB_RECURSE mylib_SRC "src/*.c*")

target_include_directories(mylib PRIVATE include)
target_include_directories(mylib INTERFACE include)

if (X86)
    if(X64)
        set(SUFF x64)
    else()
        set(SUFF x86)
    endif()
else()
    if (ARM64)
        set(SUFF arm64)
    else()
        set(SUFF arm32)
    endif()
endif()
file(GLOB_RECURSE asm_sources "src/*_${SUFF}.s")

if (X86)
    enable_language(ASM_NASM)
    set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -DUSER_DEFINE=1")
    foreach(X IN ITEMS ${asm_sources}) # make '.s' extension recognizable
        set_source_files_properties(${X} PROPERTIES LANGUAGE ASM_NASM)
    endforeach()
endif()

target_sources(mylib PRIVATE ${mylib_SRC} ${asm_sources})
source_group(TREE ${CMAKE_CURRENT_SOURCE_DIR} FILES ${mylib_SRC} ${asm_sources})

# Tests
add_executable(test)
aux_source_directory(test test_SRC)
target_sources(test PRIVATE ${test_SRC})
target_link_libraries(test mylib)
set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT test)
