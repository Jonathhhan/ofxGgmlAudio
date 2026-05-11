cmake_minimum_required(VERSION 3.18)
project(ofxGgmlAudio_tests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(ofxGgmlAudio_tests
	test_main.cpp
	../src/ofxGgmlAudio/ofxGgmlAudioUtils.cpp
	../src/ofxGgmlAudio/ofxGgmlAudioWhisperBackend.cpp)

target_include_directories(ofxGgmlAudio_tests PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}/../src)

enable_testing()
add_test(NAME ofxGgmlAudio_tests COMMAND ofxGgmlAudio_tests)
