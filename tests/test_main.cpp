#include "ofxGgmlAudio.h"

#include <cmath>
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

	ofxGgmlAudioStreamRequest streamRequest;
	if (ofxGgmlAudioUtils::hasSamples(streamRequest)) {
		std::cerr << "empty stream request reported as configured\n";
		return 1;
	}

	streamRequest.task = ofxGgmlAudioTask::Denoising;
	streamRequest.format.sampleRate = 48000;
	streamRequest.format.channels = 2;
	streamRequest.samples = { 0.0f, 0.1f, 0.2f, 0.3f, 0.4f, 0.5f };
	if (!ofxGgmlAudioUtils::hasSamples(streamRequest)) {
		std::cerr << "configured stream request reported as empty\n";
		return 1;
	}
	if (ofxGgmlAudioUtils::getFrameCount(streamRequest) != 3) {
		std::cerr << "unexpected stream frame count\n";
		return 1;
	}
	const auto durationSeconds = ofxGgmlAudioUtils::getDurationSeconds(streamRequest);
	if (durationSeconds <= 0.0 || durationSeconds > 0.001) {
		std::cerr << "unexpected stream duration\n";
		return 1;
	}
	if (ofxGgmlAudioUtils::getTaskName(streamRequest.task) != "denoising") {
		std::cerr << "unexpected stream task name\n";
		return 1;
	}
	const auto streamDescription = ofxGgmlAudioUtils::describe(streamRequest);
	if (streamDescription.find("denoising") == std::string::npos ||
		streamDescription.find("48000") == std::string::npos) {
		std::cerr << "stream description did not include task/sample rate\n";
		return 1;
	}

	ofxGgmlAudioStreamChunker chunker;
	ofxGgmlAudioStreamChunkerSettings chunkerSettings;
	chunkerSettings.format.sampleRate = 10;
	chunkerSettings.format.channels = 1;
	chunkerSettings.windowSeconds = 0.4;
	chunkerSettings.hopSeconds = 0.2;
	chunkerSettings.maxBufferedSeconds = 1.0;
	if (!chunker.setup(chunkerSettings)) {
		std::cerr << "valid chunker settings failed setup\n";
		return 1;
	}
	if (chunkerSettings.getWindowFrameCount() != 4 ||
		chunkerSettings.getHopFrameCount() != 2) {
		std::cerr << "unexpected chunker frame settings\n";
		return 1;
	}
	chunker.pushSamples({ 0.0f, 1.0f, 2.0f }, 12.0);
	if (chunker.hasNext()) {
		std::cerr << "chunker emitted a partial window\n";
		return 1;
	}
	chunker.pushSamples({ 3.0f, 4.0f, 5.0f, 6.0f });
	ofxGgmlAudioStreamRequest chunk;
	if (!chunker.popNext(chunk, ofxGgmlAudioTask::VoiceActivityDetection)) {
		std::cerr << "chunker did not emit a full window\n";
		return 1;
	}
	if (chunk.task != ofxGgmlAudioTask::VoiceActivityDetection ||
		chunk.samples.size() != 4 ||
		chunk.samples.front() != 0.0f ||
		chunk.samples.back() != 3.0f ||
		chunk.timestampSeconds != 12.0) {
		std::cerr << "unexpected first chunk contents\n";
		return 1;
	}
	if (!chunker.popNext(chunk, ofxGgmlAudioTask::VoiceActivityDetection)) {
		std::cerr << "chunker did not emit overlapping window\n";
		return 1;
	}
	if (chunk.samples.front() != 2.0f ||
		chunk.samples.back() != 5.0f ||
		chunk.timestampSeconds <= 12.1) {
		std::cerr << "unexpected overlapping chunk contents\n";
		return 1;
	}

	ofxGgmlAudioStreamChunkerSettings invalidSettings = chunkerSettings;
	invalidSettings.windowSeconds = 2.0;
	invalidSettings.maxBufferedSeconds = 1.0;
	if (invalidSettings.isValid() || chunker.setup(invalidSettings)) {
		std::cerr << "invalid chunker settings were accepted\n";
		return 1;
	}

	ofxGgmlAudioStreamRequest featureRequest;
	featureRequest.format.sampleRate = 4;
	featureRequest.format.channels = 1;
	featureRequest.samples = { -1.0f, 1.0f, -1.0f, 1.0f };
	const auto features = ofxGgmlAudioFeatures::analyze(featureRequest);
	if (std::abs(features.rms - 1.0f) > 0.0001f ||
		std::abs(features.peak - 1.0f) > 0.0001f ||
		std::abs(features.zeroCrossingRate - 1.0f) > 0.0001f ||
		std::abs(features.durationSeconds - 1.0) > 0.0001) {
		std::cerr << "unexpected audio features\n";
		return 1;
	}
	if (ofxGgmlAudioFeatures::isProbablySilent(features)) {
		std::cerr << "loud features reported as silent\n";
		return 1;
	}
	const auto featureVector = ofxGgmlAudioFeatures::toVector(features);
	if (featureVector.size() != 4 || featureVector[0] != features.rms) {
		std::cerr << "unexpected feature vector\n";
		return 1;
	}

	ofxGgmlAudioFrame silentFrame;
	silentFrame.format.sampleRate = 16000;
	silentFrame.format.channels = 1;
	silentFrame.samples = { 0.0f, 0.0f, 0.0f };
	if (!ofxGgmlAudioFeatures::isProbablySilent(ofxGgmlAudioFeatures::analyze(silentFrame))) {
		std::cerr << "silent frame was not reported as silent\n";
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
