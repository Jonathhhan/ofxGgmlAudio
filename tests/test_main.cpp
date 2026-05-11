#include "ofxGgmlSpeech.h"

#include <iostream>

int main() {
	ofxGgmlSpeechRequest request;
	if (ofxGgmlSpeechUtils::hasInput(request)) {
		std::cerr << "empty request reported as configured\n";
		return 1;
	}

	request.audioPath = "voice/sample.wav";
	if (!ofxGgmlSpeechUtils::hasInput(request)) {
		std::cerr << "configured request reported as empty\n";
		return 1;
	}

	const auto description = ofxGgmlSpeechUtils::describe(request);
	if (description.find(request.audioPath) == std::string::npos) {
		std::cerr << "description did not include request input\n";
		return 1;
	}

	return 0;
}