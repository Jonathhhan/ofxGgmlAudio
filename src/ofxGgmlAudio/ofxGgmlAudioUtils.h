#pragma once

#include "ofxGgmlAudioTypes.h"

#include <string>

namespace ofxGgmlAudioUtils {
	bool hasInput(const ofxGgmlAudioRequest & request);
	bool hasSamples(const ofxGgmlAudioStreamRequest & request);
	int getFrameCount(const ofxGgmlAudioStreamRequest & request);
	double getDurationSeconds(const ofxGgmlAudioStreamRequest & request);
	std::string getTaskName(ofxGgmlAudioTask task);
	std::string describe(const ofxGgmlAudioRequest & request);
	std::string describe(const ofxGgmlAudioStreamRequest & request);
}
