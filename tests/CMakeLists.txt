cmake_minimum_required(VERSION 3.18)
project(ofxGgmlAudio_tests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(ofxGgmlAudio_tests
	test_main.cpp
	../src/ofxGgmlAudio/ofxGgmlAudioFeatures.cpp
	../src/ofxGgmlAudio/ofxGgmlAudioRollingTranscript.cpp
	../src/ofxGgmlAudio/ofxGgmlAudioStreamChunker.cpp
	../src/ofxGgmlAudio/ofxGgmlAudioUtils.cpp
	../src/ofxGgmlAudio/ofxGgmlAudioWhisperBackend.cpp)

target_include_directories(ofxGgmlAudio_tests PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}/../src)

option(OFXGGMLAUDIO_BUILD_WHISPER_SMOKE "Build the optional whisper.cpp transcription smoke test." OFF)
option(OFXGGMLAUDIO_BUILD_CHUNKED_WHISPER_SMOKE "Build the optional chunked whisper.cpp transcription smoke test." OFF)
set(OFXGGMLAUDIO_WHISPER_INCLUDE_DIR "" CACHE PATH "Path to generated whisper.cpp headers.")
set(OFXGGMLAUDIO_WHISPER_LIBRARY "" CACHE FILEPATH "Path to generated whisper.cpp library.")
set(OFXGGMLAUDIO_GGML_INCLUDE_DIR "" CACHE PATH "Path to generated ggml headers from ofxGgmlCore.")

if (OFXGGMLAUDIO_BUILD_WHISPER_SMOKE OR OFXGGMLAUDIO_BUILD_CHUNKED_WHISPER_SMOKE)
	if (NOT OFXGGMLAUDIO_WHISPER_INCLUDE_DIR)
		message(FATAL_ERROR "OFXGGMLAUDIO_WHISPER_INCLUDE_DIR is required for the Whisper smoke test.")
	endif()
	if (NOT OFXGGMLAUDIO_WHISPER_LIBRARY)
		message(FATAL_ERROR "OFXGGMLAUDIO_WHISPER_LIBRARY is required for the Whisper smoke test.")
	endif()
	if (NOT OFXGGMLAUDIO_GGML_INCLUDE_DIR)
		message(FATAL_ERROR "OFXGGMLAUDIO_GGML_INCLUDE_DIR is required for the Whisper smoke test.")
	endif()
endif()

if (OFXGGMLAUDIO_BUILD_WHISPER_SMOKE)
	add_executable(ofxGgmlAudio_whisper_smoke
		test_whisper_smoke.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioFeatures.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioRollingTranscript.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioStreamChunker.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioUtils.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioWhisperBackend.cpp)

	target_include_directories(ofxGgmlAudio_whisper_smoke PRIVATE
		${CMAKE_CURRENT_SOURCE_DIR}/../src
		${OFXGGMLAUDIO_WHISPER_INCLUDE_DIR}
		${OFXGGMLAUDIO_GGML_INCLUDE_DIR})
	target_compile_definitions(ofxGgmlAudio_whisper_smoke PRIVATE OFXGGMLAUDIO_WITH_WHISPER)
	target_link_libraries(ofxGgmlAudio_whisper_smoke PRIVATE ${OFXGGMLAUDIO_WHISPER_LIBRARY})
	add_test(NAME ofxGgmlAudio_whisper_smoke COMMAND ofxGgmlAudio_whisper_smoke)
endif()

if (OFXGGMLAUDIO_BUILD_CHUNKED_WHISPER_SMOKE)
	add_executable(audio_chunked_smoke
		test_whisper_chunked_smoke.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioFeatures.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioRollingTranscript.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioStreamChunker.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioUtils.cpp
		../src/ofxGgmlAudio/ofxGgmlAudioWhisperBackend.cpp)

	target_include_directories(audio_chunked_smoke PRIVATE
		${CMAKE_CURRENT_SOURCE_DIR}/../src
		${OFXGGMLAUDIO_WHISPER_INCLUDE_DIR}
		${OFXGGMLAUDIO_GGML_INCLUDE_DIR})
	target_compile_definitions(audio_chunked_smoke PRIVATE OFXGGMLAUDIO_WITH_WHISPER)
	target_link_libraries(audio_chunked_smoke PRIVATE ${OFXGGMLAUDIO_WHISPER_LIBRARY})
	add_test(NAME audio_chunked_smoke COMMAND audio_chunked_smoke)
endif()

enable_testing()
add_test(NAME ofxGgmlAudio_tests COMMAND ofxGgmlAudio_tests)
