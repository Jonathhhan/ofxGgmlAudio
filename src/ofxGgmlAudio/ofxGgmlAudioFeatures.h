#pragma once

#include "ofxGgmlAudioTypes.h"

#include <vector>

struct ofxGgmlAudioFeatureFrame {
	ofxGgmlAudioStreamFormat format;
	double timestampSeconds = 0.0;
	double durationSeconds = 0.0;
	float rms = 0.0f;
	float peak = 0.0f;
	float zeroCrossingRate = 0.0f;
	float mean = 0.0f;
};

namespace ofxGgmlAudioFeatures {
	ofxGgmlAudioFeatureFrame analyze(const ofxGgmlAudioStreamRequest & request);
	ofxGgmlAudioFeatureFrame analyze(const ofxGgmlAudioFrame & frame);
	bool isProbablySilent(const ofxGgmlAudioFeatureFrame & features, float rmsThreshold = 0.01f);
	std::vector<float> toVector(const ofxGgmlAudioFeatureFrame & features);
}
