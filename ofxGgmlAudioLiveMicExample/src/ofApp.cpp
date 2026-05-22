#include "ofApp.h"

#include "imgui.h"

#include <algorithm>
#include <cmath>

namespace {
	constexpr const char * LogModule = "ofxGgmlAudioLiveMicExample";

	float computeRms(const std::vector<float> & samples) {
		if (samples.empty()) {
			return 0.0f;
		}
		double sum = 0.0;
		for (const float sample : samples) {
			sum += static_cast<double>(sample) * static_cast<double>(sample);
		}
		return static_cast<float>(std::sqrt(sum / static_cast<double>(samples.size())));
	}

	float computePeak(const std::vector<float> & samples) {
		float peak = 0.0f;
		for (const float sample : samples) {
			peak = std::max(peak, std::abs(sample));
		}
		return peak;
	}
}

void ofApp::setup() {
	ofSetWindowTitle("ofxGgmlAudio live mic example");
	gui.setup();

	chunkSettings.format.sampleRate = sampleRate;
	chunkSettings.format.channels = channelCount;
	chunkSettings.windowSeconds = 1.5;
	chunkSettings.hopSeconds = 0.5;
	chunkSettings.maxBufferedSeconds = 8.0;
	setupChunker();

	ofSoundStreamSettings settings;
	settings.setInListener(this);
	settings.sampleRate = sampleRate;
	settings.numInputChannels = channelCount;
	settings.numOutputChannels = 0;
	settings.bufferSize = bufferSize;

	try {
		stream.setup(settings);
		streamReady = true;
		status = "capturing microphone input";
		ofLogNotice(LogModule) << status;
	} catch (const std::exception & error) {
		streamFailed = true;
		status = std::string("audio input setup failed: ") + error.what();
		ofLogWarning(LogModule) << status;
	} catch (...) {
		streamFailed = true;
		status = "audio input setup failed";
		ofLogWarning(LogModule) << status;
	}
}

void ofApp::setupChunker() {
	if (!chunker.setup(chunkSettings)) {
		status = "stream chunker setup failed";
		ofLogWarning(LogModule) << status;
		return;
	}
	status = "stream chunker ready";
}

void ofApp::update() {
	std::vector<float> samples;
	{
		std::lock_guard<std::mutex> lock(audioMutex);
		samples.swap(pendingSamples);
	}
	if (samples.empty() || !chunker.isConfigured()) {
		return;
	}

	inputRms = computeRms(samples);
	inputPeak = computePeak(samples);
	const double timestampSeconds = ofGetElapsedTimef();
	chunker.pushSamples(samples, timestampSeconds);
	bufferedFrames = chunker.getBufferedFrameCount();

	ofxGgmlAudioStreamRequest chunk;
	while (chunker.popNext(chunk, ofxGgmlAudioTask::VoiceActivityDetection)) {
		latestFeatures = ofxGgmlAudioFeatures::analyze(chunk);
		latestVad = ofxGgmlAudioFeatures::estimateVoiceActivity(latestFeatures);
		++chunkCount;
		appendLogLine(
			"chunk " + ofToString(chunkCount) +
			" rms=" + ofToString(latestFeatures.rms, 4) +
			" peak=" + ofToString(latestFeatures.peak, 4) +
			" vad=" + (latestVad.active ? "active" : "silent"));
	}
}

void ofApp::draw() {
	ofBackground(18);
	gui.begin();
	ImGui::SetNextWindowPos(ImVec2(16.0f, 16.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(ImVec2(780.0f, 460.0f), ImGuiCond_Once);
	ImGui::Begin("ofxGgmlAudio Live Mic");
	ImGui::TextWrapped("%s", status.c_str());
	ImGui::SeparatorText("Input");
	ImGui::Text("stream: %s", streamReady ? "ready" : (streamFailed ? "failed" : "starting"));
	ImGui::Text("format: %d Hz, %d channel(s), buffer %d", sampleRate, channelCount, bufferSize);
	ImGui::ProgressBar(std::min(1.0f, inputRms * 10.0f), ImVec2(-1.0f, 0.0f), "input rms");
	ImGui::ProgressBar(std::min(1.0f, inputPeak), ImVec2(-1.0f, 0.0f), "input peak");

	ImGui::SeparatorText("Chunker");
	ImGui::Text("window: %.1fs, hop: %.1fs", chunkSettings.windowSeconds, chunkSettings.hopSeconds);
	ImGui::Text("buffered frames: %d", bufferedFrames);
	ImGui::Text("chunks emitted: %d", chunkCount);

	ImGui::SeparatorText("Latest Features");
	ImGui::Text("rms %.4f | peak %.4f | zcr %.4f | mean %.4f",
		latestFeatures.rms,
		latestFeatures.peak,
		latestFeatures.zeroCrossingRate,
		latestFeatures.mean);
	ImGui::Text("voice activity: %s (score %.3f)",
		latestVad.active ? "active" : "silent",
		latestVad.score);

	ImGui::SeparatorText("Recent Chunks");
	ImGui::BeginChild("live-log", ImVec2(0, 150), true, ImGuiWindowFlags_HorizontalScrollbar);
	for (const auto & line : logLines) {
		ImGui::TextUnformatted(line.c_str());
	}
	ImGui::EndChild();
	ImGui::End();
	gui.end();
}

void ofApp::exit() {
	stream.close();
}

void ofApp::audioIn(ofSoundBuffer & input) {
	std::vector<float> samples;
	samples.reserve(input.getNumFrames());
	for (std::size_t frame = 0; frame < input.getNumFrames(); ++frame) {
		float mixed = 0.0f;
		for (std::size_t channel = 0; channel < input.getNumChannels(); ++channel) {
			mixed += input.getSample(frame, channel);
		}
		const auto channels = std::max<std::size_t>(1, input.getNumChannels());
		samples.push_back(mixed / static_cast<float>(channels));
	}

	std::lock_guard<std::mutex> lock(audioMutex);
	pendingSamples.insert(pendingSamples.end(), samples.begin(), samples.end());
}

void ofApp::appendLogLine(const std::string & line) {
	logLines.push_back(line);
	constexpr std::size_t MaxLines = 12;
	if (logLines.size() > MaxLines) {
		logLines.erase(logLines.begin(), logLines.begin() + (logLines.size() - MaxLines));
	}
}
