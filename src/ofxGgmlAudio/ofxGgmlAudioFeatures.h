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

struct ofxGgmlAudioVadSettings {
	float rmsThreshold = 0.02f;
	float peakThreshold = 0.04f;
	float minZeroCrossingRate = 0.005f;
	float maxZeroCrossingRate = 0.45f;
};

struct ofxGgmlAudioVadResult {
	bool active = false;
	float score = 0.0f;
	float rms = 0.0f;
	float peak = 0.0f;
	float zeroCrossingRate = 0.0f;
};

namespace ofxGgmlAudioFeatures {
	ofxGgmlAudioFeatureFrame analyze(const ofxGgmlAudioStreamRequest & request);
	ofxGgmlAudioFeatureFrame analyze(const ofxGgmlAudioFrame & frame);
	bool isProbablySilent(const ofxGgmlAudioFeatureFrame & features, float rmsThreshold = 0.01f);
	ofxGgmlAudioVadResult estimateVoiceActivity(
		const ofxGgmlAudioFeatureFrame & features,
		const ofxGgmlAudioVadSettings & settings = ofxGgmlAudioVadSettings{});
	ofxGgmlAudioVadResult estimateVoiceActivity(
		const ofxGgmlAudioStreamRequest & request,
		const ofxGgmlAudioVadSettings & settings = ofxGgmlAudioVadSettings{});
	std::vector<float> toVector(const ofxGgmlAudioFeatureFrame & features);
}
