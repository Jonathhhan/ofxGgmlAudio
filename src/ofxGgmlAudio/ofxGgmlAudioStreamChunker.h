#pragma once

#include "ofxGgmlAudioTypes.h"

#include <vector>

struct ofxGgmlAudioStreamChunkerSettings {
	ofxGgmlAudioStreamFormat format;
	double windowSeconds = 1.0;
	double hopSeconds = 0.5;
	double maxBufferedSeconds = 10.0;

	bool isValid() const;
	int getWindowFrameCount() const;
	int getHopFrameCount() const;
	int getMaxBufferedFrameCount() const;
};

class ofxGgmlAudioStreamChunker {
public:
	bool setup(const ofxGgmlAudioStreamChunkerSettings & settings);
	bool isConfigured() const;
	const ofxGgmlAudioStreamChunkerSettings & getSettings() const;

	void clear();
	void pushSamples(const std::vector<float> & samples, double timestampSeconds = 0.0);
	bool hasNext() const;
	bool popNext(ofxGgmlAudioStreamRequest & request,
		ofxGgmlAudioTask task = ofxGgmlAudioTask::Transcription);

	int getBufferedFrameCount() const;

private:
	int getSampleCountForFrames(int frameCount) const;
	void trimToMaxBuffer();

	ofxGgmlAudioStreamChunkerSettings settings;
	bool configured = false;
	std::vector<float> buffer;
	double bufferStartTimestampSeconds = 0.0;
	bool hasTimestamp = false;
};
