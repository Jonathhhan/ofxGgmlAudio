#pragma once

#include "ofMain.h"
#include "ofxGgmlAudio.h"
#include "ofxImGui.h"

#include <atomic>
#include <array>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;
	void keyPressed(int key) override;
	void exit() override;

private:
	void startTranscription();
	void runWorker();
	ofxGgmlAudioResult runFileTranscription();
	ofxGgmlAudioResult runChunkedTranscription();
	void setStatus(const std::string & nextStatus, const std::string & nextDetail);
	static std::string findFirstFile(const std::vector<std::string> & directories, const std::vector<std::string> & extensions);
	static void copyToBuffer(std::array<char, 1024> & buffer, const std::string & value);
	static void copyToBuffer(std::array<char, 64> & buffer, const std::string & value);

	ofxImGui::Gui gui;
	ofxGgmlAudioWhisperBackend backend;
	ofxGgmlAudioWhisperSettings settings;
	ofxGgmlAudioRequest request;
	ofxGgmlAudioResult result;
	std::array<char, 1024> modelPathBuffer {};
	std::array<char, 1024> audioPathBuffer {};
	std::array<char, 64> languageBuffer {};
	std::thread worker;
	std::mutex stateMutex;
	std::string status;
	std::string detail;
	std::string output;
	std::string rollingSummary;
	int threads = 0;
	float chunkWindowSeconds = 6.0f;
	float chunkHopSeconds = 4.0f;
	bool translate = false;
	bool timestamps = true;
	bool chunkedMode = false;
	std::atomic_bool running { false };
	std::atomic_bool cancelRequested { false };
};
