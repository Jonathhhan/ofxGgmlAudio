#pragma once

#include "ofxGgmlAudioTypes.h"

#include <memory>
#include <string>

struct ofxGgmlAudioWhisperSettings {
	std::string modelPath;
	int threads = 0;
	bool translate = false;
	bool timestamps = true;

	bool hasModelPath() const {
		return !modelPath.empty();
	}
};

class ofxGgmlAudioWhisperBackend {
public:
	ofxGgmlAudioWhisperBackend();
	~ofxGgmlAudioWhisperBackend();

	ofxGgmlAudioWhisperBackend(ofxGgmlAudioWhisperBackend&& other) noexcept;
	ofxGgmlAudioWhisperBackend& operator=(ofxGgmlAudioWhisperBackend&& other) noexcept;

	ofxGgmlAudioWhisperBackend(const ofxGgmlAudioWhisperBackend&) = delete;
	ofxGgmlAudioWhisperBackend& operator=(const ofxGgmlAudioWhisperBackend&) = delete;

	bool isAvailable() const;
	bool isLoaded() const;
	std::string getBackendName() const;
	ofxGgmlAudioWhisperSettings getSettings() const;

	ofxGgmlAudioResult setup(const ofxGgmlAudioWhisperSettings& settings);
	ofxGgmlAudioResult transcribe(const ofxGgmlAudioRequest& request);
	void close();

private:
	struct Impl;
	std::unique_ptr<Impl> impl;
};
