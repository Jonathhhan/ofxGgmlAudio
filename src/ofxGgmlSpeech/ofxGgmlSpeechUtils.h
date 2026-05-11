#pragma once

#include "ofxGgmlSpeechTypes.h"

#include <string>

namespace ofxGgmlSpeechUtils {
	bool hasInput(const ofxGgmlSpeechRequest & request);
	std::string describe(const ofxGgmlSpeechRequest & request);
}