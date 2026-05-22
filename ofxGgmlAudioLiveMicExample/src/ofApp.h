#pragma once

#include "ofMain.h"
#include "ofxGgmlAudio.h"
#include "ofxImGui.h"

#include <mutex>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void update() override;
	void draw() override;
	void exit() override;
	void audioIn(ofSoundBuffer & input) override;

private:
	void setupChunker();
	void appendLogLine(const std::string & line);

	ofxImGui::Gui gui;
	ofSoundStream stream;
	ofxGgmlAudioStreamChunker chunker;
	ofxGgmlAudioStreamChunkerSettings chunkSettings;
	ofxGgmlAudioFeatureFrame latestFeatures;
	ofxGgmlAudioVadResult latestVad;

	std::mutex audioMutex;
	std::vector<float> pendingSamples;
	std::vector<std::string> logLines;
	int sampleRate = 16000;
	int channelCount = 1;
	int bufferSize = 512;
	int chunkCount = 0;
	int bufferedFrames = 0;
	float inputRms = 0.0f;
	float inputPeak = 0.0f;
	bool streamReady = false;
	bool streamFailed = false;
	std::string status;
};
