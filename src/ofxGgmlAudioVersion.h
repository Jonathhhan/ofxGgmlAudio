#pragma once

#define OFXGGML_AUDIO_VERSION_MAJOR 1
#define OFXGGML_AUDIO_VERSION_MINOR 0
#define OFXGGML_AUDIO_VERSION_PATCH 1
#define OFXGGML_AUDIO_VERSION_STRING "1.0.1"

inline const char * ofxGgmlAudioGetVersionString() {
	return OFXGGML_AUDIO_VERSION_STRING;
}
