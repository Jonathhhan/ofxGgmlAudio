#include "ofxGgmlAudioUtils.h"

namespace ofxGgmlAudioUtils {
	bool hasInput(const ofxGgmlAudioRequest & request) {
		return !request.audioPath.empty();
	}

	std::string describe(const ofxGgmlAudioRequest & request) {
		if (!hasInput(request)) {
			return "audio: empty request";
		}
		return "audio: " + request.audioPath;
	}
}
