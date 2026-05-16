#pragma once

#include "ofxGgmlAudioTypes.h"

#include <memory>
#include <string>

struct ofxGgmlAudioWhisperSettings {
	std::string modelPath;
	int threads = 0;
	bool translate = false;
	bool timestamps = true;
	std::string language;

	bool hasModelPath() const {
		return modelPath.find_first_not_of(" \t\r\n") != std::string::npos;
	}
};

struct ofxGgmlAudioWhisperRuntimeInfo {
	bool compiled = false;
	bool loaded = false;
	bool gpuRequested = false;
	bool gpuAvailable = false;
	std::string acceleration = "unavailable";
	std::string systemInfo;
	int configuredThreads = 0;
	int effectiveThreads = 0;
	std::string modelPath;
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
	ofxGgmlAudioWhisperRuntimeInfo getRuntimeInfo() const;

	ofxGgmlAudioResult setup(const ofxGgmlAudioWhisperSettings& settings);
	ofxGgmlAudioResult transcribe(const ofxGgmlAudioRequest& request);
	ofxGgmlAudioResult transcribe(const ofxGgmlAudioStreamRequest& request);
	void close();

private:
	struct Impl;
	std::unique_ptr<Impl> impl;
};
