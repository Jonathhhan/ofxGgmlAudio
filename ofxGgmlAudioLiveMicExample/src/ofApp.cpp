#include "ofApp.h"

#include "imgui.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <fstream>

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

	bool startupProbeEnabled() {
		const auto value = std::getenv("OFXGGML_AUDIO_STARTUP_PROBE");
		return value != nullptr && std::string(value) != "0" && std::string(value) != "false";
	}

	std::string startupProbePath() {
		const auto explicitPath = std::getenv("OFXGGML_AUDIO_STARTUP_PROBE_PATH");
		if (explicitPath != nullptr && std::string(explicitPath).size() > 0) {
			return explicitPath;
		}

		const auto temp = std::getenv("TEMP");
		if (temp != nullptr && std::string(temp).size() > 0) {
			return std::string(temp) + "\\ofxGgmlAudioLiveMic-startup.txt";
		}
		return "ofxGgmlAudioLiveMic-startup.txt";
	}

	void writeStartupProbe(const std::string & message) {
		if (!startupProbeEnabled()) {
			return;
		}
		std::ofstream out(startupProbePath(), std::ios::app);
		out << message << std::endl;
	}
}

void ofApp::setup() {
	writeStartupProbe("setup: enter");
	ofSetWindowTitle("ofxGgmlAudio live mic example");
	writeStartupProbe("setup: before gui.setup");
	gui.setup();
	writeStartupProbe("setup: after gui.setup");

	chunkSettings.format.sampleRate = sampleRate;
	chunkSettings.format.channels = channelCount;
	chunkSettings.maxBufferedSeconds = 8.0;
	writeStartupProbe("setup: before setupChunker");
	setupChunker();
	writeStartupProbe("setup: after setupChunker");

	ofSoundStreamSettings settings;
	settings.setInListener(this);
	settings.sampleRate = sampleRate;
	settings.numInputChannels = channelCount;
	settings.numOutputChannels = 0;
	settings.bufferSize = bufferSize;

	try {
		writeStartupProbe("setup: before stream.setup");
		stream.setup(settings);
		writeStartupProbe("setup: after stream.setup");
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
	chunkSettings.windowSeconds = chunkWindowSeconds;
	chunkSettings.hopSeconds = std::min(chunkHopSeconds, chunkWindowSeconds);

	if (!chunker.setup(chunkSettings)) {
		status = "stream chunker setup failed";
		ofLogWarning(LogModule) << status;
		return;
	}
	status = "stream chunker ready";
}

void ofApp::resetChunker() {
	{
		std::lock_guard<std::mutex> lock(audioMutex);
		pendingSamples.clear();
	}
	chunkCount = 0;
	activeChunkCount = 0;
	bufferedFrames = 0;
	latestFeatures = ofxGgmlAudioFeatureFrame {};
	latestVad = ofxGgmlAudioVadResult {};
	setupChunker();
	appendLogLine("chunker reset");
}

void ofApp::resetStats() {
	chunkCount = 0;
	activeChunkCount = 0;
	bufferedFrames = 0;
	inputRms = 0.0f;
	inputPeak = 0.0f;
	latestFeatures = ofxGgmlAudioFeatureFrame {};
	latestVad = ofxGgmlAudioVadResult {};
	logLines.clear();
	rmsHistory.clear();
	vadHistory.clear();
	appendLogLine("stats cleared");
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
		latestVad = ofxGgmlAudioFeatures::estimateVoiceActivity(latestFeatures, vadSettings);
		++chunkCount;
		if (latestVad.active) {
			++activeChunkCount;
		}
		pushHistorySample(latestFeatures.rms, latestVad.score);
		appendLogLine(
			"chunk " + ofToString(chunkCount) +
			" t=" + ofToString(chunk.timestampSeconds, 2) + "s" +
			" rms=" + ofToString(latestFeatures.rms, 4) +
			" peak=" + ofToString(latestFeatures.peak, 4) +
			" vad=" + (latestVad.active ? "active" : "silent") +
			" score=" + ofToString(latestVad.score, 3));
	}
}

