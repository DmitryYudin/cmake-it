#
# This bootstrap demostrates how to catch platform variables from CMake: X86, X64, ARM, ARM64
#
if (CMAKE_CONFIGURATION_TYPES) # https://stackoverflow.com/questions/31661264/cmake-generators-for-visual-studio-do-not-set-cmake-configuration-types
    set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "Debug/Release only" FORCE)
endif()

# System architecture detection
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" SYSPROC)
set(X86_ALIASES x86 i386 i686 x86_64 amd64)
set(ARM_ALIASES armeabi-v7a armv7-a aarch64 arm64-v8a)
list(FIND X86_ALIASES "${SYSPROC}" X86MATCH)
list(FIND ARM_ALIASES "${SYSPROC}" ARMMATCH)
if ("${SYSPROC}" STREQUAL "" OR X86MATCH GREATER "-1")
    set(X86 1)
    if ("${CMAKE_SIZEOF_VOID_P}" MATCHES 8)
        set(X64 1)
    else()
        set(X64 0)
    endif()
elseif (ARMMATCH GREATER "-1")
    set(ARM 1)
    if ("${CMAKE_SIZEOF_VOID_P}" MATCHES 8)
        set(ARM64 1)
    else()
        set(ARM64 0)
    endif()
else()
    message(FATAL_ERROR "CMAKE_SYSTEM_PROCESSOR value `${CMAKE_SYSTEM_PROCESSOR}` is unknown\n"
                        "Please add this value near ${CMAKE_CURRENT_LIST_FILE}:${CMAKE_CURRENT_LIST_LINE}")
endif()

# dump assembly
# add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-S>)

# https://cmake.org/cmake/help/latest/manual/cmake-variables.7.html
message(STATUS 	"LocalVars: X86=${X86} X64=${X64} ARM=${ARM} ARM64=${ARM64}")
message(STATUS 	"CMakeVars: TARGET:   ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS 	"CMakeVars: COMPILER: ${CMAKE_C_COMPILER_ID} FRONTEND_VARIANT=${CMAKE_C_COMPILER_FRONTEND_VARIANT} RUNTIME=${CMAKE_C_PLATFORM_ID}")

if ("Windows" STREQUAL CMAKE_SYSTEM_NAME)
	add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
	add_compile_definitions(_SCL_SECURE_NO_WARNINGS)
endif()
if ("MSVC" STREQUAL CMAKE_C_COMPILER_ID OR
    "MSVC" STREQUAL CMAKE_C_COMPILER_FRONTEND_VARIANT)
	add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/W3>)
	if (X64)
		add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/arch:AVX2>)
	elseif(X86)
    	add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/arch:AVX>)
	endif()
endif()
if ("GNU" STREQUAL CMAKE_C_COMPILER_ID OR
    "GNU" STREQUAL CMAKE_C_COMPILER_FRONTEND_VARIANT)
	add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-Wall>)
	if (X64)
    	add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-mavx2>)
	elseif(X86)
    	add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-mavx>)
	endif()
	add_compile_definitions(__STDC_WANT_LIB_EXT1__=1 _GNU_SOURCE)
endif()
if ("GNU" STREQUAL CMAKE_C_COMPILER_ID)           # strip RELEASE executables
	add_link_options($<$<CONFIG:RELEASE>:-s>)
endif()
if ("MinGW" STREQUAL CMAKE_C_PLATFORM_ID)         # https://sourceforge.net/p/mingw-w64/mailman/message/29128250/
	add_compile_definitions(__USE_MINGW_ANSI_STDIO)
endif()
if ("Clang"   STREQUAL CMAKE_C_COMPILER_ID AND    # Here the 'toolchain.cmake' file from the Android-NDK bundle is in use. CMake pass both
    "Android" STREQUAL CMAKE_SYSTEM_NAME)         # CFLAGS and ASMFLAGS to asm-compiler and this makes Clang complain for unknown flags.
	    set(CMAKE_ASM_FLAGS "-Wno-unused-command-line-argument ${CMAKE_ASM_FLAGS}")
endif()
if ("Intel" STREQUAL CMAKE_C_COMPILER_ID)         # ICC has different options format for Windows and Linux build.
    if("Windows" STREQUAL CMAKE_HOST_SYSTEM_NAME)
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/Qrestrict>)
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/Qdiag-disable:167>) # "TYPE (*)[N]" is incompatible with parameter of type "const TYPE (*)[N]"
    else()
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-restrict>)
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-diag-disable=167>)
    endif()
endif()
