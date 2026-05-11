#pragma once

#include "ofxGgmlAudioTypes.h"

#include <string>

namespace ofxGgmlAudioUtils {
	bool hasInput(const ofxGgmlAudioRequest & request);
	std::string describe(const ofxGgmlAudioRequest & request);
}