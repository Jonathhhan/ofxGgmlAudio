#include "ofxGgmlAudioStreamChunker.h"

#include <algorithm>
#include <cmath>

namespace {
	int secondsToFrames(double seconds, int sampleRate) {
		if (seconds <= 0.0 || sampleRate <= 0) {
			return 0;
		}
		return std::max(1, static_cast<int>(std::lround(seconds * static_cast<double>(sampleRate))));
	}
}

bool ofxGgmlAudioStreamChunkerSettings::isValid() const {
	return format.isValid() &&
		windowSeconds > 0.0 &&
		hopSeconds > 0.0 &&
		maxBufferedSeconds >= windowSeconds;
}

int ofxGgmlAudioStreamChunkerSettings::getWindowFrameCount() const {
	return secondsToFrames(windowSeconds, format.sampleRate);
}

int ofxGgmlAudioStreamChunkerSettings::getHopFrameCount() const {
	return secondsToFrames(hopSeconds, format.sampleRate);
}

int ofxGgmlAudioStreamChunkerSettings::getMaxBufferedFrameCount() const {
	return secondsToFrames(maxBufferedSeconds, format.sampleRate);
}

bool ofxGgmlAudioStreamChunker::setup(const ofxGgmlAudioStreamChunkerSettings & nextSettings) {
	if (!nextSettings.isValid()) {
		clear();
		settings = ofxGgmlAudioStreamChunkerSettings{};
		configured = false;
		return false;
	}
	settings = nextSettings;
	clear();
	configured = true;
	return true;
}

bool ofxGgmlAudioStreamChunker::isConfigured() const {
	return configured;
}

const ofxGgmlAudioStreamChunkerSettings & ofxGgmlAudioStreamChunker::getSettings() const {
	return settings;
}

void ofxGgmlAudioStreamChunker::clear() {
	buffer.clear();
	bufferStartTimestampSeconds = 0.0;
	hasTimestamp = false;
}

void ofxGgmlAudioStreamChunker::pushSamples(const std::vector<float> & samples, double timestampSeconds) {
	if (!configured || samples.empty() || settings.format.channels <= 0) {
		return;
	}

	const auto channelCount = static_cast<std::size_t>(settings.format.channels);
	const auto completeSampleCount = samples.size() - (samples.size() % channelCount);
	if (completeSampleCount == 0) {
		return;
	}

	if (!hasTimestamp) {
		bufferStartTimestampSeconds = timestampSeconds;
		hasTimestamp = true;
	}

	buffer.insert(buffer.end(), samples.begin(), samples.begin() + static_cast<std::ptrdiff_t>(completeSampleCount));
	trimToMaxBuffer();
}

bool ofxGgmlAudioStreamChunker::hasNext() const {
	return configured && getBufferedFrameCount() >= settings.getWindowFrameCount();
}

bool ofxGgmlAudioStreamChunker::popNext(ofxGgmlAudioStreamRequest & request, ofxGgmlAudioTask task) {
	if (!hasNext()) {
		return false;
	}

	const auto windowSamples = getSampleCountForFrames(settings.getWindowFrameCount());
	const auto hopFrames = settings.getHopFrameCount();
	const auto hopSamples = getSampleCountForFrames(hopFrames);

	request = ofxGgmlAudioStreamRequest{};
	request.task = task;
	request.format = settings.format;
	request.timestampSeconds = bufferStartTimestampSeconds;
	request.samples.assign(buffer.begin(), buffer.begin() + windowSamples);

	const auto samplesToDrop = std::min<int>(hopSamples, static_cast<int>(buffer.size()));
	buffer.erase(buffer.begin(), buffer.begin() + samplesToDrop);
	bufferStartTimestampSeconds += static_cast<double>(samplesToDrop / settings.format.channels) /
		static_cast<double>(settings.format.sampleRate);
	if (buffer.empty()) {
		hasTimestamp = false;
	}

	return true;
}

int ofxGgmlAudioStreamChunker::getBufferedFrameCount() const {
	if (settings.format.channels <= 0) {
		return 0;
	}
	return static_cast<int>(buffer.size() / static_cast<std::size_t>(settings.format.channels));
}

int ofxGgmlAudioStreamChunker::getSampleCountForFrames(int frameCount) const {
	if (frameCount <= 0 || settings.format.channels <= 0) {
		return 0;
	}
	return frameCount * settings.format.channels;
}

void ofxGgmlAudioStreamChunker::trimToMaxBuffer() {
	const auto maxSamples = getSampleCountForFrames(settings.getMaxBufferedFrameCount());
	if (maxSamples <= 0 || static_cast<int>(buffer.size()) <= maxSamples) {
		return;
	}

	auto samplesToDrop = static_cast<int>(buffer.size()) - maxSamples;
	samplesToDrop -= samplesToDrop % settings.format.channels;
	if (samplesToDrop <= 0) {
		return;
	}

	buffer.erase(buffer.begin(), buffer.begin() + samplesToDrop);
	bufferStartTimestampSeconds += static_cast<double>(samplesToDrop / settings.format.channels) /
		static_cast<double>(settings.format.sampleRate);
}
