#pragma once

#include "ofxGgmlSpeechTypes.h"

#include <memory>
#include <string>

struct ofxGgmlSpeechWhisperSettings {
	std::string modelPath;
	int threads = 0;
	bool translate = false;
	bool timestamps = true;

	bool hasModelPath() const {
		return !modelPath.empty();
	}
};

class ofxGgmlSpeechWhisperBackend {
public:
	ofxGgmlSpeechWhisperBackend();
	~ofxGgmlSpeechWhisperBackend();

	ofxGgmlSpeechWhisperBackend(ofxGgmlSpeechWhisperBackend&& other) noexcept;
	ofxGgmlSpeechWhisperBackend& operator=(ofxGgmlSpeechWhisperBackend&& other) noexcept;

	ofxGgmlSpeechWhisperBackend(const ofxGgmlSpeechWhisperBackend&) = delete;
	ofxGgmlSpeechWhisperBackend& operator=(const ofxGgmlSpeechWhisperBackend&) = delete;

	bool isAvailable() const;
	bool isLoaded() const;
	std::string getBackendName() const;
	ofxGgmlSpeechWhisperSettings getSettings() const;

	ofxGgmlSpeechResult setup(const ofxGgmlSpeechWhisperSettings& settings);
	ofxGgmlSpeechResult transcribe(const ofxGgmlSpeechRequest& request);
	void close();

private:
	struct Impl;
	std::unique_ptr<Impl> impl;
};
