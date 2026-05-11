#include "ofxGgmlAudio.h"

#include <iostream>

int main() {
	ofxGgmlAudioRequest request;
	if (ofxGgmlAudioUtils::hasInput(request)) {
		std::cerr << "empty request reported as configured\n";
		return 1;
	}

	request.audioPath = "voice/sample.wav";
	if (!ofxGgmlAudioUtils::hasInput(request)) {
		std::cerr << "configured request reported as empty\n";
		return 1;
	}

	const auto description = ofxGgmlAudioUtils::describe(request);
	if (description.find(request.audioPath) == std::string::npos) {
		std::cerr << "description did not include request input\n";
		return 1;
	}

	ofxGgmlAudioWhisperBackend backend;
	if (backend.getBackendName() != "whisper.cpp") {
		std::cerr << "unexpected whisper backend name\n";
		return 1;
	}
	if (backend.isLoaded()) {
		std::cerr << "whisper backend reported loaded before setup\n";
		return 1;
	}
	ofxGgmlAudioWhisperSettings settings;
	const auto setupResult = backend.setup(settings);
	if (setupResult) {
		std::cerr << "whisper backend setup succeeded without model/runtime\n";
		return 1;
	}
	const auto transcribeResult = backend.transcribe(request);
	if (transcribeResult) {
		std::cerr << "whisper backend transcribed without setup\n";
		return 1;
	}

	return 0;
}
