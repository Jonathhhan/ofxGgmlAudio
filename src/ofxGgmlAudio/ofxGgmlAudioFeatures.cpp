#include "ofxGgmlAudioFeatures.h"

#include <algorithm>
#include <cmath>

namespace {
	float normalizedRatio(float value, float threshold) {
		if (threshold <= 0.0f) {
			return value > 0.0f ? 1.0f : 0.0f;
		}
		return std::min(1.0f, std::max(0.0f, value / threshold));
	}

	ofxGgmlAudioFeatureFrame analyzeSamples(
		const ofxGgmlAudioStreamFormat & format,
		const std::vector<float> & samples,
		double timestampSeconds) {
		ofxGgmlAudioFeatureFrame features;
		features.format = format;
		features.timestampSeconds = timestampSeconds;

		if (!format.isValid() || samples.empty()) {
			return features;
		}

		const auto channels = static_cast<std::size_t>(format.channels);
		const auto completeSampleCount = samples.size() - (samples.size() % channels);
		if (completeSampleCount == 0) {
			return features;
		}

		double sum = 0.0;
		double sumSquares = 0.0;
		float peak = 0.0f;
		int zeroCrossings = 0;
		float previous = samples.front();

		for (std::size_t i = 0; i < completeSampleCount; ++i) {
			const auto sample = samples[i];
			sum += static_cast<double>(sample);
			sumSquares += static_cast<double>(sample) * static_cast<double>(sample);
			peak = std::max(peak, std::abs(sample));

			if (i > 0 &&
				((previous < 0.0f && sample >= 0.0f) ||
					(previous >= 0.0f && sample < 0.0f))) {
				zeroCrossings++;
			}
			previous = sample;
		}

		const auto sampleCount = static_cast<double>(completeSampleCount);
		features.mean = static_cast<float>(sum / sampleCount);
		features.rms = static_cast<float>(std::sqrt(sumSquares / sampleCount));
		features.peak = peak;
		features.zeroCrossingRate = completeSampleCount > 1
			? static_cast<float>(static_cast<double>(zeroCrossings) /
				static_cast<double>(completeSampleCount - 1))
			: 0.0f;

		const auto frameCount = static_cast<int>(completeSampleCount / channels);
		features.durationSeconds = format.sampleRate > 0
			? static_cast<double>(frameCount) / static_cast<double>(format.sampleRate)
			: 0.0;
		return features;
	}
}

namespace ofxGgmlAudioFeatures {
	ofxGgmlAudioFeatureFrame analyze(const ofxGgmlAudioStreamRequest & request) {
		return analyzeSamples(request.format, request.samples, request.timestampSeconds);
	}

	ofxGgmlAudioFeatureFrame analyze(const ofxGgmlAudioFrame & frame) {
		return analyzeSamples(frame.format, frame.samples, frame.timestampSeconds);
	}

	bool isProbablySilent(const ofxGgmlAudioFeatureFrame & features, float rmsThreshold) {
		return features.rms < rmsThreshold;
	}

	ofxGgmlAudioVadResult estimateVoiceActivity(
		const ofxGgmlAudioFeatureFrame & features,
		const ofxGgmlAudioVadSettings & settings) {
		ofxGgmlAudioVadResult result;
		result.rms = features.rms;
		result.peak = features.peak;
		result.zeroCrossingRate = features.zeroCrossingRate;

		const auto rmsScore = normalizedRatio(features.rms, settings.rmsThreshold);
		const auto peakScore = normalizedRatio(features.peak, settings.peakThreshold);
		const auto crossingInRange =
			features.zeroCrossingRate >= settings.minZeroCrossingRate &&
			features.zeroCrossingRate <= settings.maxZeroCrossingRate;
		const auto crossingScore = crossingInRange ? 1.0f : 0.0f;

		result.score = (rmsScore * 0.55f) + (peakScore * 0.35f) + (crossingScore * 0.10f);
		result.active =
			features.rms >= settings.rmsThreshold &&
			features.peak >= settings.peakThreshold &&
			crossingInRange;
		return result;
	}

	ofxGgmlAudioVadResult estimateVoiceActivity(
		const ofxGgmlAudioStreamRequest & request,
		const ofxGgmlAudioVadSettings & settings) {
		return estimateVoiceActivity(analyze(request), settings);
	}

	std::vector<float> toVector(const ofxGgmlAudioFeatureFrame & features) {
		return {
			features.rms,
			features.peak,
			features.zeroCrossingRate,
			features.mean
		};
	}
}