void ofApp::draw() {
	ofBackground(18);
	gui.begin();
	ImGui::SetNextWindowPos(ImVec2(16.0f, 16.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(ImVec2(820.0f, 620.0f), ImGuiCond_Once);
	ImGui::Begin("ofxGgmlAudio Live Mic");
	ImGui::TextWrapped("%s", status.c_str());
	if (ImGui::Button(captureEnabled.load() ? "Pause Capture" : "Resume Capture")) {
		const bool enabled = !captureEnabled.load();
		captureEnabled.store(enabled);
		status = enabled ? "capturing microphone input" : "capture paused";
		appendLogLine(status);
	}
	ImGui::SameLine();
	if (ImGui::Button("Reset")) {
		resetChunker();
		resetStats();
	}

	ImGui::SeparatorText("Input");
	ImGui::Text("stream: %s | capture: %s",
		streamReady ? "ready" : (streamFailed ? "failed" : "starting"),
		captureEnabled.load() ? "on" : "paused");
	ImGui::Text("format: %d Hz, %d channel(s), buffer %d", sampleRate, channelCount, bufferSize);
	ImGui::ProgressBar(std::min(1.0f, inputRms * 10.0f), ImVec2(-1.0f, 0.0f), "input rms");
	ImGui::ProgressBar(std::min(1.0f, inputPeak), ImVec2(-1.0f, 0.0f), "input peak");
	if (!rmsHistory.empty()) {
		ImGui::PlotLines("RMS history", rmsHistory.data(), static_cast<int>(rmsHistory.size()), 0, nullptr, 0.0f, 0.20f, ImVec2(0, 72));
		ImGui::PlotLines("VAD score", vadHistory.data(), static_cast<int>(vadHistory.size()), 0, nullptr, 0.0f, 1.0f, ImVec2(0, 72));
	}

	ImGui::SeparatorText("Chunker");
	bool chunkSettingsChanged = false;
	chunkSettingsChanged |= ImGui::SliderFloat("Window seconds", &chunkWindowSeconds, 0.5f, 5.0f, "%.1f");
	chunkSettingsChanged |= ImGui::SliderFloat("Hop seconds", &chunkHopSeconds, 0.1f, 2.0f, "%.1f");
	if (chunkHopSeconds > chunkWindowSeconds) {
		chunkHopSeconds = chunkWindowSeconds;
	}
	if (chunkSettingsChanged) {
		resetChunker();
	}
	ImGui::Text("window: %.1fs, hop: %.1fs", chunkSettings.windowSeconds, chunkSettings.hopSeconds);
	ImGui::Text("buffered frames: %d", bufferedFrames);
	ImGui::Text("chunks emitted: %d | active chunks: %d", chunkCount, activeChunkCount);

	ImGui::SeparatorText("Latest Features");
	ImGui::Text("rms %.4f | peak %.4f | zcr %.4f | mean %.4f",
		latestFeatures.rms,
		latestFeatures.peak,
		latestFeatures.zeroCrossingRate,
		latestFeatures.mean);

	ImGui::SeparatorText("Voice Activity");
	ImGui::SliderFloat("RMS threshold", &vadSettings.rmsThreshold, 0.001f, 0.100f, "%.3f");
	ImGui::SliderFloat("Peak threshold", &vadSettings.peakThreshold, 0.001f, 0.200f, "%.3f");
	ImGui::SliderFloat("Min zero crossing", &vadSettings.minZeroCrossingRate, 0.000f, 0.100f, "%.3f");
	ImGui::SliderFloat("Max zero crossing", &vadSettings.maxZeroCrossingRate, 0.100f, 0.900f, "%.3f");
	if (vadSettings.maxZeroCrossingRate < vadSettings.minZeroCrossingRate) {
		vadSettings.maxZeroCrossingRate = vadSettings.minZeroCrossingRate;
	}
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

void ofApp::keyPressed(int key) {
	if (key == ' ') {
		const bool enabled = !captureEnabled.load();
		captureEnabled.store(enabled);
		status = enabled ? "capturing microphone input" : "capture paused";
		appendLogLine(status);
	}
	if (key == 'c' || key == 'C') {
		resetChunker();
		resetStats();
	}
}

void ofApp::exit() {
	stream.close();
}

void ofApp::audioIn(ofSoundBuffer & input) {
	if (!captureEnabled.load()) {
		return;
	}

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
	constexpr std::size_t MaxLines = 24;
	if (logLines.size() > MaxLines) {
		logLines.erase(logLines.begin(), logLines.begin() + (logLines.size() - MaxLines));
	}
}

void ofApp::pushHistorySample(float rms, float vadScore) {
	constexpr std::size_t MaxHistory = 180;
	rmsHistory.push_back(rms);
	vadHistory.push_back(vadScore);
	if (rmsHistory.size() > MaxHistory) {
		rmsHistory.erase(rmsHistory.begin(), rmsHistory.begin() + (rmsHistory.size() - MaxHistory));
	}
	if (vadHistory.size() > MaxHistory) {
		vadHistory.erase(vadHistory.begin(), vadHistory.begin() + (vadHistory.size() - MaxHistory));
	}
}
