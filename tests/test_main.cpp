#include "ofxGgmlAudio.h"

#include <cstdint>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <iostream>

namespace {
	void writeU16(std::ofstream& output, std::uint16_t value) {
		output.put(static_cast<char>(value & 0xff));
		output.put(static_cast<char>((value >> 8) & 0xff));
	}

	void writeU32(std::ofstream& output, std::uint32_t value) {
		output.put(static_cast<char>(value & 0xff));
		output.put(static_cast<char>((value >> 8) & 0xff));
		output.put(static_cast<char>((value >> 16) & 0xff));
		output.put(static_cast<char>((value >> 24) & 0xff));
	}

	bool writeTestWav(const std::string& path) {
		std::ofstream output(path, std::ios::binary);
		if (!output) {
			return false;
		}
		constexpr std::uint16_t channels = 1;
		constexpr std::uint32_t sampleRate = 16000;
		constexpr std::uint16_t bitsPerSample = 16;
		const std::int16_t samples[] = { -32768, 0, 32767, 16384 };
		constexpr std::uint32_t dataSize = sizeof(samples);
		constexpr std::uint32_t fmtSize = 16;
		constexpr std::uint32_t riffSize = 4 + (8 + fmtSize) + (8 + dataSize);

		output.write("RIFF", 4);
		writeU32(output, riffSize);
		output.write("WAVE", 4);
		output.write("fmt ", 4);
		writeU32(output, fmtSize);
		writeU16(output, 1);
		writeU16(output, channels);
		writeU32(output, sampleRate);
		writeU32(output, sampleRate * channels * bitsPerSample / 8);
		writeU16(output, channels * bitsPerSample / 8);
		writeU16(output, bitsPerSample);
		output.write("data", 4);
		writeU32(output, dataSize);
		for (const auto sample : samples) {
			writeU16(output, static_cast<std::uint16_t>(sample));
		}
		return static_cast<bool>(output);
	}
}

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

	ofxGgmlAudioVadSettings vadSettings;
	vadSettings.rmsThreshold = 0.2f;
	vadSettings.peakThreshold = 0.4f;
	ofxGgmlAudioStreamRequest vadRequest;
	vadRequest.format.sampleRate = 4;
	vadRequest.format.channels = 1;
	vadRequest.samples = { -0.5f, 0.5f, 0.5f, 0.5f };
	const auto activeVad = ofxGgmlAudioFeatures::estimateVoiceActivity(
		ofxGgmlAudioFeatures::analyze(vadRequest),
		vadSettings);
	if (!activeVad.active || activeVad.score <= 0.9f) {
		std::cerr << "active VAD was not detected\n";
		return 1;
	}
	const auto silentVad = ofxGgmlAudioFeatures::estimateVoiceActivity(
		ofxGgmlAudioFeatures::analyze(silentFrame),
		vadSettings);
	if (silentVad.active || silentVad.score > 0.2f) {
		std::cerr << "silent VAD was reported active\n";
		return 1;
	}
	const auto requestVad = ofxGgmlAudioFeatures::estimateVoiceActivity(vadRequest, vadSettings);
	if (!requestVad.active) {
		std::cerr << "request VAD overload did not detect activity\n";
		return 1;
	}

	const std::string wavPath = "ofxGgmlAudio_test_16k.wav";
	if (!writeTestWav(wavPath)) {
		std::cerr << "could not write test WAV\n";
		return 1;
	}
	ofxGgmlAudioFrame wavFrame;
	ofxGgmlAudioWavInfo wavInfo;
	std::string wavError;
	if (!ofxGgmlAudioUtils::loadWavFile(wavPath, wavFrame, &wavInfo, &wavError)) {
		std::cerr << "could not load test WAV: " << wavError << "\n";
		std::remove(wavPath.c_str());
		return 1;
	}
	std::remove(wavPath.c_str());
	if (wavFrame.format.sampleRate != 16000 ||
		wavFrame.format.channels != 1 ||
		wavFrame.samples.size() != 4 ||
		wavInfo.bitsPerSample != 16 ||
		wavInfo.frameCount != 4) {
		std::cerr << "unexpected WAV metadata\n";
		return 1;
	}
	if (std::abs(wavFrame.samples.front() + 1.0f) > 0.0001f ||
		wavFrame.samples.back() < 0.49f) {
		std::cerr << "unexpected WAV sample conversion\n";
		return 1;
	}
	const auto wavStream = ofxGgmlAudioUtils::toStreamRequest(wavFrame);
	if (!ofxGgmlAudioUtils::hasSamples(wavStream) ||
		ofxGgmlAudioUtils::getFrameCount(wavStream) != 4) {
		std::cerr << "WAV stream conversion failed\n";
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
	const auto streamTranscribeResult = backend.transcribe(wavStream);
	if (streamTranscribeResult) {
		std::cerr << "whisper backend transcribed stream without setup\n";
		return 1;
	}

	return 0;
}
