#pragma once

#include "ofMain.h"
#include "ofxGgmlAudio.h"
#include "ofxImGui.h"

#include <atomic>
#include <mutex>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void update() override;
	void draw() override;
	void keyPressed(int key) override;
	void exit() override;
	void audioIn(ofSoundBuffer & input) override;

private:
	void setupChunker();
	void resetChunker();
	void resetStats();
	void appendLogLine(const std::string & line);
	void pushHistorySample(float rms, float vadScore);

	ofxImGui::Gui gui;
	ofSoundStream stream;
	ofxGgmlAudioStreamChunker chunker;
	ofxGgmlAudioStreamChunkerSettings chunkSettings;
	ofxGgmlAudioVadSettings vadSettings;
	ofxGgmlAudioFeatureFrame latestFeatures;
	ofxGgmlAudioVadResult latestVad;

	std::mutex audioMutex;
	std::vector<float> pendingSamples;
	std::vector<std::string> logLines;
	std::vector<float> rmsHistory;
	std::vector<float> vadHistory;
	int sampleRate = 16000;
	int channelCount = 1;
	int bufferSize = 512;
	int chunkCount = 0;
	int activeChunkCount = 0;
	int bufferedFrames = 0;
	float inputRms = 0.0f;
	float inputPeak = 0.0f;
	float chunkWindowSeconds = 1.5f;
	float chunkHopSeconds = 0.5f;
	bool streamReady = false;
	bool streamFailed = false;
	std::atomic_bool captureEnabled { true };
	std::string status;
};
