cmake_minimum_required(VERSION 3.18)
project(ofxGgmlSpeech_tests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(ofxGgmlSpeech_tests
	test_main.cpp
	../src/ofxGgmlSpeech/ofxGgmlSpeechUtils.cpp
	../src/ofxGgmlSpeech/ofxGgmlSpeechWhisperBackend.cpp)

target_include_directories(ofxGgmlSpeech_tests PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}/../src)

enable_testing()
add_test(NAME ofxGgmlSpeech_tests COMMAND ofxGgmlSpeech_tests)
