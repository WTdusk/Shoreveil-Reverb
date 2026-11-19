cmake_minimum_required(VERSION 3.22)

project(ShoreveilReverb VERSION 0.3.2 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (MSVC)
    add_compile_options(/MP)

    # Release builds link the C/C++ runtime statically so the shipped VST3
    # loads on a machine that has never had the Visual C++ redistributable
    # installed. Override on the command line if a host needs the shared CRT.
    if (NOT DEFINED CMAKE_MSVC_RUNTIME_LIBRARY)
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
endif()

option(RIVAGE_GENERATE_MAP "Emit a linker map file for the VST3 target" OFF)
option(RIVAGE_FETCH_JUCE "Download the pinned JUCE source archive" OFF)

set(SHOREVEIL_JUCE_VERSION "9.0.5")
set(SHOREVEIL_JUCE_COMMIT "d60b7a78030661574a615b586d9325ba7a7fa7dd")
set(SHOREVEIL_JUCE_SHA256 "e769e5622dbe1d42b411879c1e1f76f1f571d2a685755dd16337932652db0ec1")
set(SHOREVEIL_JUCE_ARCHIVE "" CACHE FILEPATH "Use a local copy of the pinned JUCE archive")
set(SHOREVEIL_JUCE_URL "https://codeload.github.com/juce-framework/JUCE/zip/${SHOREVEIL_JUCE_COMMIT}")
set(shoreveil_bundled_juce "${CMAKE_CURRENT_SOURCE_DIR}/JUCE-${SHOREVEIL_JUCE_VERSION}")

if (EXISTS "${shoreveil_bundled_juce}/CMakeLists.txt")
    set(shoreveil_juce_source "${shoreveil_bundled_juce}")
    add_subdirectory("${shoreveil_juce_source}" "${CMAKE_CURRENT_BINARY_DIR}/juce")
elseif (RIVAGE_FETCH_JUCE)
    include(FetchContent)
    if (POLICY CMP0135)
        cmake_policy(SET CMP0135 NEW)
    endif()
    if (SHOREVEIL_JUCE_ARCHIVE)
        set(SHOREVEIL_JUCE_URL "${SHOREVEIL_JUCE_ARCHIVE}")
    endif()
    FetchContent_Declare(JUCE
        URL "${SHOREVEIL_JUCE_URL}"
        URL_HASH "SHA256=${SHOREVEIL_JUCE_SHA256}")
    FetchContent_MakeAvailable(JUCE)
    set(shoreveil_juce_source "${juce_SOURCE_DIR}")
else()
    message(FATAL_ERROR
        "JUCE ${SHOREVEIL_JUCE_VERSION} was not found. Extract the pinned JUCE archive to "
        "JUCE-${SHOREVEIL_JUCE_VERSION}/ or configure with -DRIVAGE_FETCH_JUCE=ON.")
endif()

file(STRINGS "${shoreveil_juce_source}/CMakeLists.txt" shoreveil_juce_version_line
     REGEX "^project\\(JUCE VERSION ${SHOREVEIL_JUCE_VERSION} ")
if (NOT shoreveil_juce_version_line)
    message(FATAL_ERROR "The selected JUCE source must be version ${SHOREVEIL_JUCE_VERSION}.")
endif()
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/shoreveil-juce-source.txt" "${shoreveil_juce_source}\n")

add_subdirectory(Source)
add_subdirectory(tools/analyzer)
add_subdirectory(tools/preview)
