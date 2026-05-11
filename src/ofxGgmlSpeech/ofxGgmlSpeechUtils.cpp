#include "ofxGgmlSpeechUtils.h"

namespace ofxGgmlSpeechUtils {
	bool hasInput(const ofxGgmlSpeechRequest & request) {
		return !request.audioPath.empty();
	}

	std::string describe(const ofxGgmlSpeechRequest & request) {
		if (!hasInput(request)) {
			return "speech: empty request";
		}
		return "speech: " + request.audioPath;
	}
}