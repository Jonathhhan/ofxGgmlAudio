#include "ofxGgmlAudio.h"

#include <algorithm>
#include <cctype>
#include <iostream>
#include <string>

namespace {
	std::string toLower(std::string value) {
		std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
			return static_cast<char>(std::tolower(ch));
		});
		return value;
	}

	void printUsage() {
		std::cerr << "usage: ofxGgmlAudio_whisper_smoke <model.bin> <audio.wav> [expected text]\n";
	}
}

int main(int argc, char** argv) {
	if (argc < 3 || argc > 4) {
		printUsage();
		return 2;
	}

	const std::string modelPath = argv[1];
	const std::string audioPath = argv[2];
	const std::string expectedText = argc >= 4 ? argv[3] : "";

	ofxGgmlAudioWhisperBackend backend;
	if (!backend.isAvailable()) {
		std::cerr << "whisper.cpp backend is not available in this build\n";
		return 1;
	}

	ofxGgmlAudioWhisperSettings settings;
	settings.modelPath = modelPath;
	settings.language = "en";
	settings.timestamps = false;
	settings.threads = 0;

	const auto setupResult = backend.setup(settings);
	if (!setupResult) {
		std::cerr << "setup failed: " << setupResult.error << "\n";
		return 1;
	}

	ofxGgmlAudioRequest request;
	request.audioPath = audioPath;
	request.language = "en";

	const auto result = backend.transcribe(request);
	if (!result) {
		std::cerr << "transcription failed: " << result.error << "\n";
		return 1;
	}
	if (result.text.empty()) {
		std::cerr << "transcription succeeded but returned empty text\n";
		return 1;
	}

	std::cout << result.text << "\n";
	if (!expectedText.empty() && toLower(result.text).find(toLower(expectedText)) == std::string::npos) {
		std::cerr << "transcription did not contain expected text: " << expectedText << "\n";
		return 1;
	}

	return 0;
}
